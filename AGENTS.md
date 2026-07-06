# AGENTS.md — claude-code-cast

Guidance for **AI agents** (Codex, Claude Code, and any Coven familiar) opening
pull requests against this repo. This is the agent-specific layer; read
[`README.md`](README.md) for the full picture.

> **What this repo is:** the `cast` Claude Code plugin. It emits **Coven Agent
> Event Protocol v0** events from Claude Code hooks so local-first Cast, the
> Coven daemon, TUI, comux, and future UI surfaces can consume the same agent
> status stream.

## Branch & PR workflow

- **Never push to `main`.** Every change lands via a PR. Branch from current
  `origin/main`.
- **Fresh branch per task**; use a worktree if multiple sessions may touch this
  repo:
  ```sh
  git fetch origin main
  git worktree add -b <branch> /tmp/cccast-<branch> origin/main
  ```
- Keep the diff scoped to one concern; conventional-commit subjects (`feat:`,
  `fix:`, `docs:`, `chore:`, `refactor:`).
- After merge: delete the remote branch, remove your local worktree/branch.

## Before opening the PR

- The hooks are **shell scripts** — keep them POSIX-portable, quote variables,
  and fail safe. A hook that errors must not break the host Claude Code session.
- Test hooks end-to-end where possible: trigger the Claude Code hook and confirm
  a well-formed Agent Event Protocol v0 event is emitted.
- `shellcheck` your scripts before submitting.

## Repo-specific invariants (don't break these)

- **Conform to Coven Agent Event Protocol v0.** Event shape/field names are a
  contract consumed by Cast, the daemon, TUI, and comux. Don't rename or drop
  fields without coordinating the protocol change across consumers.
- **Emit, don't block.** The plugin observes and reports agent status; it must
  never gate or slow the host session waiting on a consumer.
- **No secrets in emitted events or committed files.** Event payloads may travel
  to multiple local surfaces — keep tokens and private data out.

## Attribution — credit contributors correctly

When you re-land or build on someone else's work (a fork PR, an issue author's
proposal, a co-author), **credit the human contributor with a working
GitHub-linked trailer** so they appear in the contributors graph and on their
profile:

```
Co-authored-by: Full Name <ID+username@users.noreply.github.com>
```

- Use the **numeric-id no-reply form**. Get the id with `gh api users/<login> --jq .id`.
- **Never** use a machine or `.local` email (e.g. `name@Someones-Mac.local`) in a
  co-author trailer — it links to no account and gives **zero** credit.
- When a squash-merge folds a contributor's PR into an internal branch, preserve
  their `Co-authored-by:` line in the squash commit message.
- Credit **people**, not AI tools.

## Secrets & safety

- Never commit secrets, tokens, or private emails. Use `*.noreply.github.com`
  for attribution.
- Don't disable safeguards to land a change; surface the blocker instead.

## Claude Code

`CLAUDE.md` points here — this file is the source of truth for both.
