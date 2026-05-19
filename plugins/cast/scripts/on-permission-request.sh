#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JQ="${CLAUDE_CODE_CAST_JQ:-jq}"
INPUT="$(cat)"

if ! command -v "$JQ" >/dev/null 2>&1; then
  printf '{"systemMessage":"claude-code-cast requires jq to emit Cast agent events; install jq to enable hooks."}\n'
  exit 0
fi

DATA="$("$JQ" -c '
  def trunc(n): tostring | if length > n then .[0:n] else . end;
  def safe_tool_input:
    (.tool_input // .toolInput // {})
    | with_entries(select(.key as $key | ["description", "file_path", "path", "url", "pattern"] | index($key)));

  (.tool_name // .toolName // .tool.name // "") as $tool_name
  | (.tool_input // .toolInput // {}) as $tool_input
  | {
      toolName: ($tool_name | tostring),
      toolPreview: (($tool_input.description // $tool_input.file_path // $tool_input.path // $tool_input.url // $tool_name) | trunc(120)),
      toolInput: safe_tool_input
    }
' <<<"$INPUT" 2>/dev/null || printf '{}')"
EVENT_JSON="$("$SCRIPT_DIR/build-event.sh" "permission.needed" "Claude Code needs permission to continue." "$DATA" <<<"$INPUT" 2>/dev/null || true)"
if [[ -n "$EVENT_JSON" ]]; then
  "$SCRIPT_DIR/emit-event.sh" <<<"$EVENT_JSON" 2>/dev/null || true
fi

exit 0
