#!/usr/bin/env bats

MCP_DIR="$BATS_TEST_DIRNAME/../../copilot-cli"
BIN_DIR="$MCP_DIR/bin"
SRC_DIR="$MCP_DIR/src"
WRAPPER="$BIN_DIR/mcp-banner.sh"

@test "plugin.json exists and has required fields" {
  [ -f "$MCP_DIR/plugin.json" ]
  jq -e '.name' "$MCP_DIR/plugin.json" >/dev/null
  jq -e '.version' "$MCP_DIR/plugin.json" >/dev/null
  jq -e '.skills' "$MCP_DIR/plugin.json" >/dev/null
}

@test "plugin.json version matches package.json" {
  local pj_ver oc_ver
  pj_ver=$(jq -r '.version' "$MCP_DIR/plugin.json")
  oc_ver=$(jq -r '.version' "$BATS_TEST_DIRNAME/../../opencode/package.json" 2>/dev/null || echo "$pj_ver")
  [ "$pj_ver" = "$oc_ver" ]
}

@test ".mcp.json exists and references mcp-banner" {
  [ -f "$MCP_DIR/.mcp.json" ]
  jq -e '.mcpServers["mcp-banner"]' "$MCP_DIR/.mcp.json" >/dev/null
}

@test ".mcp.json command points to existing wrapper" {
  local cmd
  cmd=$(jq -r '.mcpServers["mcp-banner"].command' "$MCP_DIR/.mcp.json")
  [ -f "$MCP_DIR/$cmd" ]
  [ -x "$MCP_DIR/$cmd" ]
}

@test "wrapper script PLUGIN_DIR resolves to one level above bin/" {
  local plugin_dir
  plugin_dir=$(bash -c 'SCRIPT_DIR="$(cd "$(dirname "'"$WRAPPER"'")" && pwd)"; cd "$SCRIPT_DIR/.." && pwd')
  [ "$plugin_dir" = "$(cd "$MCP_DIR" && pwd)" ]
}

@test "wrapper SRC_DIR points to directory with go.mod" {
  local src_dir
  src_dir=$(bash -c 'SCRIPT_DIR="$(cd "$(dirname "'"$WRAPPER"'")" && pwd)"; echo "$SCRIPT_DIR/../src"')
  [ -f "$src_dir/go.mod" ]
}

@test "wrapper SRC_DIR contains main.go" {
  [ -f "$SRC_DIR/main.go" ]
}

@test "Go source compiles successfully" {
  cd "$SRC_DIR"
  run go build -o /dev/null .
  [ "$status" -eq 0 ]
}

@test "MCP server responds to initialize" {
  cd "$SRC_DIR"
  local binary
  binary=$(mktemp)
  go build -o "$binary" .
  local resp
  resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | "$binary")
  rm -f "$binary"
  echo "$resp" | jq -e '.result.serverInfo.name' >/dev/null
  local name
  name=$(echo "$resp" | jq -r '.result.serverInfo.name')
  [ "$name" = "mcp-banner" ]
}

@test "MCP server lists make_banner tool" {
  cd "$SRC_DIR"
  local binary
  binary=$(mktemp)
  go build -o "$binary" .
  local resp
  resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | "$binary")
  rm -f "$binary"
  local tool_name
  tool_name=$(echo "$resp" | jq -r '.result.tools[0].name')
  [ "$tool_name" = "make_banner" ]
}

@test "MCP server renders banner via tools/call" {
  cd "$SRC_DIR"
  local binary
  binary=$(mktemp)
  go build -o "$binary" .
  local resp
  resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"make_banner","arguments":{"text":"TEST"}}}' | "$binary")
  rm -f "$binary"
  echo "$resp" | jq -e '.result.content[0].text' >/dev/null
  local text
  text=$(echo "$resp" | jq -r '.result.content[0].text')
  [[ "$text" == *"╔"* ]]
}

@test "hooks policy.json is valid" {
  [ -f "$MCP_DIR/hooks/policy.json" ]
  jq -e '.version' "$MCP_DIR/hooks/policy.json" >/dev/null
  jq -e '.hooks' "$MCP_DIR/hooks/policy.json" >/dev/null
}

@test "all hook scripts referenced in policy.json exist and are executable" {
  local hooks_file="$MCP_DIR/hooks/policy.json"
  [ -f "$hooks_file" ] || skip "no policy.json"
  for script in $(jq -r '.. | .bash? // empty' "$hooks_file"); do
    local full_path="$MCP_DIR/$script"
    [ -f "$full_path" ] || { echo "missing: $full_path"; false; }
    [ -x "$full_path" ] || { echo "not executable: $full_path"; false; }
  done
}

@test "skill directories contain SKILL.md" {
  local skills_dir="$MCP_DIR/skills"
  [ -d "$skills_dir" ] || skip "no skills dir"
  for dir in "$skills_dir"/*/; do
    [ -d "$dir" ] || continue
    [ -f "$dir/SKILL.md" ] || { echo "missing SKILL.md in $dir"; false; }
  done
}

@test "agent files have required frontmatter" {
  local agents_dir="$MCP_DIR/agents"
  [ -d "$agents_dir" ] || skip "no agents dir"
  for f in "$agents_dir"/*.agent.md; do
    [ -f "$f" ] || continue
    head -1 "$f" | grep -q '^---' || { echo "missing frontmatter in $f"; false; }
    grep -q '^name:' "$f" || { echo "missing name in $f"; false; }
  done
}
