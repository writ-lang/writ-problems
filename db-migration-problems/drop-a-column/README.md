# Dropping a column that is still being read

`users.legacy_flag` is no longer needed. The plan: deploy a release that stops
using it, then drop it. That is correct, provided "then" means after the
rollout has *finished*. During a rolling deploy the old and new releases serve
traffic side by side, and the old one still reads and writes the column. Drop
it too early and requests that land on an old instance fail until the rollout
completes, after which the evidence is gone.

## The model

The SQL is two files, [`01-before.sql`](01-before.sql) and
[`02-after.sql`](02-after.sql). Both are valid schemas; the mistake is in when
the second one runs, which no `.sql` file records. So
[`drop-a-column.writ`](drop-a-column.writ) models the plan instead: the column
(present or absent), the fleet as two slots `old` and `new` (equal means
settled, different means mid-rollout), and what each release reads and writes
as small `(reads …)`/`(writes …)` records. The moves are `deploy-r2`, `settle`
and `drop-column`. Two equations, kept separate from the moves so writ can
report a step the plan allows but a rule forbids:

- `read-of-existing` — no running release reads a column that is not there;
- `write-of-existing` — likewise for writes.

The whole safety of the plan is one word in the drop's guard:

```lisp
(transition drop-column
  (when (and settled (is prod.new r2) (is flag-col.state present)))
  (do (set flag-col.state absent)))
```

[`drop-a-column-shortcut.writ`](drop-a-column-shortcut.writ) is the same file
with `settled` deleted. Read as English, the two guards say the same thing.

## What writ answers

Both plans are asked the same questions from
[`drop-a-column.claims`](drop-a-column.claims). The safe plan, exit 0:

```
states: 4   edges: 3
…
equation read-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
equation write-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
holds  completes
  "the column can be dropped, with the fleet settled on the release that does not use it"
  witness:  1. deploy-r2     → #1   prod.new: r1 → r2
            2. settle        → #2   prod.old: r1 → r2
            3. drop-column   → #3   flag-col.state: present → absent
holds  no-dead-ends
  "from every situation reachable, the drop can still be completed"
```

`can be broken by` lists the steps that touch what the rule depends on; the
claims file acknowledges each one. Neither rule is violated, and the witness
for `completes` is the runbook.

The shortcut, exit 1:

```
states: 5   edges: 5
…
equation read-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
  violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column → #3
equation write-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
  violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column → #3
holds  completes
…
holds  no-dead-ends
```

Deleting `settled` admits one extra situation, and that situation is the
outage: start the deploy, drop the column, two moves. Both rules break, because
the old release both reads and writes the column. The shortcut still completes
and never gets stuck, so only the safety question catches it.

`writ compare drop-a-column.writ drop-a-column-shortcut.writ` agrees. The
shortcut still declares both rules, but it breaks them, so both are `LOST`
with the same two moves:

```
equations:   read-of-existing   LOST      witness: 1. deploy-r2 2. drop-column
             write-of-existing  LOST      witness: 1. deploy-r2 2. drop-column
```

## What to take away

A migration can be wrong in time rather than in content. Both schemas, both
releases and the order of the steps are correct; the defect is a step allowed
to start before another has finished. Checking artifacts (DDL, diffs, code)
cannot see it. Checking the sequence can, once it is written down.

To adapt it, list each release's reads and writes from the code, including the
background job or admin screen everyone forgets. The rules carry over unchanged.

## Run it

```sh
writ check drop-a-column.writ --claims drop-a-column.claims           # exit 0
writ check drop-a-column-shortcut.writ --claims drop-a-column.claims  # exit 1
```

[`drop-a-column.rules`](drop-a-column.rules) encodes the same two properties
for `writ derive`; `../../modality-cross-check.sh` checks the two answers agree.
Shared definitions live in [`drop-a-column.lib.writ`](drop-a-column.lib.writ).
Siblings: [`../add-a-required-column/`](../add-a-required-column/),
[`../rename-a-column/`](../rename-a-column/).
