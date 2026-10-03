# Adding a value to an enum, and writing it too early

Tickets are `open` or `closed`, and the database says so with a `CHECK`.
The product wants a third state, `archived`. Widening the `CHECK` is
instantaneous and safe: no row changes. The code change is small too. The new
release knows the third value.

The migration that matters is neither of those. It is the first time
something **writes** `'archived'`. Every release still running at that moment
has to be able to read it, and the old one maps the column onto a two-value
enum in code: an unknown value is a deserialisation error, on every read of
that row.

## The model

The SQL is [`01-before.sql`](01-before.sql) and
[`02-add-value.sql`](02-add-value.sql). `writ sql` reads a `CHECK … IN` as an
enumerated type, so the two steps differ in the type's members:

```
(type tickets-status (open closed))            ; 01-before.sql
(type tickets-status (open closed archived))   ; 02-add-value.sql
```

[`change-an-enum.writ`](change-an-enum.writ) carries the `CHECK` as one fact
(`allows-archived`), one ticket `t1`, and the fleet as two slots `old` and
`new` over releases `r1` (does not know `archived`) and `r2` (does). The moves
are `add-value`, `deploy-r2`, `settle`, and `archive-t1`: the first write.

Two rules:

- `check-allows`: no row holds a value the `CHECK` does not list. The loud
  one: break it and the `UPDATE` fails at once;
- `readable`: no row holds a value a running release cannot read. The quiet
  one: the `UPDATE` succeeds, and the failure is the next read by an old
  instance.

The safe plan switches the archive feature on once the fleet has **settled**
on r2. [`change-an-enum-shortcut.writ`](change-an-enum-shortcut.writ) switches
it on with the deploy.

## What writ answers

Both plans are asked the questions in
[`change-an-enum.claims`](change-an-enum.claims). The safe plan exits 0. The
shortcut, exit 1:

```
equation readable
  can be broken by: deploy-r2, settle, archive-t1   (acknowledge in claims)
  violated in 1 reachable situations   witness: 1. add-value 2. deploy-r2 3. archive-t1 → #6
```

Widen the `CHECK`, start the deploy, archive a ticket. r1 is still serving,
and every read of `t1` on an r1 instance fails until the rollout completes.
`check-allows` is satisfied throughout: the database allowed the value. Only
the rule it cannot check breaks.

## What to take away

For an enum, the schema change is not the migration: the first write of the
new value is. Gate that write, usually a feature flag, on the rollout having
finished, not on the code having shipped.

## Run it

```sh
writ check change-an-enum.writ --claims change-an-enum.claims           # exit 0
writ check change-an-enum-shortcut.writ --claims change-an-enum.claims  # exit 1
```

Siblings: [`../split-a-table/`](../split-a-table/),
[`../add-a-foreign-key/`](../add-a-foreign-key/), and the first three.
