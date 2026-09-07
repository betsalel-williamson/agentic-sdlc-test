# OpenSpec Workflow Instructions

This project uses [OpenSpec](https://github.com/Fission-AI/OpenSpec) for
spec-driven development. Specs are the source of truth; code follows them.

Read `openspec/project.md` for project context before proposing or implementing
anything.

## Directory Layout

```
openspec/
├── specs/            # Source of truth — current, merged capability specs
│   └── <capability-path>/spec.md
├── changes/          # Active proposed changes (one directory each)
│   ├── <change-name>/
│   │   ├── proposal.md   # What & why
│   │   ├── design.md     # How
│   │   ├── specs/<capability-path>/spec.md   # Delta, not the full spec
│   │   └── tasks.md      # Implementation steps
│   └── archive/      # Completed changes, moved here after archiving
├── config.yaml       # Schema selection, shared context, per-artifact rules
├── project.md        # Project context (this repo's stack, conventions, domain)
└── AGENTS.md         # This file
```

Note: the archive lives at `openspec/changes/archive/`, not at the top level —
that is where the `openspec` CLI reads and writes it.

`<capability-path>` is a spec directory relative to `specs/` (e.g. `user-auth`
or `identity/user-auth`). Preserve an existing capability's full path; follow the
established organization when adding a new one.

## The Loop

| Stage       | Slash command      | What happens                                                     |
| ----------- | ------------------ | ---------------------------------------------------------------- |
| Explore     | `/opsx:explore`    | Think through the problem before committing to a change. No files written. |
| Propose     | `/opsx:propose`    | Create `changes/<name>/` with proposal, delta specs, design, tasks. |
| Update      | `/opsx:update`     | Revise an existing change's artifacts and keep them coherent.      |
| Apply       | `/opsx:apply`      | Implement the tasks. This is the only stage that edits project code. |
| Sync        | `/opsx:sync`       | Fold delta specs into `specs/` without archiving.                 |
| Archive     | `/opsx:archive`    | Merge deltas into `specs/` and move the change to `changes/archive/`. |

## Rules

1. **Planning does not write code.** `propose`, `update`, and `explore` produce
   planning artifacts only — even when the request is phrased as "build X" or
   "fix Y". Stop after the artifacts are ready and wait for an explicit request
   to apply.

2. **Implementation does not rewrite the plan.** During `apply`, follow
   `tasks.md`. If the plan turns out to be wrong, stop and revise it via
   `update` rather than silently diverging.

3. **Change specs are deltas.** A file under `changes/<name>/specs/` describes
   what this change adds, removes, or modifies — not a full copy of the current
   spec. Only `archive` (or `sync`) merges a delta into `specs/`.

4. **`specs/` is the source of truth.** It reflects what the system does today,
   not what someone intends it to do. Never hand-edit it to describe unbuilt
   behavior; route that through a change.

5. **Clarify what materially matters.** Ask the user when ambiguity would change
   scope, externally observable behavior, compatibility, or acceptance criteria.
   For minor details, assume something reasonable and record the assumption in
   the artifacts.

6. **One change, one concern.** Split unrelated work into separate changes so
   each can be reviewed, applied, and archived on its own.

7. **Name changes in kebab-case**, verb-first: `add-user-auth`,
   `migrate-session-store`, `fix-token-refresh`.

## Useful Commands

```bash
openspec list                       # Active changes
openspec status --change <name>     # Where a change stands
openspec show <name>                # Read a change's artifacts
openspec validate                   # Check artifacts against the schema
openspec view                       # Browse specs and changes
openspec doctor                     # Diagnose a broken setup
```

Add `--json` to any of these for machine-readable output.

## Configuration

`openspec/config.yaml` sets the workflow schema (currently `spec-driven`) and can
carry shared `context:`, per-artifact `rules:`, and per-operation `operations:`
guidance. Project context that agents should always see belongs there or in
`project.md`; rules that constrain a specific artifact belong in `config.yaml`.
