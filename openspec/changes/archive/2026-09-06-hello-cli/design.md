## Context

The repository has no `package.json`, no source tree, and no CI. Every toolchain
decision here is therefore a default that later changes inherit, which is why a
one-function CLI gets a design document at all. See `proposal.md` — Why.

The binding external constraint is a peer-dependency conflict:
`typescript-eslint@8.69.0` declares `peerDependencies.typescript: ">=4.8.4
<6.1.0"`, so the latest TypeScript (7.0.2, the Go-native rewrite) cannot be used
with it. Node 24.18.0 is installed; ESLint 10 requires `^20.19.0 || ^22.13.0 ||
>=24`.

## Goals / Non-Goals

**Goals:**

- A toolchain later changes can adopt without revisiting these questions.
- Every scenario in `specs/hello-cli/spec.md` reachable by a fast unit test,
  with exit codes and stream routing verified for real at least once.
- Zero runtime dependencies, so the CLI's behavior is a function of Node itself.

**Non-Goals:**

- Publishing to a registry, or a global `hello` binary on `PATH`. The `bin`
  entry exists; installing it is out of scope.
- Internationalization, colored output, or a plugin surface.
- CI. There is no pipeline to add to yet; the git hooks carry that weight.

## Decisions

**TypeScript 6.0.3, not 7.0.2.** Chosen so `typescript-eslint` works, which buys
type-aware lint rules (`no-floating-promises` and friends) that catch a class of
bug plain syntactic linting cannot. *Alternative considered:* TypeScript 7 with
Biome as a single lint+format tool — no peer conflict, faster, one config file,
but Biome has no type-aware rules. The type-aware rules won. Revisit when
typescript-eslint supports TypeScript 7; the migration is a version bump and a
config swap, not a rewrite.

**`node:util` `parseArgs`, not commander or yargs.** The argument grammar is one
positional and two flags. A dependency would be larger than the program.
`parseArgs` needs `allowPositionals: true` (it throws
`ERR_PARSE_ARGS_UNEXPECTED_POSITIONAL` otherwise) and rejects undefined options
with `ERR_PARSE_ARGS_UNKNOWN_OPTION` in its default strict mode, which satisfies
the unknown-option requirement without custom code. *Alternative:* hand-rolled
`process.argv` slicing — rejected; it is exactly the code that grows error cases
nobody tests.

**Split a pure `greet(name)` from the I/O shell.** `greet` maps a name to a
greeting string or throws a typed usage error; `cli.ts` owns `process.argv`,
the streams, and the exit code. This is what makes the spec's scenarios cheap to
test — most become direct function calls rather than child processes. *Alternative:*
one file that reads argv and prints — rejected; every test would have to spawn a
process, and the error branches would go untested in practice.

**Validate in a fixed order: help → version → argument errors.** The spec
requires `--help` to work even alongside otherwise-invalid arguments. `parseArgs`
already returns `{help: true}` for `hello --help Ada Grace` without complaint, so
this needs only that the help branch be checked before positional-count
validation — no pre-scan of `argv`.

**Treat a whitespace-only name as missing.** `parseArgs` returns `""` as a
perfectly good positional, so the empty and whitespace cases are ours to catch.
`greet` trims only for the *validity check* and greets with the original
string, so `hello " Ada "` prints `Hello,  Ada !` — surrounding spaces are
preserved, not silently trimmed. Only a name that is entirely whitespace is
rejected.

**`node:test` and `node:assert`, not Vitest or Jest.** Built in, no dependency,
no transform pipeline. The suite is small enough that a watch-mode runner earns
nothing here.

**ESM (`"type": "module"`), not CommonJS.** Matches current Node and the
`node:` imports used throughout.

**Read the version from `package.json` via an import attribute** (`import pkg
from "../package.json" with { type: "json" }`). The spec requires the reported
version to match the manifest; importing it makes drift impossible.
*Alternative:* a hardcoded constant — rejected, it is a guaranteed future
inconsistency.

**`eslint-config-prettier` last in the ESLint config.** ESLint and Prettier
overlap on stylistic rules and will fight; this disables the ESLint half.
Formatting is Prettier's job, correctness is ESLint's.

## Risks / Trade-offs

- **TypeScript pinned a major behind latest** → Recorded here and in the
  proposal with the exact peer range that forces it, so the constraint is
  re-checkable rather than folklore. Revisit on the next `typescript-eslint`
  major.
- **Type-aware linting needs `parserOptions.projectService`, which is slower** →
  Acceptable on a source tree this size; revisit if lint time becomes noticeable.
- **JSON import attributes make `tsconfig` fussier** (`resolveJsonModule`, and
  emitting `package.json` outside `rootDir` must not break the build) → Keep
  `rootDir: "."`-relative output layout in mind when configuring; verified by
  the build task before the CLI is wired up.
- **Unit-testing `greet` directly leaves exit codes and stream routing unproven**
  → Deliberately covered by a small number of real child-process tests, not by
  unit tests alone. The "keep diagnostics off stdout" requirement is only
  meaningful at the process boundary.
- **No CI server** → Resolved within this change rather than deferred: the
  `pre-commit` and `pre-push` hooks now run the gate themselves (see task group
  7). `pre-commit` runs it only when code or config is staged, so a docs-only
  commit stays fast; `pre-push` always runs it and additionally *blocks* when
  `node_modules` is absent, since unverified work must not reach trunk. A hosted
  pipeline is still worth adding when this repo gains a remote CI target; the
  hooks are a local gate, and `--no-verify` can bypass them.
