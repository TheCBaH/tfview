---
name: aten-static-dispatch
description: Findings on torchgen --static-dispatch-backend CPU for dispatch-free ATen calls
metadata: 
  node_type: memory
  type: project
  originSessionId: d246e328-f8ef-4beb-90da-7b32514b57f9
---

Investigated 2026-06-13 for a dispatch-free path to real ATen compute (see [[aten-core-build-closure]]).

**SHIPPED 2026-06-13**: real `at::add`/`at::mul` now run through OCaml (demo prints `a+b`/`a*b` from genuine ATen kernels, dispatch-free). Toolchain requirement captured in [[aten-clang-lld-toolchain]]. The bounded build (C++ sources + scripts now in `lib/aten/`, built in-place with the ctypes library — no copy rules; `modules/` is submodules-only):
- `run_codegen.sh`: `--static-dispatch-backend CPU --skip-dispatcher-op-registration`.
- `gen_macros.sh`: also generates `ATen/Config.h` (all features 0, `AT_PARALLEL_NATIVE=1`).
- `build_archive.sh`: core c10+ATen/core (monolithic, NO sections) + section-split glue (`Operators_*`, `RegisterCPU_*`, `RegisterComposite*_0`, `TensorMethods`, `UfuncCPU{,Kernel}_add`) + native closure (TensorIterator, Parallel*, factories/shape/conversions, BinaryOps + BinaryOpsKernel/FillKernel = mul/fill stubs) compiled scalar (`-DCPU_CAPABILITY_DEFAULT`) + `stubs.cpp` + cpuinfo (cmake, merged via `ar -M ADDLIB` to preserve cpuinfo's duplicate `cache.c.o` members).
- `stubs.cpp` (Option A): throwing leaves for cold-path ops TensorIterator/structured kernels reference straight-line but never run for dense float — is_nonzero, dequantize, copy_, sum (+ structured_sum_out::impl / structured_sum_dim_IntList::meta), nonzero_cpu, index_select_cpu_, arange_out, sparse_compressed_*, quantizer factories + TensorBase::quantizer, and `torch::jit::parseName` (cold TORCH_LIBRARY path in library.cpp). QTensorImpl ctor/vtable come from the real (tiny) QTensorImpl.cpp.
- TensorMethods MUST be section-split (not in core): under static dispatch every Tensor::method() routes directly to at::native::X.
- shim: `atc_add`/`atc_mul` just `atc_wrap(at::add/at::mul(...))`; the old manual float loops are gone. OCaml binding renamed `add_float`->`add`.

**Extended 2026-06-13**: added shape API (`atc_dim`/`atc_sizes` -> `Tensor.shape`), `atc_reshape` (SymInt[] path; `at::reshape` already linked via TensorShape.cpp), and `atc_avg_pool2d` (real compute, exact block means). Adding a structured op = add its meta+impl + kernel sources to the bounded closure: avg_pool2d needed `native/AveragePool2d.cpp` (TORCH_META_FUNC/TORCH_IMPL_FUNC, -> SRCS_GLUE) + `native/cpu/AvgPoolKernel.cpp` (REGISTER_DISPATCH, vec.h -> SRCS_CAP). Routing: `at::avg_pool2d` -> `at::cpu::avg_pool2d` (Operators_2) -> `wrapper_CPU_avg_pool2d` (RegisterCPU_0) -> `structured_avg_pool2d_out_cpu::impl` -> `avg_pool2d_kernel` stub. No new stubs.cpp leaves needed; archive grew 191->193 objects, links clean. This is the template for adding any structured CPU op. Generator-side SymInt/SymInt[] type support: [[aten-schema-staged-plan]] (c_type.ml binds them as int64/IntArrayRef via the non-_symint at:: overload).

**Refactor 2026-06-13 (Tensor-API vs operations split, prep for autogen)**: the binding separates the stable hand-written Tensor API from the (future-autogen) operations, on both sides. The whole C++ build also moved out of `modules/` (submodules-only) into `lib/aten/`, built in-place with the ctypes library so there are NO cross-directory copy rules.
- C: `shim.{h,cpp}` = handle lifecycle + introspection + C++ helpers (atc_to_ptr/atc_wrap); `ops.{h,cpp}` = the at:: op wrappers (add/mul/reshape/avg_pool2d). ops.h includes shim.h; both compiled into the archive via build_archive.sh SRCS_GLUE; both listed in lib/aten/dune deps; the ctypes preamble includes both (sources live in lib/aten, so `#include "shim.h"` resolves directly).
- OCaml: `function_description.ml` (Tensor API, owns the shared `atc_tensor` opaque type) + `operation_description.ml` (ops; `let atc_tensor = Function_description.atc_tensor` to share the handle type). Two `(function_description ...)` stanzas in lib/aten/dune -> `C.Functions` + `C.Operations`. Demo: `module O = Aten.C.Operations` for ops, `F` for the Tensor API.
- GOTCHA (dune 3.23 ctypes): the inner functor module MUST be named `Functions` in EVERY function_description .ml; `(instance Operations)` only sets the alias under the entry point (`C.Operations`). Naming it `module Operations` -> "Unbound module Operation_description.Functions".
- torchgen AOTI leak: `--generate sources` always emits AOTInductor C-shims; `--aoti-install-dir` defaults to a CWD-relative `torch/csrc/inductor/aoti_torch/generated`, which leaks into the source tree on a manual run_codegen.sh. Fixed: pass `--aoti-install-dir "$A/aoti_unused"` (absolute, inside the gen/ build target) so they're cleaned with gen/. The torchgen "X.h not found" stderr lines for these are benign.
- Build location: the three archive rules (gen_macros/run_codegen/build_archive) live in `lib/aten/dune` and emit libaten_core.a/.so into lib/aten's build dir, where `(foreign_archives aten_core)` finds them. `%{project_root}/../../modules/pytorch` is depth-independent, unchanged by the move.

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
