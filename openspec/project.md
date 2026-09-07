# Project Context

Human-readable context for this project. Agents read this before proposing or
implementing a change. Keep it short, current, and specific — delete anything
that goes stale rather than letting it mislead.

## Purpose

`agentic-sdlc-test` is a testbed for an agent-driven software development
lifecycle: OpenSpec for spec-driven planning, trunk-based development with no
pull requests, and guardrails that let several agents and git worktrees work the
same repository without clobbering each other.

The `hello` CLI it ships is deliberately trivial. It exists so the workflow has
real code to act on — something to lint, build, test, commit through the hooks,
and archive.

## Tech Stack

- Language: TypeScript 6.0.3 (ESM, `"type": "module"`)
- Runtime: Node.js >= 24 (developed on 24.18.0)
- Package manager: npm
- Lint: ESLint 10 + typescript-eslint 8, type-aware (`projectService`)
- Format: Prettier 3
- Test: `node:test` + `node:assert/strict`, no test framework dependency
- Runtime dependencies: none

**Version constraint:** TypeScript is pinned to 6.0.3, not the latest 7.0.2,
because `typescript-eslint@8.69.0` declares `peerDependencies.typescript:
">=4.8.4 <6.1.0"`. TypeScript 7 is the Go-native rewrite and typescript-eslint
does not support it yet. Revisit on the next typescript-eslint major; the
migration is a version bump, not a rewrite.

## Repository Layout

- `src/` — CLI source. `greet.ts` is pure; `cli.ts` owns argv, streams and exit codes.
- `test/` — `node:test` suites. `greet.test.ts` calls functions; `cli.test.ts` spawns the built binary.
- `dist/` — build output (gitignored). Note `rootDir: "."`, so the binary lands at `dist/src/cli.js`.
- `openspec/` — spec-driven planning artifacts. See `openspec/AGENTS.md`.
- `.githooks/` — versioned git hooks, enabled via `core.hooksPath`.
- `scripts/` — `setup-dev.sh` (per-clone bootstrap) and `agent-guard.sh` (agent hooks).

## Conventions

- Commits: imperative subject, <= 72 chars, no `wip`/`temp`/`fixup`. Enforced by `commit-msg`.
- Branches: trunk-based on `main`. No PRs. Branches live hours, not days; `pre-push` refuses one diverged more than 48h.
- Code style: Prettier owns formatting, ESLint owns correctness. `eslint-config-prettier` is last in the flat config so they cannot fight.
- Prettier does **not** touch `openspec/` or `.claude/` — OpenSpec markdown structure is parsed by `openspec validate --strict`, and `.claude/` is vendored.
- Testing: every `#### Scenario:` in a spec needs a corresponding assertion. Behavior that only exists at the process boundary (exit codes, stream routing) is tested by spawning the real binary.
- Before pushing: `npm run lint && npm run format:check && npm run build && npm test`. The `pre-push` hook runs exactly this.

## Domain Glossary

| Term | Meaning |
| ---- | ------- |
| trunk | The `main` branch. The only long-lived branch. |
| gate | `format:check` + `lint` + `build` + `test`, run by `.githooks/_gate.sh`. |
| lease | A short-lived claim an agent session holds on a file, so two sessions in one worktree cannot write it at once. |
| capability | An OpenSpec behavior contract under `openspec/specs/<path>/spec.md`. |
| delta spec | A change's `specs/` file: what this change adds or alters, not a full copy. |

## Constraints & Non-Goals

- No pull requests and no long-lived branches. Integration happens on `main`.
- The `hello` CLI takes no runtime dependencies; its behavior should be a function of Node itself.
- Not published to a registry. The `bin` entry exists but installing it globally is out of scope.
- No hosted CI yet. The git hooks are the gate; they are local and bypassable with `--no-verify`.
