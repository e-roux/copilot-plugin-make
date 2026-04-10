#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BINARY="$SCRIPT_DIR/mcp-banner"
VERSION_FILE="$PLUGIN_DIR/.mcp-version"
SRC_DIR="$SCRIPT_DIR/../src"
REPO="e-roux/agent-plugin-make"

update_check() {
  if [[ -f "$VERSION_FILE" ]]; then
    local age
    age=$(( $(date +%s) - $(stat -f%m "$VERSION_FILE" 2>/dev/null || stat -c%Y "$VERSION_FILE" 2>/dev/null || echo 0) ))
    [[ $age -lt 3600 ]] && return 0
  fi

  command -v gh >/dev/null 2>&1 || return 0

  local latest current os arch asset
  latest=$(gh api "repos/$REPO/releases/latest" --jq .tag_name 2>/dev/null) || return 0
  current=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
  [[ "$latest" == "$current" ]] && { touch "$VERSION_FILE"; return 0; }

  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  [[ "$arch" == "x86_64" ]] && arch="amd64"
  [[ "$arch" == "aarch64" ]] && arch="arm64"
  asset="mcp-banner-${os}-${arch}"

  local tmp="$BINARY.tmp.$$"
  gh release download "$latest" -R "$REPO" -p "$asset" -O "$tmp" --clobber 2>/dev/null && {
    chmod +x "$tmp"
    mv -f "$tmp" "$BINARY"
    printf "%s" "$latest" > "$VERSION_FILE"
    printf "mcp-banner: updated to %s\n" "$latest" >&2
  } || rm -f "$tmp"
}

update_check &

if [[ ! -x "$BINARY" ]]; then
  if ! command -v go >/dev/null 2>&1; then
    printf "mcp-banner: Go is required to build the MCP server. Install it with: brew install go\n" >&2
    exit 1
  fi
  printf "mcp-banner: building from source (first run)...\n" >&2
  go build -o "$BINARY" "$SRC_DIR"
fi

wait
exec "$BINARY" "$@"
