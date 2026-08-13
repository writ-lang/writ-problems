# Making a column required, before the code can keep the promise

This directory holds a worked example. It checks whether a plan for making a
database column mandatory is safe, and it refuses a plan that is not.

You do not need to know anything about `writ` to read this page. Every term is
explained where it appears, and there is a glossary at the end.

---

## 1. The problem, in plain terms

You want every user to have a country. Today there is no such column, so the
job is: add it, fill it in, and make it mandatory.

You cannot do that in one step, and the database will tell you so immediately:

```sql
ALTER TABLE users ADD COLUMN country text NOT NULL;
```

That is rejected on a table that already has rows. Every existing row would
need a value for a column that did not exist a moment ago, and none of them has
one.

So the column arrives nullable, gets filled in, and only then becomes required.
Three database steps and one deploy.

That much is well known. The mistake this example is about happens *after* you
know it.

---

## 2. What a `NOT NULL` constraint actually is

This is worth being precise about, because it is where the mistake comes from,
and the usual mental model of it is subtly wrong.

`NOT NULL` is not a statement about the data you have. It is a **promise the
database makes on behalf of your code**: from this moment on, every insert will
supply a country.

That promise has two halves.

### Half one: the rows that already exist

Every row currently in the table must have a value.

**The database checks this itself.** If any row holds a `NULL`, the `ALTER` is
rejected on the spot, loudly, with an error naming the problem. You go and run
your backfill, and try again.

Because this half fails so visibly, it teaches you something — and what it
teaches you is slightly dangerous. It teaches you to expect a complaint when
something is wrong.

### Half two: the rows that are about to be written

Every row your application writes from now on must have a value too.

**The database cannot check this**, because those rows do not exist yet. Whether
the promise holds depends entirely on whether the code currently running
supplies a country on every insert.

There is no error for this. There is no warning. The `ALTER` succeeds.

### Backfilling covers one half and not the other

This is the sentence the whole example rests on.

The backfill fixes the rows that already exist. It says nothing at all about
the rows the deployed release is about to write — and if that release has never
heard of the column, it is about to write rows without one.

---

## 3. The mistake

Here is the sequence, and it is entirely reasonable at every step:

1. You add the column, nullable. Fine.
2. You backfill it — every existing user gets a country from somewhere.
3. You add the `NOT NULL` constraint. **It succeeds**, because every row the
   database can see has a value.

Nothing was flagged. The backfill worked. The `ALTER` worked. You are done.

Except the release running in production is the one from before all this. Its
inserts do not mention `country`, because when that code was written the column
did not exist. The next time a user signs up, the insert supplies no country,
the constraint rejects it, and sign-up starts failing.

The failure is not in anything you ran. It is in code you have not deployed
yet — and there is no step in the sequence above where anyone would have
thought to check.

### Why it is a good trap

Because the half you get reminded about is the half that was fine.

You *did* get an error the first time, when you tried `ADD COLUMN ... NOT NULL`
on a table with rows. You dealt with it. You ran the backfill. You now feel
that this migration has been checked, because something checked it and you
responded.

The half nobody checked is silent, and silence reads as approval.

---

## 4. The SQL

You do not write models. You write migrations, in SQL. So that is where this
example starts.

Three files, one per database step:

| file | what it is |
| --- | --- |
| `01-before.sql` | the table today: no country at all |
| `02-add-nullable.sql` | the column added, nullable, `NULL` for the existing row |
| `03-required.sql` | the column as `NOT NULL` |

Each also carries one representative row, so each file can be checked on its
own rather than only meaning something beside the others.

`writ sql` turns a `.sql` file into a model and `writ check` builds it:

```console
$ writ sql 02-add-nullable.sql --with-data > step2.writ
$ writ check step2.writ
states: 1   edges: 0
```

Inside the generated file, the table looks like this:

```lisp
(type users
  (text email)
  (text? country))
```

The question mark on `text?` means the column is allowed to be `NULL`. Without
it, the column is required. That one character is how `writ` writes the
difference between the second file and the third.

### All three files are correct

Run the same two commands on `01-before.sql` and `03-required.sql`. Both build.
All three are valid schemas, and each is exactly what you want at its own point
in the migration.

`03-required.sql` is only correct **at the right moment** — after the backfill,
and after the deploy. Neither of those facts is in the file, and there is
nowhere in a `.sql` file for them to go.

That is why the rest of this page exists.

---

## 5. What this directory does

It writes the plan down and checks every way that plan could unfold — every
order the steps could happen in, and every combination of what exists in the
database, what has been filled in, and what is deployed.

There are eight such situations. The point is not that eight is a large number.
The point is that the tool works through all of them every time, including
after you change the plan, and names the step that causes a problem instead of
only reporting that one exists.

Two files describe two plans:

- `add-a-required-column.writ` — a plan that is safe.
- `add-a-required-column-shortcut.writ` — the same plan with **one condition
  removed** from the last step.

Both are asked the same questions, from the same file, so any difference in the
answers comes from that one condition.

---

## 6. Running it

You need `writ` installed. If you do not have it, see the
[install instructions](https://github.com/writ-lang/writ#install); the short
version is `opam pin add writ git+https://github.com/writ-lang/writ.git`.

From this directory:

```console
$ writ check add-a-required-column.writ --claims add-a-required-column.claims
$ writ check add-a-required-column-shortcut.writ --claims add-a-required-column.claims
```

Both use the same questions file.

---

## 7. Reading the output: the safe plan

```
states: 8   edges: 9
gaps: none
dead ends: 1
  reached by: add-column, deploy-r2, settle, backfill, require
equation write-of-existing
  can be broken by: add-column, deploy-r2, settle   (acknowledge in claims)
equation required-needs-data
  can be broken by: backfill, require   (acknowledge in claims)
equation required-needs-every-writer
  can be broken by: deploy-r2, settle, require   (acknowledge in claims)
holds  completes
  witness:  1. add-column
            2. deploy-r2
            3. settle
            4. backfill
            5. require
holds  no-dead-ends
```

Exit code 0: nothing is wrong.

### `states: 8   edges: 9`

Eight distinct situations, nine possible moves between them. A **situation**
here is a complete snapshot: whether the column exists, whether every row has a
value, whether the constraint is on, and which releases are running.

### `dead ends: 1`

One situation with no moves left, and it is the finished job. That is the right
number — a second dead end would mean some path leaves you stuck.

### The three rules

An **equation** is a rule that must always be true. There are three, and it is
worth reading them next to the question of who checks each one in real life:

| rule | what it forbids | who catches it for you |
| --- | --- | --- |
| `write-of-existing` | writing a column that is not there | your database, loudly |
| `required-needs-data` | requiring a column some row leaves empty | your database, loudly |
| `required-needs-every-writer` | requiring a column some running release does not write | **nobody** |

That third row is the whole example. Two of these three mistakes announce
themselves the moment you make them. The third is silent until a user tries to
sign up.

### `can be broken by: ...`

This is **not** saying a rule is broken. It says: if this rule is ever broken,
one of these steps will be what broke it. They are the steps that touch the
things the rule depends on.

`(acknowledge in claims)` means the questions file has to say in writing that
you know this step could affect this rule. It is a signature rather than a
check — it forces whoever writes the plan to consider each combination once. If
you leave any out, the exit code becomes 1.

### `holds  completes`

`completes` asks whether it is possible to get all the way to the end: column
present, every row filled, constraint on. Yes — and the five steps printed
underneath are the route `writ` found.

| # | step | what happens |
| --- | --- | --- |
| 1 | `add-column` | the column arrives, nullable |
| 2 | `deploy-r2` | the release that writes a country starts rolling out |
| 3 | `settle` | the rollout **finishes**; nothing running now omits the column |
| 4 | `backfill` | the rows that predate the column get a value |
| 5 | `require` | the constraint goes on |

**Look at the order of steps 2 and 4.** The deploy comes *before* the backfill,
not after.

That ordering is the answer to the whole problem, and it is the opposite of
what feels natural. It feels natural to fix the data first and then ship the
code — data first, code second, tidy. But do it that way and the old release
keeps inserting rows without a country while you work, so the backfill is
already out of date by the time it finishes.

Deploy first and the leak is closed: once the writing release is everywhere, no
new row can arrive without a country. The backfill is then the last remaining
gap, and closing it finishes the job for good.

### `holds  no-dead-ends`

A stronger question: from *every* situation you can reach, can you still get to
the end? Yes — no step paints you into a corner.

---

## 8. Where the safety lives

The last step carries two conditions:

```lisp
(transition require
  (when (and (is country-col.state present)
             (is country-col.filled yes)
             (is country-col.required no)
             (every-live-writes W country-col)))
  (do (set country-col.required yes)))
```

`filled yes` is the first half of the promise — every existing row has a value.

`every-live-writes` is the second half — every release currently running writes
the column.

They guard two different failures, and only one of them has anything else
watching it.

---

## 9. The shortcut

`add-a-required-column-shortcut.writ` is the same file with the second condition
deleted:

```lisp
  (when (and (is country-col.state present)
             (is country-col.filled yes)
             (is country-col.required no)))     ; every-live-writes, gone
```

**Notice what is left.** The remaining condition is the one the database checks
for you. So the step still looks guarded — there is a condition right there,
and it is the condition you were reminded about the first time you got this
wrong.

That is exactly why this mistake is easy. It is not carelessness. It is
guarding the half you were trained to guard.

### What `writ` says

```
states: 10   edges: 13
equation required-needs-every-writer
  can be broken by: deploy-r2, settle, require   (acknowledge in claims)
  violated in 2 reachable situations   witness: 1. add-column 2. backfill 3. require
holds  completes
  witness:  1. add-column
            2. backfill
            3. require
holds  no-dead-ends
```

Exit code 1.

**Three moves.** Add the column, backfill it, require it. There is no deploy in
that list at all — the shortest route through the job never ships the code that
makes the constraint keepable.

### The two lists are the same list

This is the detail worth stopping on.

Read the witness for the broken rule: `add-column, backfill, require`.

Now read the witness for `completes`: `add-column, backfill, require`.

**They are the same three steps.** The route to the finished state and the
route to the fault are the same route. The plan reaches its goal by passing
through a broken situation and coming out the other side, and because it comes
out the other side, `completes` still holds and `no-dead-ends` still holds.

Every question except "is it safe on the way" answers in the shortcut's favour.

### Only one rule breaks

`required-needs-data` — the database's own check — is untouched. The shortcut
is careful about that one.

That is the point rendered as output: the half you were reminded about is
correct, and the half nobody reminded you about is the one that broke.

### And it is faster

Three steps against five. The shortcut skips a deploy and a wait, which is
exactly what makes it shorter, and exactly what makes it wrong.

---

## 10. Using it as a gate

`writ check` exits 0 when it finds nothing and 1 when it does:

```sh
writ check add-a-required-column.writ --claims add-a-required-column.claims
```

If the exit code is 1 the build fails, and the output names the rule, counts
the affected situations, and prints the shortest route to one.

Do not use `writ compare` for this. It answers "which guarantees did this version
give up?", and the shortcut gave none up — it declares all three rules and
satisfies both properties. It simply breaks one of the rules it declares, and
that is what `check` is for.

---

## 11. Adapting it to your own migration

**1. The column.** In the instance block:

```lisp
(column country-col (state absent) (filled no) (required no))
```

Three independent facts: whether it exists, whether every row has a value,
whether the constraint is on.

**2. What each release writes:**

```lisp
(writes wr1 (by r2) (col country-col))
```

One line per release-and-column pair. `r1` appears nowhere, and that absence is
what makes it the release that does not write the column.

Take this from your **code**, not from your plan. Every insert path counts —
including the background job, the admin screen and the data import that nobody
remembers, each of which is a place a row can be created without a country.

**3. The steps and their conditions.** Each `transition` is one action and its
`when` clause is the precondition you are claiming to have checked.

**4. Usually nothing in the rules.** They are about columns and releases in
general rather than about your particular column.

If you add a step, `writ` will report it unacknowledged and exit 1 until the
questions file says you have considered which rules it could affect.

---

## 12. How the model is put together

Skippable. For readers who want the model rather than the result.

**Everything is a state machine.** You describe what exists, one starting
situation, and the possible moves. `writ` works out every reachable situation and
answers questions about all of them.

**Moves are the operator's; rules are separate.** If the rules were conditions
on the moves, an unsafe move would simply be impossible and you would learn
nothing. Keeping them apart lets `writ` say a move is *allowed by your plan* but
*breaks a rule*.

**A release writes several columns**, so the write set is a list of small
records, one per pair, and asking "does r1 write this column?" means asking
whether such a record exists.

**Two of the rules are about the fleet** — which releases are running — and one
is about the column alone. `required-needs-data` needs to know nothing about
who is deployed, so it is written from the column's point of view rather than
the fleet's. A rule in this language ranges over one kind of thing, and picking
the right one is what keeps it short.

---

## 13. The files

| file | what it is |
| --- | --- |
| `01-before.sql`, `02-add-nullable.sql`, `03-required.sql` | the three schemas, each with one row |
| `add-a-required-column.writ` | the safe plan |
| `add-a-required-column-shortcut.writ` | the same, one condition lighter |
| `add-a-required-column.claims` | the questions, and the acknowledgements |
| `add-a-required-column.lib.writ` | definitions shared by model and questions |
| `add-a-required-column.rules` | the same questions written a second way |

The last is a cross-check: the two questions get answered twice, by parts of
`writ` that share no code, so a disagreement means one of them has a bug.

---

## 14. What this one teaches

That **the checks a database performs for you are the ones you will remember,
and the ones it cannot perform are the ones that hurt.**

Both halves of a `NOT NULL` promise matter equally. One is enforced the instant
you make the change, so it trains you to expect a complaint when something is
wrong. The other is about code you have not shipped, so there is no complaint
to expect — and after a while, no complaint starts to feel like confirmation.

The general form: **an unenforced rule is more dangerous next to an enforced
one than it would be alone**, because the enforced one supplies false
reassurance for both.

Writing the plan down is what lets something check the half nothing else does.

The siblings: [`../drop-a-column/`](../drop-a-column/), where the mistake is
purely about timing, and [`../rename-a-column/`](../rename-a-column/), where
two releases disagree mid-rollout.

---

## 15. Glossary

**backfill** — filling in a newly added column for rows that already existed.
Adding a column does not do this.

**claims file** — a file of questions kept separate from the model, so one set
of questions can be asked of several models.

**equation** — a rule that must always hold.

**fleet** — the running application as the model sees it: which release is on
the way out and which is on the way in.

**holds / fails** — the verdict on a question.

**rolling deploy** — replacing a running version gradually, so two versions
serve traffic at the same time.

**settled** — one release running rather than two; the rollout has finished.

**situation** — one complete snapshot of what the model tracks. Printed as
`states`.

**transition** — one move, with a condition saying when it is allowed.

**witness** — the concrete route `writ` prints to back up an answer.
