# agentic-sdlc-test

A testbed for an agent-driven SDLC: OpenSpec planning, trunk-based development
without pull requests, and guardrails for multiple agents and git worktrees
sharing one repository. See `CLAUDE.md` for the workflow and `openspec/AGENTS.md`
for the spec process.

The `hello` CLI below is the worked example those processes act on.

## Setup

```bash
npm ci
./scripts/setup-dev.sh   # installs git hooks (once per clone)
npm run build
```

## Usage

Greet someone:

```console
$ node dist/src/cli.js World
Hello, World!
```

The name is reproduced verbatim — spaces, casing and non-ASCII all survive:

```console
$ node dist/src/cli.js "Ada Lovelace"
Hello, Ada Lovelace!
```

Show usage:

```console
$ node dist/src/cli.js --help
Usage: hello <name>

Print a greeting for the given name.

Arguments:
  <name>         The name to greet. Exactly one is required.

Options:
  -h, --help     Show this help and exit.
  -v, --version  Show the version and exit.
```

Show the version, which always matches `package.json`:

```console
$ node dist/src/cli.js --version
0.1.0
```

### Exit codes

| Code | When                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------- |
| `0`  | The greeting was printed, or `--help` / `--version` was handled.                                  |
| `1`  | Usage error: no name, an empty or whitespace-only name, more than one name, or an unknown option. |

Diagnostics go to stderr, never stdout — so `hello "$n" > out.txt` leaves
`out.txt` empty on failure rather than half-written.

```console
$ node dist/src/cli.js Ada Grace
expected exactly one name, but received 2
...
$ echo $?
1
```

## Development

```bash
npm run lint          # eslint, type-aware
npm run format        # prettier --write
npm run format:check  # prettier --check
npm run build         # tsc
npm test              # build, then node --test
```

`pre-commit` runs that gate when code or config is staged; `pre-push` always
runs it. Bypass with `--no-verify` or `SKIP_GATE=1` when you must.
