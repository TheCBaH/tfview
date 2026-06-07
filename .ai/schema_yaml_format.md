# schema.yaml Format

`schema.yaml` uses a custom PyTorch format — not JSON Schema, Avro, or any external standard.
The meta-schema is the Python code in `schema_check.py` itself.

## Grammar

```yaml
TypeName:
  kind: struct | union | enum
  fields:
    field_name:
      type: <type-expression>
      default: "value"    # optional; structs only; Python repr as string
```

### Type expressions

| Expression | Meaning |
|---|---|
| `str`, `int`, `bool`, `float` | primitive |
| `TypeName` | reference to another type in the schema |
| `List[T]` | ordered list |
| `Dict[K, V]` | map |
| `Optional[T]` | nullable; always has `default: None` |

### kind: struct
All fields present in the JSON object by name. Fields with defaults may be absent
(treated as the default value on read).

### kind: union
Exactly one field is present in the JSON object. The key name IS the discriminator tag.

```json
{ "as_tensor": { "name": "x" } }
```

### kind: enum
Serialized as its integer value (not the name string).

```json
7   ← ScalarType.FLOAT = 7
```

## Annotations in schema.py

Each field in schema.py is annotated with a Thrift field ID:

```python
@dataclass
class TensorMeta:
    dtype:    Annotated[ScalarType, 10]   # field id 10
    sizes:    Annotated[list[SymInt], 20]
    ...
```

The integer is only used for Thrift serialization; JSON uses the field name.
