#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
[[ "$arch" == "x86_64" ]] && arch="amd64"
[[ "$arch" == "aarch64" ]] && arch="arm64"

BINARY="$SCRIPT_DIR/mcp-banner-${os}-${arch}"

if [[ ! -x "$BINARY" ]]; then
  printf "mcp-banner: no binary for %s/%s at %s\n" "$os" "$arch" "$BINARY" >&2
  exit 1
fi

exec "$BINARY" "$@"
