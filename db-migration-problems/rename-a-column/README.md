# Renaming a column without breaking production

Renaming `users.name` to `full_name` in a running service can't be one step:
the database and the code change at different moments, and during a rolling
deploy two releases serve traffic at once. The standard answer is
expand/contract: add `full_name` beside `name`, deploy a release that writes
both, backfill, deploy one that reads the new column, deploy one that stops
writing the old, drop `name`. The pattern names the steps. It does not tell you
whether your version has them in a safe order.

## The SQL catches one mistake

[`01-before.sql`](01-before.sql), [`02-expand.sql`](02-expand.sql) and
[`03-contract.sql`](03-contract.sql) are the three schemas, each with one
representative row. `writ sql` turns DDL into a model; the expand step comes
out as:

```lisp
(type users
    (text name)
    (text? full-name)
    (text email))
```

[`02-expand-wrong.sql`](02-expand-wrong.sql) adds the new column `NOT NULL`,
the most common way to get this step wrong. The `?` disappears, and the row
that predates the column makes the schema impossible:

```console
$ writ sql 02-expand-wrong.sql --with-data > wrong.writ
$ writ check wrong.writ
writ: wrong.writ: value out of domain for cell users.full-name for u1
```

Refused with exit 2, naming the row, from one file and no hand-written model.
The DDL cannot say in what order to run the steps relative to deploys, or what
each release reads and writes. The remaining mistakes are there.

## The model

[`rename-a-column.writ`](rename-a-column.writ) models the sequence: each column
as exists / every row filled, the fleet as two slots `old`/`new` (mid-rollout
when they differ), and what releases r1–r4 read and write as `(reads …)` /
`(writes …)` records. The moves are `add-column`, `deploy-r2`…`deploy-r4`,
`settle`, `backfill` and `drop-column`. Four equations, kept separate from the
moves so writ can report a step the plan allows but a rule forbids:

- `read-of-existing`, `write-of-existing` — no live release touches a column
  that is not there;
- `read-of-filled` — no live release reads a column before the backfill;
- `read-implies-every-writer` — a column any live release reads is written by
  every live release. This is why the pattern ships a release that writes the
  new column before any release reads it.

The reader's deploy waits for the backfill:

```lisp
(transition deploy-r3
  (when (and settled (is prod.new r2) (is full-col.filled yes)))
  (do (set prod.new r3)))
```

[`rename-a-column-shortcut.writ`](rename-a-column-shortcut.writ) drops
`(is full-col.filled yes)`. At that moment the column exists, every live release
writes it, and every row in staging has a value, so the backfill looks like a
tidy-up for later.

## What writ answers

Both plans are asked the same questions from
[`rename-a-column.claims`](rename-a-column.claims). The safe plan, exit 0:

```
states: 10   edges: 9
…
equation read-of-filled
  can be broken by: backfill, deploy-r2, deploy-r3, deploy-r4, settle   (acknowledge in claims)
equation read-implies-every-writer
  can be broken by: deploy-r2, deploy-r3, deploy-r4, settle   (acknowledge in claims)
holds  completes
  "the rename can be finished: old column gone, fleet settled on the release that neither reads nor writes it"
  witness:  1. add-column    → #1   full-col.state: absent → present
            2. deploy-r2     → #2   prod.new: r1 → r2
            3. settle        → #3   prod.old: r1 → r2
            4. backfill      → #4   full-col.filled: no → yes
            5. deploy-r3     → #5   prod.new: r2 → r3
            6. settle        → #6   prod.old: r2 → r3
            7. deploy-r4     → #7   prod.new: r3 → r4
            8. settle        → #8   prod.old: r3 → r4
            9. drop-column   → #9   name-col.state: present → absent
holds  no-dead-ends
  "from every reachable situation the rename can still be finished — no step strands production half-migrated"
```

Nobody wrote that nine-step witness; writ found it, and it is the runbook. The
backfill sits after the writer is everywhere (else old code keeps creating
empty rows behind it) and before the reader goes out. Every deploy settles
before the next begins.

The shortcut, exit 1:

```
states: 15   edges: 17
…
equation read-of-filled
  can be broken by: backfill, deploy-r2, deploy-r3, deploy-r4, settle   (acknowledge in claims)
  violated in 5 reachable situations   witness: 1. add-column 2. deploy-r2 3. settle 4. deploy-r3 → #5
…
holds  completes
…
holds  no-dead-ends
…
```

Removing one condition admits five more situations, all bad. Four ordinary
moves reach one, and the last of them, `deploy-r3`, is the step at fault. The
shortcut still completes, never gets stuck, and its route is eight steps
instead of nine.

`writ compare` does not catch it, because the shortcut gives up none of the
guarantees it declares:

```console
$ writ compare rename-a-column.writ rename-a-column-shortcut.writ
equations:   read-of-existing           preserved
             write-of-existing          preserved
             read-of-filled             preserved
             read-implies-every-writer  preserved
properties:  completes                  preserved
             no-dead-ends               preserved
```

`compare` asks which guarantees a version dropped; `check` asks whether it
keeps the ones it declares. Gate CI on `check`.

## What to take away

The dangerous plan is the one that looks fine: quicker, complete, never stuck,
and correct in staging, where every row was written after the column existed.
The SQL catches a mistake inside one file. The ordering mistakes need the
sequence written down, and then writ checks every interleaving of deploy,
backfill and schema change, including mid-rollout.

To adapt it, take each release's reads and writes from the code rather than the
plan, and give each step the precondition you claim to check. The four rules
are about columns and releases in general and carry over unchanged.

## Run it

```sh
writ sql 02-expand-wrong.sql --with-data > wrong.writ && writ check wrong.writ   # exit 2
writ check rename-a-column.writ --claims rename-a-column.claims                  # exit 0
writ check rename-a-column-shortcut.writ --claims rename-a-column.claims         # exit 1
```

[`rename-a-column.rules`](rename-a-column.rules) encodes the same properties for
`writ derive`; `../../modality-cross-check.sh` checks the two answers agree.
Shared definitions live in [`rename-a-column.lib.writ`](rename-a-column.lib.writ).
Siblings: [`../drop-a-column/`](../drop-a-column/),
[`../add-a-required-column/`](../add-a-required-column/).
