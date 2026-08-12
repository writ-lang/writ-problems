# Renaming a database column without breaking production

This directory holds a worked example. It checks whether a plan for renaming a
database column is safe, and it refuses a plan that is not.

You do not need to know anything about `pol` to read this page. The words it
uses are explained as they appear, and there is a glossary at the end.

---

## 1. The problem, in plain terms

Say you have a table of users, and one column is called `name`. You decide it
should be called `full_name`.

In a private project you would rename it and move on. In a running service you
cannot, and the reason is worth being precise about.

**Your database and your application are deployed separately.** They are two
different things, changed at two different moments. There is always a gap
between "the database changed" and "all the code that talks to it changed".
During that gap, something is out of step.

Suppose you rename the column first. For a few seconds — or a few minutes, if
the deploy is slow — your running application is still asking for `name`. That
column no longer exists. Every request that touches it fails.

Suppose you deploy the code first. Now your application asks for `full_name`,
and the database does not have that column yet. Same outcome, other direction.

There is no ordering of those two steps that works. That is the whole
difficulty, and it is why a rename becomes a sequence of small, individually
safe steps instead of one big one.

### It gets harder: two versions of your code run at the same time

Most deployments are *rolling*. The new version is not switched on everywhere
at once. It replaces the old one machine by machine, or container by container,
over a period of seconds or minutes.

During that period **both versions are live and both are serving real
traffic**. The old code is still writing rows. The new code is reading them.

This is the part that makes the problem genuinely hard, and it is the part that
survives code review. When you read a migration plan on a screen, you read it
as a list of steps that happen one after another. You do not naturally picture
the moment halfway through step 5 where two different versions of your
application are disagreeing about what the table looks like.

That moment is short. It is also where the outage comes from.

---

## 2. The usual answer: expand, then contract

The standard fix is called **expand/contract**, or sometimes *parallel change*.
The idea is to never have a moment where the database and the code disagree.
Instead of changing one thing, you temporarily have *both* things, and you
remove the old one only when nothing is using it any more.

For our rename it goes like this:

1. **Expand.** Add the new column `full_name` alongside `name`. Nothing reads
   or writes it yet, so adding it is safe.
2. Deploy code that **writes both columns** but still **reads the old one**.
   Now every new row has both values.
3. **Backfill.** Copy `name` into `full_name` for all the old rows that were
   written before the column existed.
4. Deploy code that **reads the new column**. It still writes both.
5. Deploy code that **only uses the new column**. It stops writing `name`.
6. **Contract.** Drop the `name` column. Nothing reads or writes it now.

Each step is small and each one is reversible until the last. This is a good
pattern and it is widely used.

The trouble is that the pattern tells you *what* the steps are. It does not
tell you whether *your* version of it has the steps in the right order, or
whether you have left out one that matters. Those are the mistakes people
actually make, and this directory is about catching them.

---

## 3. Four ways it can still go wrong

Here are the four mistakes this example checks for. Each is easy to make and
none of them is obvious from reading a plan.

### Mistake 1 — reading a column that is not there yet

You deploy the code that reads `full_name` before you have added the column.

Every read fails. This one is usually caught, because it breaks immediately and
loudly, in every environment including your laptop.

### Mistake 2 — writing a column that is not there yet

Same idea, on the write path. You deploy code that writes `full_name` before
the column exists.

Also loud, also usually caught.

### Mistake 3 — reading a column before the backfill has finished

This one is quieter, and it is the one this example is built around.

Adding a column does not fill it in. When you run `ALTER TABLE ... ADD COLUMN
full_name`, every row that already existed gets an empty value. Only rows
written *after* that moment get a real one.

So if you deploy the code that reads `full_name` before copying the old values
across, that code works perfectly for recent rows and returns nothing for old
ones.

Now think about where you would notice. Your staging database was probably
created recently, or reset recently. Every row in it was written after the
column was added. So every row in staging has a value, and staging looks
completely fine.

Production has five years of rows that predate the column. Those are the ones
that come back empty.

### Mistake 4 — one live version reads a column the other one does not write

This is the rolling-deploy trap, and it is the reason the whole exercise is
worth doing.

Picture the moment mid-deploy. Two versions are live:

- The **old** version writes only `name`.
- The **new** version reads `full_name`.

A user hits the old version and creates a record. The old version writes
`name` and nothing else, because it has never heard of `full_name`.

A second later the same user hits the new version and looks at that record. The
new version reads `full_name`. It is empty, because the version that wrote the
row did not fill it in.

The record was created seconds ago. It is not old data. The backfill you ran
last week does not help, because the backfill ran *before* this row existed.

The window lasts exactly as long as your deploy. Then it closes, and the
symptom disappears, and you are left with a handful of broken records and no
obvious cause.

**This is why the pattern has a step that looks redundant.** Step 2 above
deploys code that writes both columns and reads the old one. It seems pointless
— why write a column nobody reads? The answer is that it makes the *next*
deploy safe. When the reader goes out, the version it is rolling alongside is
already writing what it reads.

Skip that step and everything still works in testing. It breaks in production
for about ninety seconds.

---

## 4. What this directory does

It writes the migration down as a model, and then it checks every possible way
the migration could unfold.

That is the important difference from a code review. A reviewer reads the plan
as one sequence. This checks *every* sequence the plan allows — every order the
steps could happen in, and every combination of what is deployed, what exists
in the database, and what has been backfilled.

There are 10 such situations for the safe plan. A person could work through 10
by hand, though they probably would not bother. The point is that the tool
works through all of them every time, including after you edit the plan, and it
tells you which step causes a problem rather than just that one exists.

Two files describe two plans:

- `db-migration-problem.pol` — a plan that is safe.
- `db-migration-problem-shortcut.pol` — the same plan with **one line
  changed**. It looks fine. It is not.

Both are asked exactly the same questions, from the same file. That is
deliberate: when the answers differ, the only thing that could have caused the
difference is the one changed line.

---

## 5. Running it

You need `pol` installed. If you do not have it, see the
[install instructions](https://github.com/sajonaro/pol#install); the short
version is `opam pin add pol git+https://github.com/sajonaro/pol.git`.

Then, from this directory:

```console
$ pol check db-migration-problem.pol --claims db-migration-problem.claims
```

That checks the safe plan. To check the unsafe one:

```console
$ pol check db-migration-problem-shortcut.pol --claims db-migration-problem.claims
```

Note that the second command uses the *same* questions file as the first.

---

## 6. Reading the output: the safe plan

Here is what the first command prints, in full, with an explanation of each
part underneath.

```
states: 10   edges: 9
gaps: none
dead ends: 1
  reached by: add-column, deploy-r2, settle, backfill, deploy-r3, settle, deploy-r4, settle, drop-column
equation read-of-existing
  can be broken by: add-column, deploy-r2, deploy-r3, deploy-r4, settle, drop-column   (acknowledge in claims)
equation write-of-existing
  can be broken by: add-column, deploy-r2, deploy-r3, deploy-r4, settle, drop-column   (acknowledge in claims)
equation read-of-filled
  can be broken by: backfill, deploy-r2, deploy-r3, deploy-r4, settle   (acknowledge in claims)
equation read-implies-every-writer
  can be broken by: deploy-r2, deploy-r3, deploy-r4, settle   (acknowledge in claims)
holds  completes
  witness:  1. add-column
            2. deploy-r2
            3. settle
            4. backfill
            5. deploy-r3
            6. settle
            7. deploy-r4
            8. settle
            9. drop-column
holds  no-dead-ends
```

And the exit code is 0, which means nothing is wrong.

### `states: 10   edges: 9`

There are 10 distinct situations this migration can be in, and 9 possible moves
between them. A "situation" here means a complete snapshot: which columns
exist, whether the backfill has run, and which versions of the code are live.

The number is small because the plan is tightly constrained. A looser plan
allows more situations. You will see this below — the unsafe plan has 15.

### `dead ends: 1`

A dead end is a situation with no moves available. There is exactly one here,
and it is the finished migration: the column is dropped, the last version is
everywhere, there is nothing left to do. That is the correct number. If it were
higher, the plan would have a way to get stuck partway.

The line underneath it shows how to reach it.

### `equation ...` and `can be broken by: ...`

An `equation` is a rule that must always hold. There are four, and they are the
four mistakes from section 3.

`can be broken by` lists the steps that *touch* the things the rule is about.
It is not saying the rule is broken. It is saying "if this rule ever breaks, it
will be one of these steps that did it".

Almost every step appears in almost every list, and that is not a flaw in the
example. It is the point. Nearly every action in a migration can, in principle,
affect nearly every compatibility rule. That is exactly why reading a plan and
nodding is not enough.

`(acknowledge in claims)` means the questions file has to say, explicitly, "yes,
I know this step could affect this rule". The file does that for all of them.
It is a signature, not a check: it forces whoever writes the plan to have
looked at each one. If you leave any out, the exit code becomes 1.

### `holds  completes`

`completes` is a question the questions file asks. It means: *is it possible to
get all the way to the end?* The answer is yes.

**The list underneath it is the answer, and it is the most useful thing here.**
Nobody wrote that sequence of nine steps. `pol` searched for a way to reach the
finished state and printed the route it found. That route is your runbook.

Read it and you can see the pattern doing its work:

| # | step | what happens |
| --- | --- | --- |
| 1 | `add-column` | `full_name` is created, empty |
| 2 | `deploy-r2` | rollout starts: the version that writes both columns |
| 3 | `settle` | rollout finishes; only that version is live now |
| 4 | `backfill` | old rows get their `full_name` filled in |
| 5 | `deploy-r3` | rollout starts: the first version that *reads* the new column |
| 6 | `settle` | rollout finishes |
| 7 | `deploy-r4` | rollout starts: the version that stops writing `name` |
| 8 | `settle` | rollout finishes |
| 9 | `drop-column` | `name` is removed |

Notice two things about the order.

The backfill is at step 4, **after** the writer is fully deployed and
**before** the reader goes out. That placement is not decoration. If you
backfill before the writer is everywhere, the old version keeps creating rows
behind you. If you backfill after the reader is out, the reader has already
been returning empty values.

Every deploy is followed by a `settle`. The plan never starts one rollout while
another is still in progress.

### `holds  no-dead-ends`

This asks a stronger question: *from every situation you could possibly be in,
can you still finish?*

Yes. That means there is no move in this plan that paints you into a corner.
Whatever order things happen in, and wherever you pause, the migration can
still be completed. You cannot get halfway and discover you are stuck.

This is a different question from "can it finish", and it is the more valuable
one. A plan can have a working path and still have a trap next to it.

---

## 7. The unsafe plan

`db-migration-problem-shortcut.pol` is the same file with one condition
deleted. In the safe plan, the step that deploys the reader has this condition:

```lisp
(when (and settled (is prod.new r2) (is full-col.filled yes)))
```

The last part means "and the backfill has finished". In the shortcut it is
gone:

```lisp
(when (and settled (is prod.new r2)))
```

So the reader is allowed out before the backfill.

**Why anyone would write this.** At that moment the column exists. Every live
version writes it. Every row you can see in staging has a value. The backfill
feels like a tidy-up job that can happen later, and skipping it makes the
migration shorter. It is a reasonable-looking decision, which is what makes it
worth catching automatically.

### What `pol` says

```
states: 15   edges: 17
equation read-of-filled
  can be broken by: backfill, deploy-r2, deploy-r3, deploy-r4, settle   (acknowledge in claims)
  violated in 5 reachable situations   witness: 1. add-column 2. deploy-r2 3. settle 4. deploy-r3
holds  completes
holds  no-dead-ends
```

The exit code is 1, which means something is wrong.

The important line is the new one:

```
violated in 5 reachable situations   witness: 1. add-column 2. deploy-r2 3. settle 4. deploy-r3
```

This says three things.

**The rule is actually broken**, not merely breakable. There are 5 situations
you can genuinely reach where a version is reading a column that has not been
filled in.

**Here is how to reach one**, in four moves. Add the column, deploy the writer,
let it settle, deploy the reader. That is it. No unusual ordering, no
concurrency, no bad luck. It is the obvious thing to do, and it is wrong.

**The step that does it is named.** `deploy-r3`. You do not have to work out
which part of the plan is at fault.

Compare the state counts: 10 for the safe plan, 15 for the unsafe one. Removing
a condition let the migration into five situations it previously could not
reach. All five are bad ones.

### It still finishes, and it is faster

Look again at the output above. `holds completes` — the shortcut can still
reach the end. And `holds no-dead-ends` — it never gets stuck either.

The route it prints is **eight** steps rather than nine, because it skips the
backfill wait.

So the unsafe plan is genuinely quicker, genuinely finishes, and never strands
you. Every measure you would naturally reach for says it is fine. The only
thing wrong with it is that some of your users see empty names for a minute and
a half, and by the time anyone reports it the evidence is gone.

This is worth sitting with, because it is the general shape of the problem: the
dangerous plan is not the one that looks dangerous.

---

## 8. One tool that does not catch it

`pol` has a command for comparing two versions of a model, which sounds like
exactly what you would want here:

```console
$ pol compare db-migration-problem.pol db-migration-problem-shortcut.pol
equations:   read-of-existing           preserved
             write-of-existing          preserved
             read-of-filled             preserved
             read-implies-every-writer  preserved
properties:  completes                  preserved
             no-dead-ends               preserved
```

Everything preserved. Exit code 0. **It does not notice the problem**, and it
is not malfunctioning.

`compare` answers the question "which guarantees did this version give up?"
The shortcut gave none up. It still declares all four rules. It still satisfies
both properties. On that question the two files really are equivalent.

The problem is a different question: "does this version keep the rules it
declares?" That is what `check` answers.

The practical warning: if you put the wrong command in your CI pipeline, it
will go green on a plan that breaks production. Use `check`.

---

## 9. Using it as a gate

`pol check` exits 0 when it finds nothing and 1 when it does. That is all a CI
step needs:

```sh
pol check db-migration-problem.pol --claims db-migration-problem.claims
```

If the exit code is 1, the build fails, and the output already names the rule,
the number of bad situations, and the step responsible.

To use this on your own migration, edit the model rather than this page. See
the next section.

---

## 10. Adapting it to your own migration

The model has four parts you would change. You do not need to understand the
whole language to change them.

**1. The columns.** Near the top of the instance block:

```lisp
(column name-col (state present) (filled yes))
(column full-col (state absent)  (filled no))
```

`state` is whether the column exists. `filled` is whether every row has a value
for it. Add a line per column you care about.

**2. What each version of your code does.** This is the part worth getting
right, because it is where the real knowledge lives:

```lisp
(reads  rd1 (by r1) (col name-col))
(writes wr1 (by r1) (col name-col))
```

One line per (version, column) pair. `reads` and `writes` are separate lists.
If release `r2` writes two columns, it gets two `writes` lines.

Work these out from your actual code, not from your plan. The plan says what
you meant; the code says what will happen.

**3. The steps, and their conditions.** Each `transition` is one action, and
its `when` clause is the precondition you are claiming to have checked:

```lisp
(transition deploy-r3
  (when (and settled (is prod.new r2) (is full-col.filled yes)))
  (do (set prod.new r3)))
```

Read that as: *deploying r3 is allowed when the fleet is settled on r2 and the
backfill has finished.* If your runbook has a step with no precondition, write
`(when ...)` with whatever is genuinely true, and let the rules tell you if it
is not enough.

**4. The rules.** The four `equation` blocks are the compatibility rules. They
are generic — they are about columns and releases, not about `full_name` — so
you probably do not need to change them at all.

If you add a step, `pol` will tell you it is unacknowledged and exit 1 until
you add a line to the questions file saying you have considered it. That is
intentional.

---

## 11. How the model is put together

You can skip this section. It is here for readers who want to understand the
model itself rather than use it.

**Everything is a state machine.** You describe the kinds of things that exist,
one starting situation, and the moves. `pol` works out every situation
reachable from the start and answers questions about all of them.

**The moves are what an operator can do**, and their conditions are the
runbook. The rules are written separately as `equation` blocks, and this
separation is what makes the output useful. If the rules were conditions on the
moves, an unsafe move would simply be impossible and you would learn nothing.
Because they are separate, `pol` can tell you that a move is *allowed by the
plan* but *breaks a rule*, which is the actual finding.

**A release reads and writes several columns**, so "what r2 writes" is a list,
not a single value. The model holds it as a set of small records — one per
(release, column) pair — and asking "does r2 write this column?" means checking
whether such a record exists. That is the `some` you will see in the rules.

**The fleet has two slots**, `old` and `new`. When they hold the same release,
one version is live. When they differ, a rollout is in progress and both are
serving. Every rule has to hold for both, which is what makes the fourth rule
expressible at all.

**Each rule is written from the fleet's point of view** and reaches the
read/write lists through `some`. This is not a stylistic choice: a rule in this
language ranges over one kind of thing, and its paths are written from that
kind rather than from a specific named item. That is why the rules read like
"there is no live release such that ..." rather than "for every pair of
releases ...".

---

## 12. The files

| file | what it is |
| --- | --- |
| `db-migration-problem.pol` | the safe plan: columns, releases, steps, four rules |
| `db-migration-problem-shortcut.pol` | the same, with one condition removed |
| `db-migration-problem.claims` | the questions, and the acknowledgements |
| `db-migration-problem.lib.pol` | shared definitions, loaded by both of the above |
| `db-migration-problem.rules` | the same two questions written a second way |

The last file exists as a cross-check. The two questions are answered twice, by
two different parts of `pol` that share no code. If the two answers ever
disagree, one of them has a bug — and that is a much better test than a number
someone chose by hand.

The shared definitions live in their own file because the questions file cannot
see definitions made inside the model. They are two separate documents, and
anything used in both has to be somewhere both can load.

---

## 13. Glossary

**backfill** — copying values into a newly added column for rows that already
existed. Adding a column does not do this; the column starts empty for every
existing row.

**claims file** — a file of questions, kept separate from the model. Separating
them means one set of questions can be asked of several models, which is
exactly what happens here.

**equation** — a rule that must always hold. `pol` reports both which steps
could break it and whether any reachable situation actually does.

**expand/contract** — the pattern in section 2. Add the new thing, run both
side by side, remove the old thing once nothing uses it.

**holds / fails** — the verdict on a question. `holds` means yes.

**rolling deploy** — replacing a running version gradually rather than all at
once, so that two versions serve traffic at the same time.

**situation** — one complete snapshot of everything the model tracks. Called a
"state" in the output.

**transition** — one move: something an operator does, with a condition saying
when it is allowed.

**witness** — the concrete route `pol` prints to back up an answer. For a
question that holds, it is an example that works. For a broken rule, it is the
shortest way to break it.
