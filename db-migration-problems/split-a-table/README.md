# Splitting a table: switching reads before the copy finishes

A user's address moves out of `users` into a table of its own, so a user can
have several. The safe order is well known: create the new table; deploy code
that writes both places (the **dual write**); copy the rows that existed
before it (the **backfill**); switch reads to the new table; drop the old
column.

The switch must wait for the backfill to *finish*. Nothing in any SQL file
says when that is. Until then the new table holds some addresses and not
others, and a read from it returns nothing for every user the backfill has
not reached yet. No error is raised: those users simply have no address.

## The model

The SQL is [`01-before.sql`](01-before.sql),
[`02-create-addresses.sql`](02-create-addresses.sql) and
[`03-drop-column.sql`](03-drop-column.sql). `writ sql` reads the new table's
`user_id uuid NOT NULL REFERENCES users (id)` as an arrow from an address to a
user: `(fk user-id users)`.

How far the backfill has got is not in any file, so
[`split-a-table.writ`](split-a-table.writ) carries it as a cell: `filled` is
`no`, `partial` or `yes`. Not a row count. The rules only ever ask which of
those three it is. Three releases, each described by what its code reads and
writes: `r1` (old column only), `r2` (writes both, reads the old one), `r3`
(the new table only).

Three rules:

- `read-of-existing`: nobody reads a column that is gone;
- `no-lost-writes`: once the backfill has started, every running release
  writes the new table too, or its writes land after the copy and are never
  moved;
- `complete-before-read`: nobody reads the new table before it holds every
  address.

The safe plan deploys r3 once r2 has settled **and** `filled` is `yes`.
[`split-a-table-shortcut.writ`](split-a-table-shortcut.writ) deploys it once
the backfill has started.

## What writ answers

The safe plan exits 0. The shortcut, exit 1:

```
equation complete-before-read
  …
  violated in 3 reachable situations   witness: 1. create-table 2. deploy-r2 3. settle 4. backfill-start 5. deploy-r3 → #6
```

Five steps, the longest route to a fault in this collection, and every one is
in the runbook's order. The mistake is the word "started" where the runbook
meant "finished". The backfill in a real system takes hours, so that word
covers most of the migration's wall-clock time.

## What to take away

The migration's real state includes the progress of a job, and a job's
progress is exactly what no schema file records. Make it a fact the deploy
can check: a completion row the backfill writes last, for instance. Then gate
the switch on that row rather than on the job having been launched.

## Run it

```sh
writ check split-a-table.writ --claims split-a-table.claims           # exit 0
writ check split-a-table-shortcut.writ --claims split-a-table.claims  # exit 1
```

Siblings: [`../change-an-enum/`](../change-an-enum/),
[`../add-a-foreign-key/`](../add-a-foreign-key/), and the first three.
