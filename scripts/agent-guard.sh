#!/usr/bin/env bash
# agent-guard.sh — keep concurrent Claude Code agents and git worktrees from
# clobbering each other in a trunk-based repo.
#
# Invoked from .claude/settings.json hooks. Reads the hook payload as JSON on
# stdin and writes a hook-protocol JSON object on stdout.
#
# Design rule: FAIL OPEN. Any internal error must allow the tool call through.
# A guard that wedges the agent is worse than the clobber it prevents.
#
# Subcommands:
#   session-start   register this session; report neighbours and repo state
#   session-end     deregister this session and drop its leases
#   stop            drop leases; nudge if work is uncommitted
#   guard-bash      block destructive git/rm commands
#   lease-acquire   claim a file before Write/Edit
#   lease-refresh   extend a held lease after a successful Write/Edit

set -uo pipefail

TRUNK="${AGENT_GUARD_TRUNK:-main}"
LEASE_TTL="${AGENT_GUARD_LEASE_TTL:-900}"        # seconds before a lease goes stale
SESSION_TTL="${AGENT_GUARD_SESSION_TTL:-14400}"  # seconds before a session record goes stale

# --- plumbing ---------------------------------------------------------------

now() { date +%s; }

# Emit a hook result and exit. $1=json object
emit() { printf '%s\n' "$1"; exit 0; }

allow() { emit '{"suppressOutput":true}'; }

deny() { # $1 = reason
  jq -nc --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

note() { # $1 = systemMessage, $2 = additionalContext (optional)
  jq -nc --arg m "$1" --arg c "${2:-}" --arg e "${HOOK_EVENT:-SessionStart}" '
    {systemMessage: $m}
    + (if $c == "" then {} else {hookSpecificOutput: {hookEventName: $e, additionalContext: $c}} end)
  '
  exit 0
}

repo_root() { git rev-parse --show-toplevel 2>/dev/null; }

lock_root() {
  local d
  d="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
  [ -n "$d" ] || return 1
  printf '%s/agent-locks' "$d"
}

key_for() { printf '%s' "$1" | shasum | cut -d' ' -f1; }

read_field() { # $1 = jq path, reads from $PAYLOAD
  printf '%s' "$PAYLOAD" | jq -r "$1 // empty" 2>/dev/null
}

# Relative path inside the repo, or empty if the file is outside it.
rel_path() { # $1 = absolute or relative file path
  local root abs
  root="$(repo_root)" || return 1
  abs="$1"
  case "$abs" in /*) ;; *) abs="$PWD/$abs" ;; esac
  case "$abs" in "$root"/*) printf '%s' "${abs#"$root"/}" ;; *) return 1 ;; esac
}

# --- session registry -------------------------------------------------------

session_file() { printf '%s/sessions/%s.json' "$1" "$2"; }

prune_stale() { # $1 = lock root
  local root="$1" f t cutoff
  cutoff=$(( $(now) - SESSION_TTL ))
  for f in "$root"/sessions/*.json; do
    [ -e "$f" ] || continue
    t="$(jq -r '.last_seen // 0' "$f" 2>/dev/null)"
    [ "${t:-0}" -lt "$cutoff" ] 2>/dev/null && rm -f "$f"
  done
  cutoff=$(( $(now) - LEASE_TTL ))
  for f in "$root"/leases/*/meta.json; do
    [ -e "$f" ] || continue
    t="$(jq -r '.refreshed // 0' "$f" 2>/dev/null)"
    if [ "${t:-0}" -lt "$cutoff" ] 2>/dev/null; then rm -rf "$(dirname "$f")"; fi
  done
  return 0
}

release_leases() { # $1 = lock root, $2 = session id
  local root="$1" sid="$2" f n=0
  for f in "$root"/leases/*/meta.json; do
    [ -e "$f" ] || continue
    if [ "$(jq -r '.session // empty' "$f" 2>/dev/null)" = "$sid" ]; then
      rm -rf "$(dirname "$f")"; n=$((n+1))
    fi
  done
  printf '%s' "$n"
}

# --- subcommands ------------------------------------------------------------

cmd_session_start() {
  local root sid wt branch f others msg ctx dirty
  root="$(lock_root)" || allow
  mkdir -p "$root/sessions" "$root/leases" 2>/dev/null
  sid="$(read_field '.session_id')"; [ -n "$sid" ] || sid="unknown-$$"
  wt="$(repo_root)" || allow
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

  prune_stale "$root"

  # Self-heal the git hook path so a fresh clone or worktree is protected too.
  if [ "$(git config core.hooksPath)" != ".githooks" ] && [ -d "$wt/.githooks" ]; then
    git config core.hooksPath .githooks 2>/dev/null
  fi

  jq -nc --arg s "$sid" --arg w "$wt" --arg b "$branch" --argjson t "$(now)" \
    '{session:$s, worktree:$w, branch:$b, started:$t, last_seen:$t}' \
    > "$(session_file "$root" "$sid")" 2>/dev/null

  others=""
  for f in "$root"/sessions/*.json; do
    [ -e "$f" ] || continue
    [ "$(jq -r '.session' "$f" 2>/dev/null)" = "$sid" ] && continue
    others="$others$(jq -r '"  - \(.session[0:8]) on \(.branch) in \(.worktree)"' "$f" 2>/dev/null)"$'\n'
  done

  dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  msg="agent-guard: $branch"
  [ "$dirty" != "0" ] && msg="$msg · $dirty uncommitted"
  ctx="Trunk-based repo. Trunk is '$TRUNK'; no PRs, no long-lived branches — commit small and push often."
  if [ -n "$others" ]; then
    msg="$msg · $(printf '%s' "$others" | grep -c .) other agent session(s) active"
    ctx="$ctx"$'\n''Other active agent sessions in this repo:'$'\n'"$others"'Files they are editing are leased; your Write/Edit will be blocked on a conflict.'
  fi
  note "$msg" "$ctx"
}

cmd_session_end() {
  local root sid
  root="$(lock_root)" || allow
  sid="$(read_field '.session_id')"; [ -n "$sid" ] || allow
  release_leases "$root" "$sid" >/dev/null
  rm -f "$(session_file "$root" "$sid")"
  allow
}

cmd_stop() {
  local root sid dirty ahead msg
  root="$(lock_root)" || allow
  sid="$(read_field '.session_id')"; [ -n "$sid" ] || sid="unknown-$$"
  release_leases "$root" "$sid" >/dev/null
  [ -f "$(session_file "$root" "$sid")" ] && \
    jq -c --argjson t "$(now)" '.last_seen=$t' "$(session_file "$root" "$sid")" \
      > "$(session_file "$root" "$sid").tmp" 2>/dev/null && \
    mv "$(session_file "$root" "$sid").tmp" "$(session_file "$root" "$sid")" 2>/dev/null

  dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  ahead="$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)"
  msg=""
  [ "$dirty" != "0" ] && msg="$dirty uncommitted file(s)"
  if [ "${ahead:-0}" != "0" ]; then
    [ -n "$msg" ] && msg="$msg, "
    msg="${msg}${ahead} unpushed commit(s)"
  fi
  [ -z "$msg" ] && allow
  jq -nc --arg m "agent-guard: $msg — trunk-based means integrate now, not later." '{systemMessage:$m}'
  exit 0
}

# Classify the `rm` invocations inside a compound command. Splits on command
# separators first, so a slash or path elsewhere in the script is not mistaken
# for an rm target. Prints a reason and returns 0 when one is dangerous.
rm_danger_reason() { # $1 = full command
  local seg root
  root="$(repo_root)"
  while IFS= read -r seg; do
    seg="${seg#"${seg%%[![:space:]]*}"}"                 # ltrim
    printf '%s' "$seg" | grep -Eq '^rm[[:space:]]+-[a-zA-Z]*[rf]' || continue
    if printf '%s' "$seg" | grep -Eq '(^|[[:space:]]|/)\.git/?([[:space:]]|$)'; then
      printf 'Deleting .git destroys the repository, every worktree attached to it, and all local history.'
      return 0
    fi
    if printf '%s' "$seg" | grep -Eq '[[:space:]](/|~|~/|\$HOME|\$HOME/|\*)([[:space:]]|$)'; then
      printf 'That targets the filesystem root, the home directory, or an unbounded glob.'
      return 0
    fi
    if [ -n "$root" ]; then
      case " $seg " in
        *" $root "*|*" $root/ "*)
          printf 'That would delete the repository working tree itself, along with every uncommitted change in it and any worktree nested under it.'
          return 0 ;;
      esac
    fi
  done < <(printf '%s\n' "$1" | tr ';&|' '\n\n\n')
  return 1
}

cmd_guard_bash() {
  local c reason
  c="$(read_field '.tool_input.command')"
  [ -n "$c" ] || allow

  # Documented escape hatch, so the guard is a speed bump and not a wall.
  case "$c" in *AGENT_GUARD_OVERRIDE=1*) allow ;; esac

  reason=""
  # Discards uncommitted work — possibly another agent's, in a shared tree.
  if printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?reset\s+(--hard|--merge|--keep)'; then
    reason="\`git reset --hard\` discards every uncommitted change in this working tree, including work another agent has in flight. Commit or stash first, or use \`git reset --soft\` / \`git revert\`."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?clean\s+-[a-zA-Z]*f'; then
    reason="\`git clean -f\` permanently deletes untracked files, including files another agent has not committed yet. Run \`git clean -n\` first and delete specific paths."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?(checkout|restore)\s+(--\s+)?(\.|\*)(\s|$)'; then
    reason="Restoring the whole tree throws away every uncommitted edit in it. Name the specific files you mean to revert."
  # Rewrites shared history on the trunk everyone is pushing to.
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?push\s+.*(--force([^-]|$)|--force-with-lease|(\s|:)\+)'; then
    reason="Force-pushing rewrites history other agents and worktrees have already pulled. In trunk-based development this is the one operation that loses committed work. Rebase and push normally instead."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?branch\s+(-D|--delete\s+--force|-d\s+--force)'; then
    reason="\`git branch -D\` force-deletes a branch whose commits may not be merged to $TRUNK yet. Use \`git branch -d\` so git can refuse when work would be lost."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?worktree\s+remove\s+.*--force'; then
    reason="\`git worktree remove --force\` deletes a worktree that still has uncommitted changes — likely another agent's. Commit there first, or remove it without --force."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?stash\s+(drop|clear)'; then
    reason="Dropping stashes destroys work you cannot recover. Inspect with \`git stash list\` and \`git stash show -p\` first."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?(filter-branch|filter-repo)'; then
    reason="History rewriting invalidates every other worktree and clone of this repo."
  elif printf '%s' "$c" | grep -Eq '(^|[;&|]|\s)git\s+([^;&|]*\s)?reflog\s+expire.*--expire[= ](now|all)'; then
    reason="Expiring the reflog removes the last safety net for recovering clobbered commits."
  fi

  if [ -z "$reason" ]; then
    reason="$(rm_danger_reason "$c")" || reason=""
  fi

  [ -z "$reason" ] && allow
  deny "$reason"$'\n\n'"If this is genuinely what you want, re-run it prefixed with AGENT_GUARD_OVERRIDE=1 and say why."
}

cmd_lease_acquire() {
  local root sid fp rel key dir meta owner owner_wt wt age
  root="$(lock_root)" || allow
  sid="$(read_field '.session_id')"; [ -n "$sid" ] || allow
  fp="$(read_field '.tool_input.file_path')"; [ -n "$fp" ] || allow
  rel="$(rel_path "$fp")" || allow      # outside the repo: not our business
  wt="$(repo_root)"

  mkdir -p "$root/leases" 2>/dev/null
  prune_stale "$root"

  key="$(key_for "$rel")"
  dir="$root/leases/$key"
  meta="$dir/meta.json"

  if mkdir "$dir" 2>/dev/null; then
    jq -nc --arg s "$sid" --arg p "$rel" --arg w "$wt" --argjson t "$(now)" \
      '{session:$s, path:$p, worktree:$w, acquired:$t, refreshed:$t}' > "$meta" 2>/dev/null
    allow
  fi

  # Directory exists: someone holds it, or a previous run died mid-write.
  [ -f "$meta" ] || { rm -rf "$dir"; allow; }
  owner="$(jq -r '.session // empty' "$meta" 2>/dev/null)"
  owner_wt="$(jq -r '.worktree // empty' "$meta" 2>/dev/null)"
  [ -z "$owner" ] || [ "$owner" = "$sid" ] && allow

  age=$(( $(now) - $(jq -r '.refreshed // 0' "$meta" 2>/dev/null) ))

  if [ "$owner_wt" = "$wt" ]; then
    deny "\`$rel\` is being edited right now by another agent session (${owner:0:8}) in this same working tree — writing would clobber its changes. Its lease was refreshed ${age}s ago and expires after ${LEASE_TTL}s. Work on a different file, or ask that session to finish."
  fi
  # A different worktree is a legitimate parallel edit; warn, don't block.
  jq -nc --arg m "agent-guard: session ${owner:0:8} is also editing $rel in $owner_wt — expect a merge conflict on $TRUNK." '
    {systemMessage:$m, hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:"allow", permissionDecisionReason:"Parallel edit in another worktree"}}'
  exit 0
}

cmd_lease_refresh() {
  local root sid fp rel key meta
  root="$(lock_root)" || allow
  sid="$(read_field '.session_id')"; [ -n "$sid" ] || allow
  fp="$(read_field '.tool_input.file_path')"; [ -n "$fp" ] || allow
  rel="$(rel_path "$fp")" || allow
  key="$(key_for "$rel")"
  meta="$root/leases/$key/meta.json"
  [ -f "$meta" ] || allow
  [ "$(jq -r '.session // empty' "$meta" 2>/dev/null)" = "$sid" ] || allow
  jq -c --argjson t "$(now)" '.refreshed=$t' "$meta" > "$meta.tmp" 2>/dev/null && mv "$meta.tmp" "$meta"
  allow
}

# --- entry point ------------------------------------------------------------

command -v jq >/dev/null 2>&1 || { echo '{"suppressOutput":true}'; exit 0; }
PAYLOAD="$(cat)"
git rev-parse --git-dir >/dev/null 2>&1 || allow

case "${1:-}" in
  session-start)  HOOK_EVENT=SessionStart cmd_session_start ;;
  session-end)    cmd_session_end ;;
  stop)           cmd_stop ;;
  guard-bash)     cmd_guard_bash ;;
  lease-acquire)  cmd_lease_acquire ;;
  lease-refresh)  cmd_lease_refresh ;;
  *)              allow ;;
esac
