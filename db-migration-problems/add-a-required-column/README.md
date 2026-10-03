# Making a column required before the code can keep the promise

Every user should have a `country`. The column can't arrive `NOT NULL` on a
table with rows, so it is added nullable, backfilled, then made required. But
`NOT NULL` promises two things: every existing row has a value, and every
future insert supplies one. The database checks the first loudly. It cannot
check the second, which depends on the release currently running. Backfill and
require while the old release is live, and the `ALTER` succeeds; the next
sign-up from old code inserts no country and fails.

## The model

The SQL is three valid files: [`01-before.sql`](01-before.sql),
[`02-add-nullable.sql`](02-add-nullable.sql) and
[`03-required.sql`](03-required.sql). The third is only correct after the
backfill and the deploy, and nothing in the file says so.
[`add-a-required-column.writ`](add-a-required-column.writ) models the plan: the
column as three facts (exists, every row filled, constraint on), the fleet as
two slots `old`/`new` (mid-rollout when they differ), and which releases write
the column as `(writes …)` records. The moves are `add-column`, `deploy-r2`,
`settle`, `backfill` and `require`. Three equations:

| rule | forbids | who catches it in real life |
| --- | --- | --- |
| `write-of-existing` | writing a column that is not there | the database |
| `required-needs-data` | requiring a column some row leaves empty | the database |
| `required-needs-every-writer` | requiring a column some running release does not write | nobody |

The last step guards both halves of the promise:

```lisp
(transition require
  (when (and (is country-col.state present)
             (is country-col.filled yes)
             (is country-col.required no)
             (every-live-writes W country-col)))
  (do (set country-col.required yes)))
```

[`add-a-required-column-shortcut.writ`](add-a-required-column-shortcut.writ)
deletes `every-live-writes`. What remains is the condition the database checks
for you, so the step still looks guarded.

## What writ answers

Both plans are asked the same questions from
[`add-a-required-column.claims`](add-a-required-column.claims). The safe plan,
exit 0:

```
states: 8   edges: 9
…
equation required-needs-every-writer
  can be broken by: deploy-r2, settle, require   (acknowledge in claims)
holds  completes
  "the column can end up existing, filled in, and required"
  witness:  1. add-column   → #1   country-col.state: absent → present
            2. deploy-r2    → #2   prod.new: r1 → r2
            3. settle       → #4   prod.old: r1 → r2
            4. backfill     → #6   country-col.filled: no → yes
            5. require      → #7   country-col.required: no → yes
holds  no-dead-ends
  "from every reachable situation, that end can still be reached"
```

The witness deploys before it backfills, the opposite of the natural "data
first, then code". Backfill first and the old release keeps inserting rows
without a country while you work; deploy first and nothing new can arrive
empty, so the backfill closes the last gap.

The shortcut, exit 1:

```
states: 10   edges: 13
…
equation required-needs-every-writer
  can be broken by: deploy-r2, settle, require   (acknowledge in claims)
  violated in 2 reachable situations   witness: 1. add-column 2. backfill 3. require → #6
holds  completes
  "the column can end up existing, filled in, and required"
  witness:  1. add-column   → #1   country-col.state: absent → present
            2. backfill     → #3   country-col.filled: no → yes
            3. require      → #6   country-col.required: no → yes
holds  no-dead-ends
…
```

Three moves, with no deploy among them. The route to the fault and the route to
`completes` are the same three steps: the plan reaches its goal by passing
through the broken situation. `required-needs-data`, the database's own check,
is untouched; only the unwatched rule breaks. The shortcut is also faster,
three steps against five, because it skips a deploy and a wait.

`writ compare` against the safe plan agrees: `required-needs-every-writer` is
`LOST`, with the same three moves. The other two rules are preserved.

## What to take away

The check a database performs for you is the one you remember, and it makes the
unchecked half feel checked. An unenforced rule is more dangerous next to an
enforced one than alone. Writing the plan down lets something check the half
nothing else does.

To adapt it, take each release's writes from the code: every insert path,
including imports and admin screens, is a place a row can arrive without a
value.

## Run it

```sh
writ check add-a-required-column.writ --claims add-a-required-column.claims           # exit 0
writ check add-a-required-column-shortcut.writ --claims add-a-required-column.claims  # exit 1
```

[`add-a-required-column.rules`](add-a-required-column.rules) encodes the same
properties for `writ derive`; `../../modality-cross-check.sh` checks the two
answers agree. Shared definitions live in
[`add-a-required-column.lib.writ`](add-a-required-column.lib.writ). Siblings:
[`../drop-a-column/`](../drop-a-column/),
[`../rename-a-column/`](../rename-a-column/).
