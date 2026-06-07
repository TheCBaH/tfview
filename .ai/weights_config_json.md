# model_weights_config.json / model_constants_config.json

Both files share the same schema root type: `PayloadConfig`.

## Schema

```
PayloadConfig (struct)
└── config: Dict[str, PayloadMeta]
        key   = parameter/buffer name as used in the graph
                e.g. "features.0.0.weight"
        value = PayloadMeta (struct)
                  ├── path_name: str          → filename in data/weights/ e.g. "weight_0"
                  ├── is_param: bool          → true=parameter, false=buffer
                  ├── use_pickle: bool        → true if binary is pickled, false=raw tensor
                  └── tensor_meta: TensorMeta → shape/dtype (same type as in model.json)
```

## Purpose

Acts as an index between the graph's tensor names and the binary weight files.
The graph in `model.json` references tensors by name (e.g. `p_features_0_0_weight`).
`GraphSignature.input_specs` maps that graph name to the parameter name
(`features.0.0.weight`), which is then the key in `PayloadConfig.config`.
`PayloadMeta.path_name` gives the actual binary file (`weight_0`).

```
Node input "p_features_0_0_weight"
    ↓ GraphSignature.input_specs
"features.0.0.weight"
    ↓ PayloadConfig.config key
PayloadMeta { path_name: "weight_0", tensor_meta: {dtype:7, sizes:[32,3,3,3], ...} }
    ↓
data/weights/weight_0   ← raw float32 bytes, shape [32,3,3,3]
```

## TensorMeta fields (same as in model.json)

- `dtype` — `ScalarType` enum int (7 = float32)
- `sizes` — `List[SymInt]` logical shape
- `strides` — `List[SymInt]` memory layout; contiguous = `[d1*d2*..., d2*d3*..., ..., 1]`
- `storage_offset` — `SymInt` start position in the flat buffer
- `device` — `Device {type, index}`
- `requires_grad` — bool
- `layout` — `Layout` enum int (7 = Strided)

Sizes and strides use `SymInt` (same union as in `model.json`) but in practice are
always `as_int` in weight files since weight shapes are always static.

## Reading a tensor from the binary file

```python
import numpy as np

meta = payload_config["features.0.0.weight"]
dtype = {7: np.float32, 1: np.int8, 3: np.uint8, 4: np.int32}[meta["tensor_meta"]["dtype"]]
sizes = [s["as_int"] for s in meta["tensor_meta"]["sizes"]]
raw = open(f"data/weights/{meta['path_name']}", "rb").read()
tensor = np.frombuffer(raw, dtype=dtype).reshape(sizes)
```
