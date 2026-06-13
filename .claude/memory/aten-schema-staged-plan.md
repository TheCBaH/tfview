---
name: aten-schema-staged-plan
description: Two-stage plan for parsing aten op schema from native_functions.yaml — both stages complete
metadata: 
  node_type: memory
  type: project
  originSessionId: 30d9240c-ed2b-4cdf-ab55-a245b31f1b3a
---

Stage 1 (done): `lib/aten_schema/raw.ml` — parses `native_functions.yaml` into `Raw.t list`. All fields kept as strings/basic types; `func:` string NOT parsed. Cram test at `test/aten_schema_raw_cram.t` verifies 2650 entries parse cleanly.

Stage 2 (done): `lib/aten_schema/func_ast.ml` (AST types), `func_lexer.mll` (ocamllex), `func_parser.mly` (menhir), `func_schema.ml` (top-level parse). Cram test at `test/aten_schema_func_cram.t` verifies all 2650 `func:` strings parse (0 errors). Expect tests in `test/func_parser_test.ml`.

**Why:** JSON model files reference ops as `torch.ops.aten.conv2d.default`; the schema gives argument types, return types, variants, dispatch, tags.

Key design decisions:
- Tokens for `int`/`float`/`bool`/`str` use suffix `_TY` (INT_TY etc.) to avoid clashing with menhir token name rules.
- String defaults support escape sequences (`\"`, `\\`, `\'`) via buffer-based ocamllex subrule.
- `NONE`/`TRUE`/`FALSE` are handled as explicit `default_val` alternatives (not `type_kw_str`) to avoid reduce/reduce conflicts.
- Out args are kwarg-only args with `is_write = true` annotation; classified in `kwarg_args` rule.
- One synthetic test entry `_test_string_default` in the YAML exercises escaped string defaults.
