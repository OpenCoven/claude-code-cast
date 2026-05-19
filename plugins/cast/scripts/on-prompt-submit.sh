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
  (.prompt // .user_prompt // .message // "") as $prompt
  | {
      promptPreview: ($prompt | trunc(200)),
      promptLength: ($prompt | tostring | length)
    }
' <<<"$INPUT" 2>/dev/null || printf '{}')"
EVENT_JSON="$("$SCRIPT_DIR/build-event.sh" "prompt.submitted" "User submitted a Claude Code prompt." "$DATA" <<<"$INPUT" 2>/dev/null || true)"
if [[ -n "$EVENT_JSON" ]]; then
  "$SCRIPT_DIR/emit-event.sh" <<<"$EVENT_JSON" 2>/dev/null || true
fi

exit 0
