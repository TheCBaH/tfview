---
name: aten-core-build-closure
description: "Verified minimal dependency closure to build the ATen \"core\" C++ subset (no OCaml bindings)"
metadata: 
  node_type: memory
  type: project
  originSessionId: d246e328-f8ef-4beb-90da-7b32514b57f9
---

Goal: build only the ATen *core* subset of PyTorch C++ (`modules/pytorch`) + direct deps, no OCaml bindings, via dune foreign rules. Empirically verified 2026-06-11 with g++ 14.2 (`-std=c++17`): **all 120 source files compile to .o, zero failures.**

UPDATE 2026-06-13: archive grown to **137 objects** — c10 globs are now RECURSIVE over c10/core (incl c10/core/impl), c10/util, c10/mobile (the old `-maxdepth 1` dropped c10/core/impl PyObjectSlot/COW/SizesAndStrides + c10/mobile caching allocators, which real tensor construction needs). This 137-file set is the smallest that can CONSTRUCT CPU tensors + run trivial ops: build via c10 directly (make_intrusive<StorageImpl> + at::detail::make_tensor<TensorImpl> + set_sizes_contiguous), access buffer via `storage().mutable_data()`. Do NOT use `data_ptr<T>()` — it pulls TensorMethods.cpp's Tensor::item() → at::_ops::item::call → whole Operators_*.cpp + record_function + SequenceNumber layer. No dispatcher/native kernels/cpuinfo/at::empty/Context/Config.h needed. Step 2 shim (atc_new_float/atc_free/atc_numel/atc_data_float/atc_fill_float/atc_add_float) does add via a direct buffer loop; OCaml demo prints a+b=[10..15].

Closure (CPU, static, no CUDA/MKL/etc):
- **c10/core + c10/util** = 75 .cpp. Needs only generated `c10/macros/cmake_macros.h` (configure the `.in`; all `#cmakedefine`→undef for default CPU build) + `fmt` (header-only, `-DFMT_HEADER_ONLY=1`) for 4 files + `cpuinfo` for `thread_pool.cpp`. fmt+cpuinfo are third_party submodules (must `git submodule update --init third_party/fmt third_party/cpuinfo`; default checkout is empty).
- **aten/src/ATen/core** = 45 hand-written .cpp. Needs c10 above PLUS torchgen-generated **headers** (esp. `ATen/core/TensorBody.h`, `ATen/core/aten_interned_strings.h`). ATen/core pulls c10 only from core/util/macros — nothing else.
- **2 generated core sources**: `core/ATenOpList.cpp`, `core/TensorMethods.cpp`.

Codegen: `python3 -m torchgen.gen --source-path aten/src/ATen --install_dir OUT --generate headers --generate sources`. Needs python `pyyaml`+`typing_extensions` (apt: python3-yaml python3-typing-extensions). `--generate` takes one value per flag (repeat it). Do NOT pass `--per-operator-headers` → keeps monolithic 25 headers, no `ops/` dir, simpler. Includes resolve as `<ATen/...>` so symlink/point install_dir as `ATen/` under an include root.

Include roots used: `-I<pt-root> -Iaten/src -I<gen>(ATen→install_dir) -I<macros> -Ithird_party/fmt/include -Ithird_party/cpuinfo/include`.

DONE 2026-06-11: working dune build at `modules/aten_core/` — `dune build modules/aten_core/libaten_core.a` produces a 44MB static archive (122 .o). Three rules + three bash scripts: `gen_macros.sh` (→`inc/` dir target, sed the `.in`), `run_codegen.sh` (→`gen/` dir target, torchgen), `build_archive.sh` (g++ -O0 + ar). Needed `(using directory-targets 0.1)` in dune-project. `%{project_root}/../../modules/pytorch` works in ACTIONS (cwd=build dir) but NOT in `(deps)` (resolved vs source dir) — so submodule inputs are untracked (like data/dune). Rule 3 deps on dir targets via `(glob_files_rec inc/*)`/`(glob_files_rec gen/*)`, not `(source_tree ...)`. Harmless `ftruncate ENOENT` internal error prints during `dune clean` on this overlayfs — build itself is fine.

OCaml bindings (started 2026-06-13): ctypes **static stubs** (no .so runtime load), pattern from [TheCBaH/ocaml-ggml] lib/ggml. Hand-written `extern "C"` shim (shim.h/shim.cpp) compiled INTO libaten_core.a; build_archive.sh also emits dllaten_core.so (--whole-archive) for ctypes bytecode path. `(library (name aten))` with dune `(ctypes ...)` stanza (Types/Functions functors, foreign_archives aten_core, vendored resolver `-lstdc++ -lpthread`, preamble `#include "shim.h"`, generated_entry_point C → `Aten.C.Functions.*`). Deps: `(using ctypes 0.3)` in dune-project; opam ctypes + ctypes-foreign; apt libffi-dev + pkg-config (added to devcontainer.json packages + Dockerfile). Step 0 DONE: demo prints `default dtype = 6, elem size = 4 bytes`, cram test demo/demo.t. Ladder: 1=Scalar/ScalarType, 2=grow build core→aten_cpu (native+RegisterCPU), 3=Tensor handle lifecycle, 4=at::add (aten::add.Tensor). add kernel is in native/, NOT in core archive yet.

NOT in core: all `native/` kernel impls and the big `Register*CPU.cpp`/`Operators_*.cpp` codegen glue — those are the actual operator kernels and need the native sources. "core" = dispatcher/IValue/type-system/Tensor-metadata layer only. See [[aten-schema-staged-plan]].
