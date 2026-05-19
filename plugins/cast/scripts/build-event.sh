#!/usr/bin/env bash
set -euo pipefail

JQ="${CLAUDE_CODE_CAST_JQ:-jq}"
EVENT="${1:-}"
SUMMARY="${2:-}"
if [[ $# -ge 3 ]]; then
  DATA_JSON="$3"
else
  DATA_JSON="{}"
fi
PLUGIN_VERSION="${CAST_PLUGIN_VERSION:-0.1.0}"
INPUT="$(cat)"

if ! command -v "$JQ" >/dev/null 2>&1; then
  printf '{"systemMessage":"claude-code-cast requires jq to emit Cast agent events; install jq to enable hooks."}\n'
  exit 0
fi

if [[ -z "${INPUT//[[:space:]]/}" ]]; then
  INPUT="{}"
fi

if [[ -z "$EVENT" || -z "$SUMMARY" ]]; then
  printf '{"protocol":"coven.agent-event","version":0,"event":"session.failed","source":{"adapter":"claude-code-cast","agent":"claude-code","pluginVersion":"%s"},"session":{"id":"","cwd":"","project":"","castSessionId":null},"time":"%s","summary":"claude-code-cast could not build an event.","data":{"stage":"build-event","error":"missing event or summary"}}\n' \
    "$PLUGIN_VERSION" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  exit 0
fi

"$JQ" -c \
  --arg event "$EVENT" \
  --arg summary "$SUMMARY" \
  --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --arg plugin_version "$PLUGIN_VERSION" \
  --arg fallback_cwd "$PWD" \
  --argjson data "$DATA_JSON" \
  '
  def clean_string:
    if . == null then "" else tostring end;

  . as $hook
  | ($hook.session_id // $hook.sessionId // $hook.session.id // "") as $session_id
  | ($hook.cwd // $hook.workspace.current_dir // $hook.workspace.cwd // $hook.project_cwd // $fallback_cwd) as $cwd
  | {
      protocol: "coven.agent-event",
      version: 0,
      event: $event,
      source: {
        adapter: "claude-code-cast",
        agent: "claude-code",
        pluginVersion: $plugin_version
      },
      session: {
        id: ($session_id | clean_string),
        cwd: ($cwd | clean_string),
        project: (($cwd | clean_string | rtrimstr("/") | split("/") | last) // ""),
        castSessionId: null
      },
      time: $time,
      summary: $summary,
      data: $data
    }
  ' <<<"$INPUT"
