---
name: aten-clang-lld-toolchain
description: The ATen static-dispatch build requires the clang++/lld toolchain (GNU ld too slow at --gc-sections)
metadata: 
  node_type: memory
  type: project
  originSessionId: 7f9f9223-e13f-4be6-a183-e4d5152db400
---

The `modules/aten_core` real-kernel build (see [[aten-static-dispatch]]) compiles with **clang++** and links with **lld** (`-fuse-ld=lld`). This is a hard requirement, not a preference — the user directed it after we hit the blocker.

**Why:** the static-dispatch archive trims the ~2600 unreached `at::cpu::` op wrappers via `-ffunction-sections` + `-Wl,--gc-sections`. GNU `ld.bfd` does this GC over the giant generated objects (Operators_*.o, RegisterCPU_*.o are 8–10 MB each) pathologically slowly — >90 s and effectively hangs. `lld` does the identical link in **~0.1 s**.

**How to apply:**
- `modules/aten_core/build_archive.sh`: `clang++` for all compiles; `clang++ -shared -fuse-ld=lld -Wl,--gc-sections` for `dllaten_core.so`.
- `lib/aten/dune` ctypes `c_library_flags`: `-fuse-ld=lld -Wl,--gc-sections -Wl,--no-export-dynamic -lstdc++ -lpthread`. The **`--no-export-dynamic` is essential** — ocamlopt links native exes with `-Wl,-E` by default, which makes every global symbol a GC root and defeats `--gc-sections` (the whole archive stays, link fails with hundreds of undefined `at::native::` Tensor-method symbols).
- `clang` + `lld` added to `.devcontainer/Dockerfile`.
