#!/usr/bin/env bash
# Shared quality gate for pre-commit and pre-push.
#
# Sourced, not executed. Defines run_gate <mode>, where mode is "commit"
# (missing deps warn and skip) or "push" (missing deps block — unverified work
# must not reach trunk).
#
# Bypass for both: `git commit --no-verify` / `git push --no-verify`, or
# SKIP_GATE=1.
#
# Note: the gate runs against the working tree, not the staged tree. With the
# small, whole-tree commits this workflow expects that is the same thing; if
# you stage a subset, verify before you commit.

gate_fail() { printf '\033[31m%s: %s\033[0m\n' "${HOOK_NAME:-hook}" "$1" >&2; }
gate_warn() { printf '\033[33m%s: %s\033[0m\n' "${HOOK_NAME:-hook}" "$1" >&2; }
gate_info() { printf '\033[2m%s: %s\033[0m\n' "${HOOK_NAME:-hook}" "$1" >&2; }

run_gate() {
  local mode="$1" root log step
  root="$(git rev-parse --show-toplevel)" || return 0
  cd "$root" || return 0

  if [ "${SKIP_GATE:-}" = "1" ]; then
    gate_warn "SKIP_GATE=1 — quality gate skipped."
    return 0
  fi

  # Nothing to check until the project has a manifest.
  [ -f package.json ] || return 0

  if [ ! -d node_modules ]; then
    if [ "$mode" = "push" ]; then
      gate_fail "node_modules is missing, so lint, build and test cannot run.
         Run: npm ci
         Unverified work must not reach trunk. Override with --no-verify."
      return 1
    fi
    gate_warn "node_modules missing — gate skipped for this commit. Run 'npm ci'."
    return 0
  fi

  log="$(mktemp)"
  for step in "format:check" "lint" "build" "test"; do
    if ! npm run --silent "$step" >"$log" 2>&1; then
      gate_fail "npm run $step failed:"
      tail -30 "$log" >&2
      [ "$step" = "format:check" ] && gate_info "Fix with: npm run format"
      rm -f "$log"
      return 1
    fi
  done
  rm -f "$log"
  gate_info "format, lint, build and test all passed."
  return 0
}
