# Memory Index

- [aten-schema-staged-plan](aten-schema-staged-plan.md) — stage 1 (raw YAML) done; stage 2 (func parser) planned
- [aten-core-build-closure](aten-core-build-closure.md) — verified minimal C++ closure to build ATen core (c10+ATen/core, 120 files compile)
- [aten-static-dispatch](aten-static-dispatch.md) — SHIPPED: real at::add/at::mul via OCaml, dispatch-free; bounded build (section-split glue + stubs + cpuinfo)
- [aten-clang-lld-toolchain](aten-clang-lld-toolchain.md) — aten_core build requires clang++/lld; GNU ld too slow at --gc-sections; ocamlopt needs --no-export-dynamic
