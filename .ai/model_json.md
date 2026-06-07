# model.json Parsing

## Root type: ExportedProgram

```
ExportedProgram (struct)
├── graph_module: GraphModule
│     ├── graph: Graph
│     │     ├── inputs:       List[Argument]   ← graph-level inputs (weights + user inputs)
│     │     ├── outputs:      List[Argument]   ← graph-level outputs
│     │     ├── nodes:        List[Node]        ← operations
│     │     ├── tensor_values: Dict[str, TensorMeta]  ← shape/dtype of every tensor name
│     │     ├── sym_int_values: Dict[str, SymInt]     ← named symbolic integers
│     │     ├── sym_bool_values: Dict[str, SymBool]
│     │     └── custom_obj_values: Dict[str, ...]
│     ├── signature: GraphSignature  ← maps input/output names to parameters/buffers/user I/O
│     └── module_call_graph: List[ModuleCallEntry]
├── opset_version: Dict[str, int]
├── range_constraints: Dict[str, RangeConstraint]  ← allowed ranges for symbolic variables
└── schema_version: SchemaVersion
```

## Node

```json
{
  "target": "torch.ops.aten.conv2d.default",
  "inputs": [ { "name": "input", "arg": {...}, "kind": 1 }, ... ],
  "outputs": [ { "as_tensor": { "name": "conv2d" } } ],
  "metadata": { "stack_trace": "...", "nn_module_stack": "...", "torch_fn": "..." }
}
```

- `target` = `<namespace>.<opname>.<overload>` — exact ATen overload
- `inputs` = `List[NamedArgument]` — each has a `name` (from op schema) and an `Argument` union
- `outputs` = `List[Argument]` — tensor results, named for SSA reference by later nodes
- `kind` = argument kind enum (1 = POSITIONAL)

## Argument union — complete variants

| JSON key | Schema type | ATen schema type |
|---|---|---|
| `as_none` | `bool` (always true) | `None` / absent optional |
| `as_tensor` | `TensorArgument {name}` | `Tensor` |
| `as_tensors` | `List[TensorArgument]` | `Tensor[]` |
| `as_optional_tensor` | `OptionalTensorArgument` | `Tensor?` |
| `as_optional_tensors` | `List[OptionalTensorArgument]` | `Tensor?[]` |
| `as_int` | `int` | `int` or concrete `SymInt` |
| `as_ints` | `List[int]` | `int[]` or concrete `SymInt[]` |
| `as_float` | `float` | `float` or concrete `SymFloat` |
| `as_floats` | `List[float]` | `float[]` |
| `as_bool` | `bool` | `bool` or concrete `SymBool` |
| `as_bools` | `List[bool]` | `bool[]` |
| `as_sym_int` | `SymIntArgument` | symbolic `SymInt` |
| `as_sym_ints` | `List[SymIntArgument]` | symbolic or mixed `SymInt[]` |
| `as_sym_float` | `SymFloatArgument` | symbolic `SymFloat` |
| `as_sym_floats` | `List[SymFloatArgument]` | symbolic `SymFloat[]` |
| `as_sym_bool` | `SymBoolArgument` | symbolic `SymBool` |
| `as_sym_bools` | `List[SymBoolArgument]` | symbolic `SymBool[]` |
| `as_scalar_type` | `ScalarType` (int enum) | `ScalarType` |
| `as_memory_format` | `MemoryFormat` (int enum) | `MemoryFormat` |
| `as_layout` | `Layout` (int enum) | `Layout` |
| `as_device` | `Device {type, index}` | `Device` |
| `as_string` | `str` | `str` |
| `as_strings` | `List[str]` | `str[]` |
| `as_graph` | `GraphArgument` | higher-order op subgraph |
| `as_custom_obj` | `CustomObjArgument` | custom class |
| `as_operator` | `str` | operator reference |
| `as_complex` | `ComplexValue` | `complex` |

## Sym* types — concrete vs symbolic

ATen schema type `SymInt` means the value *can* be a symbolic expression (unknown at
export time). The serializer picks the flattest representation that's still correct:

```
SymInt in ATen schema
├── concrete at export time  →  as_int / as_ints   (no wrapper)
└── symbolic at export time  →  as_sym_int / as_sym_ints
        └── SymIntArgument (union)
                ├── as_int: int     ← concrete int in a mixed list
                └── as_name: str    ← reference to a sym_int_values entry
```

Same pattern for `SymFloat` and `SymBool`.

Plain `bool`, `int`, `float` in an ATen schema are never symbolic — always the direct
`as_bool` / `as_int` / `as_float` variant.

`Scalar` (type-erased numeric) maps to whichever of `as_int`, `as_float`, `as_bool`,
`as_complex` matches the actual runtime value.

`Tensor?` maps to `as_none: true` when absent, `as_tensor: {name}` when present.

## SSA: as_name references

`as_name` is an SSA reference — it names a value produced by another node, exactly
like `as_tensor: {name}` for tensors.

```
range_constraints:   "s77": {min_val: 0, max_val: null}
                              ↑
sym_int_values:  "sym_size_int_1": {as_expr: {expr_str: "Symbol('s77')", hint: {as_int: 4}}}
                          ↑
node sym_size.int  outputs: [{as_sym_int: {as_name: "sym_size_int_1"}}]   ← defines it
node mul.Tensor    inputs:  [{arg: {as_sym_int: {as_name: "sym_size_int_1"}}}]  ← uses it
```

Three layers:
1. `range_constraints` — raw symbolic variable `s77` and its allowed range
2. `sym_int_values` — graph-local name bound to an expression over `s77`
3. `as_name` in a node arg — use-site reference

## TensorMeta

```json
{
  "dtype": 7,
  "sizes": [{"as_int": 32}, {"as_int": 3}, {"as_int": 3}, {"as_int": 3}],
  "strides": [{"as_int": 27}, {"as_int": 9}, {"as_int": 3}, {"as_int": 1}],
  "storage_offset": {"as_int": 0},
  "device": {"type": "cpu", "index": null},
  "requires_grad": true,
  "layout": 7
}
```

- `dtype` / `layout` — `ScalarType` / `Layout` enum values (7 = float32 / Strided)
- `sizes` — logical shape: `[filters, channels, height, width]`
- `strides` — elements to skip per dimension in the flat buffer; for contiguous tensors
  `stride[i] = product(sizes[i+1:])`. Non-contiguous (transposed, sliced, permuted)
  tensors have strides that differ from this formula.
- `storage_offset` — where in the flat buffer this tensor starts (non-zero when
  multiple tensors share a storage via slicing)
- `sizes` and `strides` use `List[SymInt]` — can be `as_int` (static) or
  `as_sym_int: {as_name}` (dynamic shape)
