#!/usr/bin/env bash
set -euo pipefail

JQ="${CLAUDE_CODE_CAST_JQ:-jq}"
EVENT_JSON="$(cat)"

if ! command -v "$JQ" >/dev/null 2>&1; then
  exit 0
fi

COMPACT_EVENT="$("$JQ" -c . <<<"$EVENT_JSON" 2>/dev/null || true)"
if [[ -z "$COMPACT_EVENT" ]]; then
  exit 0
fi

printf '\033]777;cast://agent-event;%s\a' "$COMPACT_EVENT"
