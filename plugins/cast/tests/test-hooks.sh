#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
TMP_DIR="$(mktemp -d)"
LOG_FILE="$TMP_DIR/events.jsonl"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "$expected" != "$actual" ]]; then
    fail "$label: expected '$expected', got '$actual'"
  fi
}

assert_json_field() {
  local json="$1"
  local filter="$2"
  local expected="$3"
  local label="$4"
  local actual

  actual="$(jq -r "$filter" <<<"$json")"
  assert_eq "$expected" "$actual" "$label"
}

last_event() {
  tail -n 1 "$LOG_FILE"
}

run_hook() {
  local script="$1"
  local input="$2"

  CAST_AGENT_EVENT_LOG="$LOG_FILE" \
    CAST_AGENT_EVENT_TERMINAL=0 \
    "$SCRIPTS_DIR/$script" <<<"$input" >/tmp/claude-code-cast-test.out
}

builder_input='{
  "session_id": "sess-123",
  "cwd": "/tmp/example-project",
  "reason": "startup"
}'

builder_output="$("$SCRIPTS_DIR/build-event.sh" \
  "session.started" \
  "Claude Code session started." \
  '{"reason":"startup"}' \
  <<<"$builder_input")"

assert_json_field "$builder_output" '.protocol' 'coven.agent-event' 'builder protocol'
assert_json_field "$builder_output" '.version | tostring' '0' 'builder version'
assert_json_field "$builder_output" '.event' 'session.started' 'builder event'
assert_json_field "$builder_output" '.source.adapter' 'claude-code-cast' 'builder adapter'
assert_json_field "$builder_output" '.source.agent' 'claude-code' 'builder agent'
assert_json_field "$builder_output" '.session.id' 'sess-123' 'builder session id'
assert_json_field "$builder_output" '.session.cwd' '/tmp/example-project' 'builder cwd'
assert_json_field "$builder_output" '.session.project' 'example-project' 'builder project'
assert_json_field "$builder_output" '.data.reason' 'startup' 'builder data'

run_hook "on-session-start.sh" "$builder_input"
assert_json_field "$(last_event)" '.event' 'session.started' 'session hook event'
assert_json_field "$(last_event)" '.data.reason' 'startup' 'session hook reason'

long_prompt="$(printf 'p%.0s' {1..240})"
run_hook "on-prompt-submit.sh" "$(jq -n --arg prompt "$long_prompt" --arg cwd "$PWD" '{
  session_id: "sess-prompt",
  cwd: $cwd,
  prompt: $prompt
}')"
assert_json_field "$(last_event)" '.event' 'prompt.submitted' 'prompt hook event'
assert_json_field "$(last_event)" '.data.promptLength | tostring' '240' 'prompt length'
assert_json_field "$(last_event)" '.data.promptPreview | length | tostring' '200' 'prompt preview truncation'

run_hook "on-permission-request.sh" '{
  "session_id": "sess-permission",
  "cwd": "/tmp/example-project",
  "tool_name": "Bash",
  "tool_input": {
    "command": "printf secret-token",
    "description": "print token"
  }
}'
assert_json_field "$(last_event)" '.event' 'permission.needed' 'permission hook event'
assert_json_field "$(last_event)" '.data.toolName' 'Bash' 'permission tool name'
assert_json_field "$(last_event)" '.data.toolPreview | contains("secret-token") | tostring' 'false' 'permission redacts command text'

run_hook "on-notification.sh" '{
  "session_id": "sess-blocked",
  "cwd": "/tmp/example-project",
  "notification_type": "idle_prompt",
  "message": "Claude is waiting for input"
}'
assert_json_field "$(last_event)" '.event' 'session.blocked' 'notification hook event'
assert_json_field "$(last_event)" '.data.reason' 'idle_prompt' 'notification reason'

run_hook "on-post-tool-use.sh" '{
  "session_id": "sess-tool",
  "cwd": "/tmp/example-project",
  "tool_name": "Read",
  "tool_input": {"file_path": "/tmp/example-project/README.md"},
  "tool_response": "full output should not be included"
}'
assert_json_field "$(last_event)" '.event' 'tool.completed' 'post tool hook event'
assert_json_field "$(last_event)" '.data.toolName' 'Read' 'post tool name'
assert_json_field "$(last_event)" 'has("tool_response") | tostring' 'false' 'post tool omits raw response'

run_hook "on-stop.sh" '{
  "session_id": "sess-stop",
  "cwd": "/tmp/example-project",
  "transcript_path": "/tmp/example-project/.claude/transcript.jsonl",
  "prompt": "short prompt",
  "response": "short response"
}'
assert_json_field "$(last_event)" '.event' 'session.completed' 'stop hook event'
assert_json_field "$(last_event)" '.data.transcriptPath' '/tmp/example-project/.claude/transcript.jsonl' 'stop transcript path'

missing_jq_output="$(CLAUDE_CODE_CAST_JQ=/no/such/jq "$SCRIPTS_DIR/on-session-start.sh" <<<"$builder_input")"
assert_json_field "$missing_jq_output" '.systemMessage' 'claude-code-cast requires jq to emit Cast agent events; install jq to enable hooks.' 'missing jq system message'

echo "claude-code-cast hook tests passed"
