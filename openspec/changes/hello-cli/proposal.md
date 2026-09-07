## Why

This repository has an OpenSpec workflow and trunk-based guardrails but no
executable code, so neither has ever been exercised against a real build. A
small, complete CLI is the cheapest way to prove the whole loop — propose,
apply, lint, build, commit through the hooks, push to trunk — and to fix the
Node/TypeScript toolchain that every later change will inherit.

The tool itself is deliberately trivial. The toolchain decisions it forces are
not.

## What Changes

- Add a Node.js/TypeScript CLI, `hello`, that prints `Hello, <name>!` to stdout
  and exits 0.
- Take the name as a positional command-line argument, parsed with the built-in
  `node:util` `parseArgs` — no argument-parsing dependency.
- Handle the error cases explicitly: no name given, more than one name given,
  and an empty or whitespace-only name. Each writes a usage message to stderr
  and exits with a non-zero status.
- Support `--help` and `--version`, both to stdout with exit 0.
- Establish the project toolchain, currently absent: `package.json` (ESM),
  TypeScript 6.0.3, ESLint 10 with typescript-eslint 8, and Prettier 3.
- Add `node:test` unit tests covering the success path and every error case.
- Extend `openspec/project.md`, which is still a skeleton of placeholders, with
  the stack and conventions this change fixes.

## Capabilities

### New Capabilities
- `hello-cli`: the greeting command's observable contract — its argument
  grammar, stdout/stderr output, and exit codes.

### Modified Capabilities
<!-- None. This is the first capability in the repository. -->

## Impact

- **New files**: `package.json`, `tsconfig.json`, `eslint.config.js`,
  `.prettierrc`, `src/cli.ts`, `src/greet.ts`, `test/greet.test.ts`.
- **Modified files**: `openspec/project.md` (fill in the placeholders),
  `.gitignore` (ignore `node_modules/` and `dist/`).
- **Runtime**: Node 24 or newer. ESLint 10 requires `^20.19.0 || ^22.13.0 ||
  >=24`; Node 24.18.0 is what is installed here.
- **Dependencies**: no runtime dependencies. Dev-only: `typescript@6.0.3`,
  `eslint@10`, `typescript-eslint@8`, `prettier@3`, `eslint-config-prettier@10`,
  `@types/node@26`.
- **Version constraint**: TypeScript is pinned to 6.0.3 rather than the latest
  7.0.2 because `typescript-eslint@8.69.0` declares
  `peerDependencies.typescript: ">=4.8.4 <6.1.0"`. TypeScript 7 is the
  Go-native rewrite and typescript-eslint does not support it yet. Revisit when
  it does; the alternative was dropping type-aware lint rules for Biome.
- **CI**: none exists yet. This change does not add any; `lint`, `build`, and
  `test` are npm scripts a human or agent runs, and the `pre-commit` hook keeps
  broken commits off trunk in the meantime.
