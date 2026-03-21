#!/bin/sh
# Verify tfview output for a single model
# Usage: verify-model-output.sh <output-file>
# Exits non-zero with a diagnostic message on failure.

set -e

file="$1"
if [ -z "$file" ] || [ ! -f "$file" ]; then
  echo "Usage: $0 <output-file>" >&2
  exit 1
fi

name=$(basename "$file" .txt)
fail() { echo "FAIL [$name]: $1" >&2; exit 1; }

# Must not be empty
[ -s "$file" ] || fail "output is empty"

# Must contain model version
grep -q "^Model version:" "$file" || fail "missing Model version"

# Operator codes section: extract count, verify detail lines
op_code_count=$(grep "^Operator codes:" "$file" | awk '{print $3}')
[ -n "$op_code_count" ] || fail "missing Operator codes"
[ "$op_code_count" -gt 0 ] || fail "zero operator codes"

# Subgraph section must exist
grep -q "^Subgraphs:" "$file" || fail "missing Subgraphs"

# Operators section: extract declared count, verify matching detail lines
op_count=$(grep "^  Operators:" "$file" | awk '{print $2}')
[ -n "$op_count" ] || fail "missing Operators"
[ "$op_count" -gt 0 ] || fail "zero operators"
op_lines=$(grep -c '^ *\[.*\].*inputs=' "$file" || true)
[ "$op_lines" -eq "$op_count" ] || fail "operator count mismatch: declared=$op_count listed=$op_lines"

# Tensors section: extract declared count, verify matching detail lines
tensor_count=$(grep "^  Tensors:" "$file" | awk '{print $2}')
[ -n "$tensor_count" ] || fail "missing Tensors"
[ "$tensor_count" -gt 0 ] || fail "zero tensors"
# Tensor lines: indented [N] with a type keyword (float32, uint8, int32, etc.) but no "inputs="
tensor_lines=$(grep -c '^ *\[.*\] .* \(float16\|float32\|float64\|int8\|int16\|int32\|int64\|uint8\|uint16\|uint32\|uint64\|string\|bool\|complex64\|complex128\|resource\|variant\) ' "$file" || true)
[ "$tensor_lines" -eq "$tensor_count" ] || fail "tensor count mismatch: declared=$tensor_count listed=$tensor_lines"

# No unknown nodes
if grep -q "<unknown>" "$file"; then
  fail "output contains <unknown> nodes"
fi

# No unparsed builtin options (lines like "      <some_options>")
unparsed=$(grep -c '^ *<.*_options>' "$file" || true)
if [ "$unparsed" -gt 0 ]; then
  examples=$(grep '^ *<.*_options>' "$file" | sort -u | head -5 | tr '\n' ' ')
  fail "unparsed builtin options ($unparsed): $examples"
fi

echo "OK [$name]: $op_code_count op_codes, $op_count operators, $tensor_count tensors"
