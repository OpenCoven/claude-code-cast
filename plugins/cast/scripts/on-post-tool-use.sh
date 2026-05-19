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
  def safe_tool_input:
    (.tool_input // .toolInput // {})
    | with_entries(select(.key as $key | ["description", "file_path", "path", "url", "pattern"] | index($key)));

  {
    toolName: ((.tool_name // .toolName // .tool.name // "") | tostring),
    toolInput: safe_tool_input
  }
' <<<"$INPUT" 2>/dev/null || printf '{}')"
EVENT_JSON="$("$SCRIPT_DIR/build-event.sh" "tool.completed" "Claude Code tool completed." "$DATA" <<<"$INPUT" 2>/dev/null || true)"
if [[ -n "$EVENT_JSON" ]]; then
  "$SCRIPT_DIR/emit-event.sh" <<<"$EVENT_JSON" 2>/dev/null || true
fi

exit 0
