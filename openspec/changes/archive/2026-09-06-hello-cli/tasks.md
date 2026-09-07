## 1. Project scaffold

- [x] 1.1 Create `package.json`: `"type": "module"`, `"engines": {"node": ">=24"}`, `"bin": {"hello": "./dist/cli.js"}`, version `0.1.0`, and scripts `build`, `lint`, `format`, `format:check`, `test`. Verify `npm pkg get type bin engines` returns the expected values.
- [x] 1.2 Add `node_modules/` and `dist/` to `.gitignore`. Verify `git status --porcelain` stays empty after a build and an install.
- [x] 1.3 Create `tsconfig.json` targeting ES2023 modules with `strict: true`, `resolveJsonModule: true`, `outDir: "dist"`, and an include covering `src/` plus `package.json` (needed for the version import). Verify `npx tsc --noEmit` exits 0 on an empty `src/`.
- [x] 1.4 Install the dev dependencies at the versions design.md fixes: `typescript@6.0.3`, `@types/node@26.4.1`, `eslint@10.10.0`, `@eslint/js@10.0.1`, `typescript-eslint@8.69.0`, `prettier@3.9.6`, `eslint-config-prettier@10.1.8`. Verify `npm ls` reports no unmet peer dependencies — in particular that `typescript-eslint` accepts TypeScript 6.0.3.

## 2. Lint and format

- [x] 2.1 Create `eslint.config.js` (flat config) composing `@eslint/js` recommended, `typescript-eslint` type-checked rules with `parserOptions.projectService: true`, and `eslint-config-prettier` **last**. Verify `npx eslint .` exits 0 on the empty tree.
- [x] 2.2 Create `.prettierrc` and a `.prettierignore` excluding `dist/`. Verify `npx prettier --check .` exits 0.
- [x] 2.3 Confirm the two tools do not fight: introduce a deliberate formatting deviation, run `npm run format`, then `npm run lint`, and verify both pass with no rule reporting the formatting Prettier just applied.

## 3. Core implementation

- [x] 3.1 Implement `src/greet.ts` exporting a pure `greet(name: string): string` that returns `` `Hello, ${name}!` `` and throws a typed usage error when the name is empty or whitespace-only. Trim only to test validity; greet with the original string. Verify against spec requirements "Greet a named person" and "Reject an empty name".
- [x] 3.2 Implement `src/cli.ts` argument parsing with `parseArgs` from `node:util`, using `allowPositionals: true` and default strict mode, and options `help` and `version` (both boolean). Verify `hello Ada` prints `Hello, Ada!` and exits 0.
- [x] 3.3 Order the branches help → version → argument validation, so `--help` wins over otherwise-invalid arguments. Verify `hello --help Ada Grace` exits 0 and prints usage, per the spec scenario "Help is requested alongside invalid arguments".
- [x] 3.4 Import the version from `package.json` with `with { type: "json" }` and print it for `--version`. Verify the printed string equals `npm pkg get version`, satisfying "Report its version".
- [x] 3.5 Route every diagnostic to stderr and exit 1; keep stdout to the greeting, help, and version only. Catch `ERR_PARSE_ARGS_UNKNOWN_OPTION` from `parseArgs` and report it as a usage error rather than letting the stack trace escape. Verify "Reject unknown options" and "Keep diagnostics off stdout".
- [x] 3.6 Reject two or more positionals with a message naming the count received. Verify `hello Ada Grace` exits 1 and stderr states that one name was expected and two were given.
- [x] 3.7 Verify the build: `npm run build` exits 0 and `node dist/cli.js World` prints `Hello, World!`.

## 4. Tests

- [x] 4.1 Write `test/greet.test.ts` covering `greet` directly: a plain name, a name with internal spaces, a non-ASCII name, the empty string, and a whitespace-only string. Verify `npm test` passes and every scenario under "Greet a named person" and "Reject an empty name" has a case.
- [x] 4.2 Write `test/cli.test.ts` driving the built CLI as a child process for the cases that only exist at the process boundary: exit codes, stdout/stderr separation, `--help`, `--version`, unknown option, and too many arguments. Verify each asserts on exit status *and* which stream carried the output.
- [x] 4.3 Cross-check the suite against `openspec/changes/hello-cli/specs/hello-cli/spec.md` and confirm every `#### Scenario:` has a corresponding assertion. Verify by listing scenario names beside test names; any gap is a missing test, not a spec to edit.

## 5. Documentation

- [x] 5.1 Fill in the placeholder sections of `openspec/project.md` — purpose, tech stack, repository layout, conventions, and the TypeScript version constraint from design.md. Verify no `<!-- TODO` markers remain in the file.
- [x] 5.2 Add a Usage section to `README.md` showing `hello <name>`, `--help`, and `--version`, including the exit codes. Verify each command shown produces exactly the documented output when run.

## 6. Integration

- [x] 6.1 Run the full gate in one pass — `npm run lint && npm run format:check && npm run build && npm test` — and verify it exits 0 from a clean `node_modules` install.
- [x] 6.2 Commit through the project hooks and verify `pre-commit` and `commit-msg` accept the change, and that no build output or `node_modules` is staged.

## 7. Quality gate in the git hooks

- [x] 7.1 Add `.githooks/_gate.sh` defining a shared `run_gate <commit|push>` that runs `format:check`, `lint`, `build` and `test` in order and reports which step failed. Verify it no-ops when `package.json` is absent and honours `SKIP_GATE=1`.
- [x] 7.2 Call the gate from `pre-commit`, scoped to commits that stage code or config so a docs-only commit stays fast. Verify a lint error, a format error and a failing test each block a commit, and that a docs-only commit skips the gate.
- [x] 7.3 Call the gate from `pre-push` unconditionally, and make a missing `node_modules` block a push while only warning on commit. Verify by moving `node_modules` aside and running both hooks.
- [x] 7.4 Document the gate, its bypasses (`--no-verify`, `SKIP_GATE=1`) and the working-tree-vs-staged-tree caveat in `CLAUDE.md`. Verify the documented commands behave as described.

