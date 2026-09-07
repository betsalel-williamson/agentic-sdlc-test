# agentic-sdlc-test

## Workflow: agentic trunk-based development

`main` is the trunk. There are **no pull requests and no long-lived branches**.
Work is integrated into `main` continuously, by humans and agents alike.

- Commit small and often. Every commit on `main` should stand on its own.
- Push at least once per working session. Unpushed work is work nobody else
  can build on and everybody else can conflict with.
- Rebase, never merge: `git pull --rebase`. The trunk stays linear.
- If you need isolation, use a git worktree with a branch that lives **hours,
  not days**, and merge it down the same day. `pre-push` refuses a branch that
  has been diverged from `main` for more than 48h.

Planning still goes through OpenSpec — see `openspec/AGENTS.md`. Planning
artifacts are committed to `main` like anything else; a change proposal is not
a branch.

## Guardrails

Two independent layers. Git hooks bind everyone; the Claude hooks bind agents.

### Git hooks — `.githooks/`, enabled via `core.hooksPath`

| Hook         | Refuses                                                                                                                                                                                                        |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pre-commit` | staged conflict markers, blobs over 2MB, committed lock state; warns on a branch diverged 2+ days; **runs the quality gate when code or config is staged**                                                     |
| `commit-msg` | empty subjects, subjects over 72 chars, `wip`/`temp`/`fixup` placeholders                                                                                                                                      |
| `pre-push`   | non-fast-forward pushes, conflict markers in the pushed range, branches older than 48h, **branches not rebased on current trunk**, pushing `main` while behind `origin/main`; **always runs the quality gate** |

`pre-push` fetches `<remote>/<trunk>` before its per-ref checks, so
"is this integrated?" is answered against the remote as it is now, not as of
your last fetch. If the fetch fails (offline) the integration checks are skipped
with a warning rather than blocking the push.

### The quality gate — `.githooks/_gate.sh`

`format:check` -> `lint` -> `build` -> `test`, in that order, stopping at the
first failure and printing that step's output. Roughly 3s on this repo.

- `pre-commit` runs it **only when a `.ts`/`.js`/`.json` or config file is
  staged**, so a docs-only commit costs ~0.1s instead of ~3s.
- `pre-push` runs it **unconditionally**, and additionally **fails** when
  `node_modules` is missing — unverified work must not reach trunk. On commit a
  missing `node_modules` only warns, so you can still commit on a fresh clone.
- Bypass: `git commit --no-verify` / `git push --no-verify`, or `SKIP_GATE=1`.
- Caveat: the gate runs against the **working tree**, not the staged tree. With
  the whole-tree commits this workflow expects those are the same; if you stage
  a subset deliberately, verify before committing.

`core.hooksPath` is per-clone config and is **not** carried by `git clone`.
After cloning, run:

```bash
./scripts/setup-dev.sh
```

That also sets the trunk-based git defaults: `pull.rebase`, `rebase.autoStash`,
`fetch.prune`, `rerere.enabled` (so a conflict resolved once is not re-resolved
by every agent), and `merge.conflictstyle=zdiff3`. A Claude Code session
re-applies `core.hooksPath` on its own at `SessionStart`, so an agent working in
a fresh worktree is covered without the manual step.

### Agent hooks — `.claude/settings.json` → `scripts/agent-guard.sh`

| Event                          | Behavior                                                                                                                                            |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SessionStart`                 | registers the session; reports the branch, uncommitted count, and any other live agent sessions                                                     |
| `PreToolUse` / `Bash`          | **denies** commands that destroy work (below)                                                                                                       |
| `PreToolUse` / `Write`,`Edit`  | takes a lease on the file; **denies** if another live session in the _same_ worktree holds it, **warns** if the holder is in a _different_ worktree |
| `PostToolUse` / `Write`,`Edit` | refreshes the lease                                                                                                                                 |
| `Stop`                         | releases the session's leases; reports uncommitted and unpushed work                                                                                |
| `SessionEnd`                   | deregisters the session and drops its leases                                                                                                        |

Denied commands: `git reset --hard`, `git clean -f*`, `git checkout/restore .`,
`git push --force` (and `+refspec`), `git branch -D`,
`git worktree remove --force`, `git stash drop|clear`, `git filter-branch`,
`git reflog expire --expire=now`, and `rm -rf` aimed at `.git`, the repo root,
`/`, or `$HOME`.

Every denial is a speed bump, not a wall. Re-run the command prefixed with
`AGENT_GUARD_OVERRIDE=1` and state why.

Leases and the session registry live in the git **common** directory
(`.git/agent-locks/`), so all worktrees of this clone share one view. Leases go
stale after 15 minutes and session records after 4 hours, so a crashed agent
never wedges the repo. The guard fails **open**: any internal error allows the
tool call through, because a jammed agent is worse than the clobber it prevents.

Tuning knobs (environment variables): `AGENT_GUARD_TRUNK`,
`AGENT_GUARD_LEASE_TTL`, `AGENT_GUARD_SESSION_TTL`,
`AGENT_GUARD_MAX_BRANCH_AGE_HOURS`, `AGENT_GUARD_MAX_FILE_KB`.

## Working alongside other agents

```bash
git worktree list          # who has a tree checked out where
git fetch origin && git log --oneline origin/main -10
```

New worktrees branch from `origin/main` (`worktree.baseRef: "fresh"`), so an
agent never inherits another agent's half-finished state.
