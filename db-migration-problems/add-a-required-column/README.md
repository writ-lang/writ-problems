# Making a column required, before the code can keep the promise

You do not need to know anything about `pol` to read this page.

---

## The problem

You want every user to have a country. Today the column does not exist, so the
job is: add it, fill it in, and make it mandatory.

You cannot do that in one step. `ALTER TABLE users ADD COLUMN country text NOT
NULL` is rejected on a table that already has rows, because none of those rows
has a value for a column that did not exist a moment ago.

So the column arrives nullable, gets filled in, and only then becomes required.
Three database steps and one deploy.

## What a NOT NULL constraint actually is

This is the part worth being precise about, because it is where the mistake
comes from.

`NOT NULL` is not a statement about the data you have. It is a **promise the
database makes on behalf of your code**: from this moment on, every insert will
supply a country.

That promise has two halves, and only one of them is about existing rows.

- **The rows that are already there** must have a value. The database checks
  this itself. If any row holds a NULL, the `ALTER` is rejected immediately and
  loudly, and you go and run the backfill.
- **The rows that are about to be written** must have a value too. The database
  cannot check this, because those rows do not exist yet. It depends entirely
  on whether the code currently running supplies one.

Backfilling handles the first half. It does nothing at all about the second,
and nothing warns you about that.

## The mistake

You add the column. You backfill it. You add the constraint, and the `ALTER`
succeeds — the database is satisfied, because every row it can see has a value.

But the release running in production has never heard of this column. Its
inserts do not mention it. The next time a user signs up, the insert supplies
no country, the constraint rejects it, and sign-up starts failing.

Nothing you did was flagged. The backfill worked. The `ALTER` worked. The
failure is in the code you have not deployed yet.

---

## The SQL

| file | what it is |
| --- | --- |
| `01-before.sql` | the table today, with no country at all |
| `02-add-nullable.sql` | the column added, nullable, holding NULL for the existing row |
| `03-required.sql` | the column as `NOT NULL` |

Each carries one representative row, so each can be checked on its own:

```console
$ pol sql 02-add-nullable.sql --with-data > step2.pol
$ pol check step2.pol
states: 1   edges: 0
```

All three files are valid schemas. `03-required.sql` is only *correct at the
right moment*, and nothing in the file says when that moment is. That is the
whole reason the rest of this directory exists.

---

## The plan

```console
$ pol check add-a-required-column.pol --claims add-a-required-column.claims
states: 8   edges: 9
holds  completes
  witness:  1. add-column
            2. deploy-r2
            3. settle
            4. backfill
            5. require
holds  no-dead-ends
```

Exit code 0. Five steps:

| # | step | what happens |
| --- | --- | --- |
| 1 | `add-column` | the column arrives, nullable |
| 2 | `deploy-r2` | the release that writes a country starts rolling out |
| 3 | `settle` | the rollout finishes; nothing running now omits the column |
| 4 | `backfill` | the rows that predate the column get a value |
| 5 | `require` | the constraint goes on |

The deploy comes **before** the backfill, not after. That ordering is the
answer to the whole problem: once the writing release is everywhere, no new row
can arrive without a country, so the backfill is the last gap and closing it
finishes the job.

### The three rules

| rule | what it forbids | who checks it in real life |
| --- | --- | --- |
| `write-of-existing` | writing a column that is not there | your database, loudly |
| `required-needs-data` | requiring a column some row leaves empty | your database, loudly |
| `required-needs-every-writer` | requiring a column some live release does not write | **nobody** |

The third row is the point. Two of these three mistakes announce themselves the
moment you make them. The third one is silent until a user tries to sign up.

---

## The shortcut

`add-a-required-column-shortcut.pol` is the same file with one condition
removed from the last step. The constraint no longer waits for the code:

```lisp
(when (and (is country-col.state present)
           (is country-col.filled yes)
           (is country-col.required no)))     ; every-live-writes, gone
```

What is left is the condition the database checks for you. That is exactly why
the mistake is easy: the step still looks guarded, and the guard that remains
is the one you were reminded about.

```console
$ pol check add-a-required-column-shortcut.pol --claims add-a-required-column.claims
states: 10   edges: 13
equation required-needs-every-writer
  violated in 2 reachable situations   witness: 1. add-column 2. backfill 3. require
holds  completes
  witness:  1. add-column
            2. backfill
            3. require
holds  no-dead-ends
```

Exit code 1.

**Three moves**: add the column, backfill it, require it. No deploy at all. It
is the shortest sensible-looking route through the job, and it is wrong.

Look at the two witness lists. They are the same three steps. The route to the
finished state and the route to the fault are *the same route* — because the
plan reaches its goal by going through a broken state and out the other side.
`completes` still holds. `no-dead-ends` still holds. Only the rule catches it.

And once again the unsafe version is shorter: three steps against five.

---

## The files

| file | what it is |
| --- | --- |
| `01-before.sql`, `02-add-nullable.sql`, `03-required.sql` | the three schemas, each with one row |
| `add-a-required-column.pol` | the safe plan |
| `add-a-required-column-shortcut.pol` | the same, one condition lighter |
| `add-a-required-column.claims` | the questions, put to both |
| `add-a-required-column.lib.pol` | definitions shared by model and questions |
| `add-a-required-column.rules` | the same questions answered a second way, as a cross-check |

---

## What this one teaches

That **the checks a database performs for you are the ones you will remember,
and the ones it cannot perform are the ones that hurt.**

Both halves of a `NOT NULL` promise matter equally. One of them is enforced at
the moment you make the change, so it trains you to expect a complaint when
something is wrong. The other is about code you have not shipped yet, so there
is no complaint to expect, and silence reads as approval.

Writing the plan down is what lets a tool check the half nothing else does.

The sibling problems: [`../drop-a-column/`](../drop-a-column/) for a mistake
that is purely about timing, and [`../rename-a-column/`](../rename-a-column/)
for one where two releases disagree mid-rollout.
