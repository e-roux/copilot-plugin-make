#!/usr/bin/env bats

PLUGIN_DIR="$BATS_TEST_DIRNAME/../.."
BIN_DIR="$PLUGIN_DIR/bin"
SRC_DIR="$PLUGIN_DIR/src"
WRAPPER="$BIN_DIR/mcp-banner.sh"

@test "plugin.json exists and has required fields" {
  [ -f "$PLUGIN_DIR/plugin.json" ]
  jq -e '.name' "$PLUGIN_DIR/plugin.json" >/dev/null
  jq -e '.version' "$PLUGIN_DIR/plugin.json" >/dev/null
  jq -e '.skills' "$PLUGIN_DIR/plugin.json" >/dev/null
}

@test "plugin.json has single version source of truth" {
  jq -e '.version' "$PLUGIN_DIR/plugin.json" >/dev/null
}

@test ".mcp.json exists and references mcp-banner" {
  [ -f "$PLUGIN_DIR/.mcp.json" ]
  jq -e '.mcpServers["mcp-banner"]' "$PLUGIN_DIR/.mcp.json" >/dev/null
}

@test ".mcp.json command points to existing wrapper" {
  local cmd
  cmd=$(jq -r '.mcpServers["mcp-banner"].command' "$PLUGIN_DIR/.mcp.json")
  [ -f "$PLUGIN_DIR/$cmd" ]
  [ -x "$PLUGIN_DIR/$cmd" ]
}

@test "wrapper script selects platform binary from bin/" {
  run bash "$WRAPPER" < /dev/null
  [[ "$status" -eq 0 ]] || [[ "$output" == *"no binary for"* ]]
}

@test "pre-compiled binaries exist for all platforms" {
  for platform in darwin-arm64 darwin-amd64 linux-amd64 linux-arm64; do
    [ -f "$BIN_DIR/mcp-banner-$platform" ] || { echo "missing: mcp-banner-$platform"; false; }
    [ -x "$BIN_DIR/mcp-banner-$platform" ] || { echo "not executable: mcp-banner-$platform"; false; }
  done
}

@test "Go source compiles successfully" {
  cd "$SRC_DIR"
  run go build -o /dev/null .
  [ "$status" -eq 0 ]
}

@test "MCP server responds to initialize" {
  local resp
  resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | "$WRAPPER" 2>/dev/null)
  echo "$resp" | jq -e '.result.serverInfo.name' >/dev/null
  local name
  name=$(echo "$resp" | jq -r '.result.serverInfo.name')
  [ "$name" = "mcp-banner" ]
}

@test "MCP server lists make_banner tool" {
  local resp
  resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | "$WRAPPER" 2>/dev/null)
  local tool_name
  tool_name=$(echo "$resp" | jq -r '.result.tools[0].name')
  [ "$tool_name" = "make_banner" ]
}

@test "MCP server renders banner via tools/call" {
  local resp
  resp=$(echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"make_banner","arguments":{"text":"TEST"}}}' | "$WRAPPER" 2>/dev/null)
  echo "$resp" | jq -e '.result.content[0].text' >/dev/null
  local text
  text=$(echo "$resp" | jq -r '.result.content[0].text')
  [[ "$text" == *"╔"* ]]
}

@test "hooks policy.json is valid" {
  [ -f "$PLUGIN_DIR/hooks/policy.json" ]
  jq -e '.version' "$PLUGIN_DIR/hooks/policy.json" >/dev/null
  jq -e '.hooks' "$PLUGIN_DIR/hooks/policy.json" >/dev/null
}

@test "all hook scripts referenced in policy.json exist and are executable" {
  local hooks_file="$PLUGIN_DIR/hooks/policy.json"
  [ -f "$hooks_file" ] || skip "no policy.json"
  for script in $(jq -r '.. | .bash? // empty' "$hooks_file"); do
    local full_path="$PLUGIN_DIR/$script"
    [ -f "$full_path" ] || { echo "missing: $full_path"; false; }
    [ -x "$full_path" ] || { echo "not executable: $full_path"; false; }
  done
}

@test "skill directories contain SKILL.md" {
  local skills_dir="$PLUGIN_DIR/skills"
  [ -d "$skills_dir" ] || skip "no skills dir"
  for dir in "$skills_dir"/*/; do
    [ -d "$dir" ] || continue
    [ -f "$dir/SKILL.md" ] || { echo "missing SKILL.md in $dir"; false; }
  done
}

@test "agent files have required frontmatter" {
  local agents_dir="$PLUGIN_DIR/agents"
  [ -d "$agents_dir" ] || skip "no agents dir"
  for f in "$agents_dir"/*.agent.md; do
    [ -f "$f" ] || continue
    head -1 "$f" | grep -q '^---' || { echo "missing frontmatter in $f"; false; }
    grep -q '^name:' "$f" || { echo "missing name in $f"; false; }
  done
}
