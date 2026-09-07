#!/usr/bin/env bash
# One-time per-clone setup. Git hooks and git config are not carried by a
# clone, so every machine and every fresh clone runs this once. Claude Code's
# SessionStart hook re-applies core.hooksPath on its own, but a human clone
# needs this.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
echo "✓ hooks: .githooks (pre-commit, commit-msg, pre-push)"

# Trunk-based defaults. Each of these removes a way to strand or lose work.
git config pull.rebase true          # linear trunk; never an accidental merge commit
git config rebase.autoStash true     # a dirty tree can't block an integration
git config fetch.prune true          # dead remote branches don't linger
git config rerere.enabled true       # resolve a conflict once, not once per agent
git config merge.conflictstyle zdiff3
git config push.default current
echo "✓ git config: rebase-first, rerere on, prune on"

# Worktrees live inside the repo and must never be committed.
git config --get-all core.excludesFile >/dev/null 2>&1 || true

echo
echo "Trunk-based development: commit small, push to $(git config --get init.defaultBranch || echo main) often, no PRs."
echo "Run 'git worktree list' to see who else is working here."
