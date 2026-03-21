# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

tfview is an OCaml tool that parses and displays TensorFlow Lite model files (.tflite). It reads FlatBuffers-encoded models and prints their structure: operator codes, subgraphs, operators with builtin options, tensors with quantization parameters. It compiles to native, js_of_ocaml, and Melange JavaScript targets.

## Build Commands

```sh
make build              # Build native + jsoo targets
make build-melange      # Build Melange JS target
make build-web-melange  # Build Melange browser bundle (esbuild)
make fmt                # Auto-format OCaml code (run before committing)
make generate           # Regenerate tflite_schema from schema.fbs
```

## Testing

```sh
make download-models           # Download all 12 test models
make test-models               # Parse all models, verify output structure
make test-jsoo                 # Compare native vs jsoo (all models)
make test-melange              # Compare native vs melange (all models)
make test-web-jsoo             # JSDOM test (small models)
make test-web-jsoo-browser     # Playwright test (small models)
make test-web-melange          # JSDOM test (small models)
make test-web-melange-browser  # Playwright test (small models)
```

Browser/DOM tests use a subset of 4 small models (<5MB) to avoid timeouts.

## Architecture

```
lib/print/print.ml              — Core parsing logic (shared by all targets)
bin/tfview.ml                   — Native CLI
web-jsoo/tfview_web.ml          — js_of_ocaml browser export
web-melange/tfview_mel.ml       — Melange Node.js CLI
web-melange/web/tfview_mel_web.ml — Melange browser export
web/                            — Shared browser UI, tests, and dev server (SERVE_DIR selects build)
```

## Key Rules

- **Always run `make fmt` before committing.** CI rejects unformatted code.
- **Use `Bytes` not `String` for binary data.** Melange's `String.get_int32_le` is O(n) per call. `Bytes` operations are O(1).
- **Update `.devcontainer/` when adding tools or dependencies.** Dockerfile for system packages, `devcontainer.json` for opam/npm packages.
- **Melange libraries use `_mel` suffix with `(wrapped false)`** to avoid name conflicts while exposing matching module names.
- **cppo + copy_files**: Use explicit `(rule)` for cppo preprocessing — combining `(preprocess)` with `(copy_files)` causes duplicate rule errors.
- Generated schema files are committed. Run `make generate` after modifying flatc or schema.fbs.
- `modules/flatbuffers` submodule is a fork with OCaml codegen. See its own `CLAUDE.md`.
- `models/` is gitignored; downloaded on demand. URLs in `models.inc` (hash drives CI cache key).
- Reuse existing tools and languages rather than introducing alternatives.
