# claude-code-cast

Cast integration for Claude Code. The `cast` Claude Code plugin emits Coven Agent Event Protocol v0 events from Claude Code hooks so local-first Cast, Coven daemon, TUI, comux, and future UI surfaces can consume the same agent status stream.

## Status

This is the first minimal plugin version. It ships shell hooks, a shared event builder, a terminal transport, and an optional JSONL debug transport. It does not implement daemon ingestion yet.

## Install

Install the local marketplace or plugin through Claude Code using this repository path. The marketplace file lives at:

```text
.claude-plugin/marketplace.json
```

The plugin source is:

```text
plugins/cast
```

The installed plugin name is `cast`.

## Requirements

- `bash`
- `jq`

If `jq` is missing, each hook exits successfully and prints a clear Claude Code system message:

```text
claude-code-cast requires jq to emit Cast agent events; install jq to enable hooks.
```

Hooks are best effort and should not break Claude Code sessions.

## Hook Coverage

| Claude Code hook | Protocol event |
| --- | --- |
| `SessionStart` with matcher `startup|resume` | `session.started` |
| `UserPromptSubmit` | `prompt.submitted` |
| `PermissionRequest` | `permission.needed` |
| `Notification` with matcher `idle_prompt` | `session.blocked` |
| `PostToolUse` | `tool.completed` |
| `Stop` | `session.completed` |

`tool.running`, `session.resumed`, and `session.failed` are reserved protocol events. V0 only emits them when a reliable source exists; the current implementation does not infer noisy state transitions.

## Protocol Envelope

Every event uses Coven Agent Event Protocol v0:

```json
{
  "protocol": "coven.agent-event",
  "version": 0,
  "event": "session.started",
  "source": {
    "adapter": "claude-code-cast",
    "agent": "claude-code",
    "pluginVersion": "0.1.0"
  },
  "session": {
    "id": "claude-session-id",
    "cwd": "/path/to/repo",
    "project": "repo",
    "castSessionId": null
  },
  "time": "2026-05-19T11:15:00Z",
  "summary": "Claude Code session started.",
  "data": {}
}
```

Required top-level fields are `protocol`, `version`, `event`, `source`, `session`, `time`, `summary`, and `data`.

## Transports

### Terminal

By default, hooks emit a Claude Code hook output object with a `terminalSequence` field. The sequence uses an OSC 777 style frame with a Cast URI:

```text
ESC ] 777 ; cast://agent-event ; <event-json> BEL
```

Disable terminal output for debugging:

```sh
CAST_AGENT_EVENT_TERMINAL=0
```

### JSONL Debug Log

Set `CAST_AGENT_EVENT_LOG` to append one compact JSON event per line:

```sh
CAST_AGENT_EVENT_LOG=/tmp/claude-code-cast.jsonl
```

### Future Daemon

Coven daemon ingestion is intentionally not implemented in v0. The event envelope is transport-neutral so a future Unix socket or local HTTP route can consume the same JSON.

## Privacy

V0 emits previews and safe metadata only.

- Prompt preview is truncated to 200 characters.
- Response preview is truncated to 200 characters.
- Tool preview is truncated to 120 characters.
- Tool input is limited to safe fields: `description`, `file_path`, `path`, `url`, and `pattern`.
- Full transcripts, command output, environment dumps, and secrets are not emitted.
- `transcriptPath` is allowed only as a local reference on `session.completed`.

## Tests

Run:

```sh
plugins/cast/tests/test-hooks.sh
```

The test suite covers the shared event builder, every hook script, preview truncation, safe tool input redaction, JSONL transport, and missing-`jq` behavior.

If `shellcheck` is available, run:

```sh
shellcheck plugins/cast/scripts/*.sh plugins/cast/tests/test-hooks.sh
```

`shellcheck` is recommended but not required by the plugin.

## License and Attribution

This repository is MIT licensed.

The implementation shape was informed by the MIT-licensed `warpdotdev/claude-code-warp` project: Claude Code plugin metadata, hook registration, shell hook scripts, tests, and terminal event emission. This repository does not copy or depend on AGPL Warp client code, `session-sharing-protocol`, or `warp-proto-apis`.
