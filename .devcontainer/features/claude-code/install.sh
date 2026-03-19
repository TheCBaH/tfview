#!/bin/sh
set -eu
set -x

echo "Activating feature 'Claude Code CLI'"
CLAUDE_CODE_VERSION=${VERSION:-latest}
echo "Selected Claude Code version: $CLAUDE_CODE_VERSION"

export DEBIAN_FRONTEND=noninteractive

# Native installer (recommended, replaces deprecated npm method)
if [ "$CLAUDE_CODE_VERSION" = "latest" ]; then
    curl -fsSL https://claude.ai/install.sh | bash
else
    curl -fsSL https://claude.ai/install.sh | bash -s "$CLAUDE_CODE_VERSION"
fi
