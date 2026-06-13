---
name: aten-static-dispatch
description: Findings on torchgen --static-dispatch-backend CPU for dispatch-free ATen calls
metadata: 
  node_type: memory
  type: project
  originSessionId: d246e328-f8ef-4beb-90da-7b32514b57f9
---

Investigated 2026-06-13 for a dispatch-free path to real ATen compute (see [[aten-core-build-closure]]).

**SHIPPED 2026-06-13**: real `at::add`/`at::mul` now run through OCaml (demo prints `a+b`/`a*b` from genuine ATen kernels, dispatch-free). Toolchain requirement captured in [[aten-clang-lld-toolchain]]. The bounded build (`modules/aten_core`):
- `run_codegen.sh`: `--static-dispatch-backend CPU --skip-dispatcher-op-registration`.
- `gen_macros.sh`: also generates `ATen/Config.h` (all features 0, `AT_PARALLEL_NATIVE=1`).
- `build_archive.sh`: core c10+ATen/core (monolithic, NO sections) + section-split glue (`Operators_*`, `RegisterCPU_*`, `RegisterComposite*_0`, `TensorMethods`, `UfuncCPU{,Kernel}_add`) + native closure (TensorIterator, Parallel*, factories/shape/conversions, BinaryOps + BinaryOpsKernel/FillKernel = mul/fill stubs) compiled scalar (`-DCPU_CAPABILITY_DEFAULT`) + `stubs.cpp` + cpuinfo (cmake, merged via `ar -M ADDLIB` to preserve cpuinfo's duplicate `cache.c.o` members).
- `stubs.cpp` (Option A): throwing leaves for cold-path ops TensorIterator/structured kernels reference straight-line but never run for dense float — is_nonzero, dequantize, copy_, sum (+ structured_sum_out::impl / structured_sum_dim_IntList::meta), nonzero_cpu, index_select_cpu_, arange_out, sparse_compressed_*, quantizer factories + TensorBase::quantizer, and `torch::jit::parseName` (cold TORCH_LIBRARY path in library.cpp). QTensorImpl ctor/vtable come from the real (tiny) QTensorImpl.cpp.
- TensorMethods MUST be section-split (not in core): under static dispatch every Tensor::method() routes directly to at::native::X.
- shim: `atc_add`/`atc_mul` just `atc_wrap(at::add/at::mul(...))`; the old manual float loops are gone. OCaml binding renamed `add_float`->`add`.

Original investigation notes follow.

`python3 -m torchgen.gen ... --static-dispatch-backend CPU` makes each op's `::call` a DIRECT backend call, no Dispatcher:
```cpp
at::Tensor empty_memory_format::call(...) { return at::cpu::empty_symint(...); }  // no Dispatcher::call
```
Verified empirically: compiling TensorIterator.cpp + test against core + the static-dispatch Operators_*.cpp leaves **0** `at::_ops::*::call` (Dispatcher) undefined symbols — the dispatcher is fully gone (no boxing, no TORCH_LIBRARY_IMPL registration, no --whole-archive static-init trick needed).

BUT the cost just moves: compiling ALL 5 Operators_*.cpp then references **1058 `at::cpu::X` kernels** (the whole CPU library) → full cascade. Lever to bound it: `--op-registration-whitelist aten::add ...` so only the needed ops' `::call`/`at::cpu::X` are emitted.

TensorIterator.cpp alone references ~33 ops (empty, empty_strided, empty_like, copy_, clone, contiguous, resize_as_, as_strided_, fill_, zero_, item, eq/lt, AND sparse/quantized accessors: q_scale, qscheme, coalesce, values, indices, crow_indices, dequantize, to_dense). Under static dispatch each needs its at::cpu:: kernel + native impl linked → TensorIterator drags a broad native set even allowlisted. Plus parallel_for → ParallelNative → cpuinfo (the compiled C library, genuine new dep).

SIMD is orthogonal: avoid add_stub by driving TensorIterator with a scalar `iter.for_each(loop)` (no Loops.h, no vectorization).

BREAKTHROUGH 2026-06-13 on bounding the closure (empirically, scratch /tmp/mintensor):
- `--op-registration-whitelist` does NOT trim the static `at::cpu::` wrappers (RegisterCPU still defines all 2669 → 648 native kernels). Op-selection YAML trims `m.impl` registrations to selected ops but ALSO keeps the 2669 at::cpu:: defs.
- `--skip-dispatcher-op-registration` → emits EMPTY `TORCH_LIBRARY_IMPL` blocks (0 `m.impl`), so no static-init force-links kernels. Combined with **`-ffunction-sections -fdata-sections` + `-Wl,--gc-sections`**, the linker drops everything not actually reached: closure collapses **2565 → 46 undefined (10 native kernels)**. This is THE key to a bounded real-ATen build.
- cpuinfo builds cleanly standalone: `cmake -S third_party/cpuinfo -B out -DCPUINFO_BUILD_*_TESTS=OFF -DCPUINFO_LIBRARY_TYPE=static` → libcpuinfo.a. One step, no fuss.
- RESIDUAL BLOCKER (~33 syms after adding factories/shape/conversions/compare/fill/sparse/hooks): TensorIterator.cpp UNCONDITIONALLY references cold-path ops `is_nonzero`, `item`, `to_dense`, `dequantize`, `coalesce`, `values/indices`, `sum` (in its error/type-check helpers). These drag sparse + quantized (QTensorImpl, quantizers) + reduction (sum) + comparison, and pull a few DispatchStub SIMD kernels (fill_stub, eq/lt/sum stubs). gc-sections can't drop them (straight-line refs in composite delegates).
- To FINISH, two options: (A) stub those ~6 cold-path ops (throw; never called for dense-float add) → bounded ~30 files + cpuinfo, no SIMD; (B) pull the full transitive closure ~50-80 native files + a few SIMD DispatchStub kernels. Option A matches the "controlled set, rest handled manually" philosophy.
- Build flags for the static-dispatch kernels: `-DCPU_CAPABILITY=DEFAULT -DCPU_CAPABILITY_DEFAULT` (scalar, no AVX). Also needs ATen/Config.h.

Conclusion: static dispatch = genuinely dispatch-free execution, clean (no registration/whole-archive). Remaining cost to reach real TensorIterator-based ops = bound the at::cpu:: kernel set via op-allowlist + resolve TensorIterator's ~33-op native closure + build cpuinfo. Moderate, well-defined, not tiny. ATen/Config.h (all features off, AT_PARALLEL_NATIVE=1) also needed, like cmake_macros.h.
