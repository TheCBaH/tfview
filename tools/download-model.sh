#!/bin/sh
# Download a model file if not already cached.
# Usage: download-model.sh <model_dir> <type> <filename> <url> [inner_name]
#   type: direct  - curl directly to file
#         tgz     - stream-extract inner_name from tgz archive
#         zip     - download zip, extract inner_name, cleanup
#         base64  - pipe through base64 -d
#   inner_name defaults to filename; use when archive path differs
#
# Downloads are atomic: written to a temp file first, renamed on success.
set -eu

MODEL_DIR="$1"
TYPE="$2"
FILENAME="$3"
URL="$4"
INNER_NAME="${5:-$FILENAME}"

TARGET="$MODEL_DIR/$FILENAME"
TMP="$MODEL_DIR/.$FILENAME.tmp.$$"

if [ -f "$TARGET" ]; then
  echo "skip: $FILENAME (cached)"
  exit 0
fi

mkdir -p "$MODEL_DIR"

cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

case "$TYPE" in
  direct)
    curl -sL --fail -o "$TMP" "$URL"
    ;;
  tgz)
    curl -sL --fail "$URL" | tar xzf - -C "$MODEL_DIR" "$INNER_NAME"
    mv "$MODEL_DIR/$INNER_NAME" "$TMP"
    ;;
  zip)
    TMPZIP="$MODEL_DIR/_tmp_$$.zip"
    curl -sL --fail -o "$TMPZIP" "$URL"
    unzip -joq "$TMPZIP" "$INNER_NAME" -d "$MODEL_DIR"
    rm -f "$TMPZIP"
    mv "$MODEL_DIR/$FILENAME" "$TMP"
    ;;
  base64)
    curl -sL --fail "$URL" | base64 -d > "$TMP"
    ;;
  *)
    echo "unknown type: $TYPE" >&2
    exit 1
    ;;
esac

mv "$TMP" "$TARGET"
trap - EXIT
echo "downloaded: $FILENAME"
