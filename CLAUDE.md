# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

tfview is an OCaml tool that parses and displays TensorFlow Lite model files (.tflite). It reads FlatBuffers-encoded models and prints their structure: operator codes, subgraphs, operators with builtin options, tensors with quantization parameters. It compiles to both native and JavaScript (via js_of_ocaml) targets.

## Build Commands

```sh
make build              # Build native + js targets
make flatc              # Build flatc compiler (needed for schema regeneration)
make deps               # Install opam dependencies
make generate           # Regenerate tflite_schema from schema.fbs
make generate-check     # Verify generated schema matches committed files
make fmt                # Auto-format OCaml code
make fmt-check          # Check formatting without changes
```

## Testing

```sh
make download-models    # Download all 12 test models (~870MB of archives)
make test-models        # Parse all models, verify output structure
make test-jsoo          # Compare native vs js_of_ocaml output
make test-web-jsoo      # Test web-jsoo API + DOM modes via Node.js/JSDOM
make test-web-jsoo-browser  # Test web-jsoo in Chromium via Playwright
```

`make test-models` saves each model's output to `_build/models/<name>.txt` then runs `tools/verify-model-output.sh` which checks: operator/tensor counts match detail lines, no `<unknown>` nodes, no unparsed `<..._options>`, and reports quantized tensor counts.

Model URLs are defined in `models.inc` (separate file so its hash drives the CI cache key).

## Architecture

```
schema.fbs (from tflite-micro submodule)
    → flatc --ocaml (from flatbuffers submodule)
    → lib/tflite_schema/tflite_schema.ml/.mli (generated, committed)

lib/print/print.ml          — Core: parses model buffer → text output
bin/tfview.ml               — CLI: reads file, calls Print.model_to_string
web-jsoo/tfview_web.ml      — Web: exports tfview.parse() via js_of_ocaml
web-jsoo/static/index.html  — Browser UI with file input
```

The `tflite_schema` module is auto-generated (~19K lines) and wraps the FlatBuffers runtime (`modules/flatbuffers/ocaml/lib/`). The `print` library is the only hand-written parsing code and handles all operator builtin options and per-tensor quantization parameters.

All three targets (native exe, Node.js jsoo, web jsoo) share the same `tfview_print` library.

## Key Conventions

- **Always run `make fmt` before committing.** CI runs `make fmt-check` and will reject unformatted code. Formatting covers `bin/`, `lib/print/`, `web-jsoo/` only (not generated code). Profile is `default` (`.ocamlformat`).
- Generated schema files are committed. After modifying flatc or schema.fbs, run `make generate` and commit the result. CI runs `make generate-check` to enforce this.
- The `modules/flatbuffers` submodule is a fork (TheCBaH/flatbuffers) with OCaml codegen support. See its own `CLAUDE.md` for details.
- `dune-workspace` adds `modules/flatbuffers` to PATH so dune can find the `flatc` binary.
- `models/` is gitignored. Models are downloaded on demand.
