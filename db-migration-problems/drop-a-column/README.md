# Dropping a column that is still being read

This is the smallest problem in this folder, and the one with the shortest path
to an outage: **two moves.**

You do not need to know anything about `pol` to read this page.

---

## The problem

You have a column nobody needs any more — say `users.legacy_flag`. Removing it
looks like a three-step job:

1. Change the code so it no longer reads or writes the column.
2. Deploy that.
3. Drop the column.

That is the right sequence. The trap is entirely in the word *then*, between
steps 2 and 3.

**A deploy is not instant.** Most deployments are rolling: the new version
replaces the old one machine by machine, over seconds or minutes. For that
whole window **both versions are live and both are serving real traffic**. The
old one still reads `legacy_flag`.

If you drop the column during that window, the old version is now asking for a
column that no longer exists. Every request it handles that touches the column
fails, until the rollout finishes and the last old instance goes away.

Then the errors stop by themselves, which is its own problem: by the time
anyone looks, the cause has cleaned itself up.

### Why this is easy to get wrong

There is nothing on screen to warn you. The pull request that removes the last
use of the column has been merged, reviewed and deployed. Dropping the column
is plainly the next thing to do, and running one `ALTER TABLE` takes a second.

The only thing you had to know was whether the deploy had *finished* rather
than *started*, and nothing you were looking at told you.

---

## The SQL

Two files, because a drop really is one statement:

| file | what it is |
| --- | --- |
| `01-before.sql` | the table with `legacy_flag` |
| `02-after.sql` | the table without it |

Each also has one row in it, so each file can be checked on its own:

```console
$ pol sql 01-before.sql --with-data > before.pol
$ pol check before.pol
states: 1   edges: 0
```

Both files are perfectly good schemas. Neither is wrong. **That is the point of
this problem** — unlike the expand step in `rename-a-column/`, where the bad
version of the DDL can be caught by looking at the file, here there is nothing
wrong with either file. The mistake is in *when* you run the second one, and no
amount of staring at SQL will show you that.

---

## The plan

```console
$ pol check drop-a-column.pol --claims drop-a-column.claims
states: 4   edges: 3
dead ends: 1
  reached by: deploy-r2, settle, drop-column
holds  completes
  witness:  1. deploy-r2
            2. settle
            3. drop-column
holds  no-dead-ends
```

Exit code 0.

Four situations, three moves. The whole safe plan is:

| # | step | what happens |
| --- | --- | --- |
| 1 | `deploy-r2` | the rollout of the release that stops using the column begins |
| 2 | `settle` | the rollout **finishes**; the old release is gone |
| 3 | `drop-column` | the column is removed |

`holds completes` means the drop can be finished, and the three steps printed
underneath are the route. `holds no-dead-ends` means that from every situation
you can reach, you can still finish — there is no way to get stuck.

The safety is one word in one condition. The `drop-column` step is allowed
`when settled`, and `settled` means the fleet is running one release rather
than two.

---

## The shortcut

`drop-a-column-shortcut.pol` is the same file with that word deleted. The drop
is allowed as soon as the new release has *started* going out:

```lisp
(when (and (is prod.new r2) (is flag-col.state present)))   ; `settled`, gone
```

Read as prose, both versions say "drop the column once the new release is out".
Only one of them means it.

```console
$ pol check drop-a-column-shortcut.pol --claims drop-a-column.claims
states: 5   edges: 5
equation read-of-existing
  violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column
equation write-of-existing
  violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column
holds  completes
holds  no-dead-ends
```

Exit code 1.

**Two moves.** Start the deploy, drop the column. That is the entire route to
the fault — no unusual ordering, no bad luck, nothing concurrent. It is the
obvious thing to do and it is wrong.

Both rules break, because the old release both reads and writes the column.

And notice, again, that `holds completes` and `holds no-dead-ends` are both
still true. The bad plan reaches the same end state and never gets stuck. Every
question except "is it safe on the way" says it is fine.

---

## The files

| file | what it is |
| --- | --- |
| `01-before.sql`, `02-after.sql` | the two schemas, each with one row |
| `drop-a-column.pol` | the safe plan |
| `drop-a-column-shortcut.pol` | the same, one word lighter |
| `drop-a-column.claims` | the questions, put to both |
| `drop-a-column.lib.pol` | definitions shared by model and questions |
| `drop-a-column.rules` | the same questions answered a second way, as a cross-check |

---

## What this one teaches

That a migration can be **wrong in time rather than wrong in content**.

Every file here is correct. Both schemas are fine, both releases are fine, and
the steps are in the right order. The only defect is that one step is permitted
to begin before another has finished, and that defect lives in a condition, not
in a statement.

If you only ever check artifacts — the DDL, the diff, the code — you cannot see
it. You have to check the *sequence*, and that means writing the sequence down
somewhere a tool can read it.

For a problem where the DDL alone does catch something, see
[`../rename-a-column/`](../rename-a-column/).
