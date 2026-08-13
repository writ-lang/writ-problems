# Dropping a column that is still being read

This directory holds a worked example. It checks whether a plan for removing a
database column is safe, and it refuses a plan that is not.

It is the smallest example in this folder, and the one with the shortest path
to an outage: **two moves.** If you only read one of these, read this one.

You do not need to know anything about `writ` to read this page. Every term is
explained where it appears, and there is a glossary at the end.

---

## 1. The problem, in plain terms

You have a column nobody needs any more. Say it is `users.legacy_flag` — it
supported a feature that was switched off last year, and nothing looks at it.

Removing it seems like a three-step job:

1. Change the code so it no longer reads or writes the column.
2. Deploy that change.
3. Drop the column.

That sequence is correct. Nothing about it is wrong. The trap is entirely in
the word *then*, between steps 2 and 3 — and to see it you need one fact about
how deployments work.

### A deploy is not a moment

When you deploy, the new version of your application does not replace the old
one everywhere at once. It replaces it gradually — machine by machine, or
container by container, or pod by pod. This is called a **rolling deploy**, and
it is how nearly all production systems work, because the alternative is
switching everything off and on again.

The rollout takes time. Seconds if you are lucky, minutes if you are not.

**During that whole window, two versions of your application are running at the
same time, and both are serving real traffic.** Some requests go to the new
version. Some go to the old one. Which one you get depends on which machine
happened to receive your request.

That is the fact the whole problem rests on.

### What goes wrong

Go back to step 3. You are about to drop the column, and you believe it is safe
because the code that used it is no longer deployed.

But if the rollout has not finished, the old version *is* still deployed, on
some of your machines. It is still reading `legacy_flag`. It is still writing
it.

You drop the column. Now every request that reaches an old instance and touches
that column fails. Not all requests — only the ones unlucky enough to land on a
machine that has not been replaced yet.

Then the rollout finishes, the last old instance goes away, and the errors
stop.

### Why this one is nasty

It cleans up after itself.

By the time anyone has noticed the error rate, opened a dashboard and started
looking, the cause is gone. The old version is no longer running. The column is
dropped and everything is working. What is left is a few minutes of failed
requests with no obvious explanation and nothing to reproduce.

That is a bad shape for a bug. A failure that stays broken gets fixed. A
failure that fixes itself gets argued about.

### Why it is easy to make

There is nothing on your screen to warn you.

The change that removed the last use of the column was written, reviewed,
approved and merged. The deploy was triggered and reported success — because
"deploy started successfully" and "deploy finished" often look the same in a
chat notification. Dropping the column is plainly the next thing on the list,
and it is one short statement.

The only thing you needed to know was whether the rollout had *finished* rather
than *started*, and nothing you were looking at distinguished those.

---

## 2. The SQL

You do not write models. You write migrations, in SQL. So that is where this
example starts.

There are two files here, because a drop really is one statement:

| file | what it is |
| --- | --- |
| `01-before.sql` | the table with `legacy_flag` |
| `02-after.sql` | the table without it |

Each file also ends with one `INSERT` of a representative user. That is so each
file can be checked on its own, rather than only meaning something next to the
other one.

`writ` reads SQL directly. `writ sql` turns a `.sql` file into a model, and
`writ check` builds it:

```console
$ writ sql 01-before.sql --with-data > before.writ
$ writ check before.writ
states: 1   edges: 0
```

`states: 1` means there is exactly one situation here — which is right, because
a schema on its own does not change. Nothing has happened yet.

If you look inside the generated file, the table comes out like this:

```lisp
(type users
  (text email)
  (bool legacy-flag))
```

One line per column.

### Both files are fine

Now do the same to `02-after.sql`. It also builds. It is also a perfectly good
schema.

**Neither file is wrong, and that is the whole point of this example.**

There is a sibling problem in this folder, `rename-a-column/`, where one of the
SQL files *is* wrong on its own and `writ` refuses it. That does not happen here.
Both of these schemas are correct. Both would pass any review. Both would work
perfectly if you ran them at the right time.

The mistake is in *when* you run the second one, and no amount of reading SQL
will show you that. Timing is not written down in a `.sql` file. There is
nowhere in that file for it to go.

That is why the rest of this page exists.

---

## 3. What this directory does

It writes the plan down — not the SQL, the *plan* — and then checks every way
that plan could unfold.

That is the difference from a code review. A reviewer reads a plan as one
sequence, top to bottom. This checks every sequence the plan allows: every
order the steps could happen in, and every combination of what is deployed and
what exists in the database.

There are only four such situations here. You could work through four by hand.
The point is not that four is a lot — it is that the tool works through them
every time, including after you edit the plan, and tells you which step causes
the problem instead of only that one exists.

Two files describe two plans:

- `drop-a-column.writ` — a plan that is safe.
- `drop-a-column-shortcut.writ` — the same plan with **one word deleted**.

Both are asked exactly the same questions, from the same file. That is
deliberate. When the answers differ, the only thing that could have caused the
difference is that one word.

---

## 4. Running it

You need `writ` installed. If you do not have it, see the
[install instructions](https://github.com/writ-lang/writ#install); the short
version is `opam pin add writ git+https://github.com/writ-lang/writ.git`.

From this directory:

```console
$ writ check drop-a-column.writ --claims drop-a-column.claims
```

That is the safe plan. And the unsafe one:

```console
$ writ check drop-a-column-shortcut.writ --claims drop-a-column.claims
```

Note that the second command uses the **same** questions file as the first.

---

## 5. Reading the output: the safe plan

Here is what the first command prints, in full.

```
states: 4   edges: 3
gaps: none
dead ends: 1
  reached by: deploy-r2, settle, drop-column
equation read-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
equation write-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
holds  completes
  witness:  1. deploy-r2
            2. settle
            3. drop-column
holds  no-dead-ends
```

The exit code is 0, which means nothing is wrong.

Now each part of that.

### `states: 4   edges: 3`

There are four distinct situations this job can be in, and three possible moves
between them.

A **situation** means a complete snapshot: whether the column still exists, and
which versions of the application are running. Four is small because the plan
is tightly constrained — it does not allow much to happen. You will see the
unsafe plan has five, and the extra one is the bad one.

### `gaps: none`

A gap is a point where the plan does not say what happens. There are none here,
which means every situation has a defined outcome. This line matters more in
larger models; here it is confirmation that nothing was left out.

### `dead ends: 1`

A dead end is a situation with no moves left. There is exactly one, and it is
the finished job: the column is dropped, the new release is everywhere, there
is nothing more to do.

One is the right number. If it were higher, some path through the plan would
leave you stuck partway through with no way forward.

The line underneath shows how to get there.

### `equation read-of-existing`

An **equation** is a rule that must always be true. There are two here, and
they are the obvious two:

| rule | what it forbids |
| --- | --- |
| `read-of-existing` | a running release reading a column that is not there |
| `write-of-existing` | a running release writing a column that is not there |

### `can be broken by: deploy-r2, settle, drop-column`

This line is easy to misread, so it is worth being clear.

It is **not** saying the rule is broken. It is saying: *if this rule is ever
broken, one of these three steps will be what broke it.* These are the steps
that touch the things the rule is about.

All three steps appear, because all three change either which column exists or
which releases are running, and the rule depends on both.

### `(acknowledge in claims)`

This means the questions file has to say, in writing, "yes, I know this step
could affect this rule". The file does that for every pair.

It is a signature, not a check. Nothing is verified by it. What it does is
force whoever writes the plan to look at each combination once and confirm they
have thought about it. If you leave any out, the exit code becomes 1 and `writ`
tells you which.

### `holds  completes`

`completes` is one of the two questions in the questions file. It asks: *is it
possible to get all the way to the end?*

Yes. And the three steps printed underneath are how — that list is the answer,
not decoration. `writ` searched for a route to the finished state and printed
the one it found.

| # | step | what happens |
| --- | --- | --- |
| 1 | `deploy-r2` | the rollout of the release that stops using the column begins |
| 2 | `settle` | the rollout **finishes**; the old release is gone from every machine |
| 3 | `drop-column` | the column is removed |

Step 2 is the entire safety of this plan. It is not a thing you do — it is a
thing you *wait for*.

### `holds  no-dead-ends`

This is a stronger question: *from every situation you could possibly be in,
can you still get to the end?*

Yes. There is no move in this plan that paints you into a corner. Wherever you
pause, and whatever order things happen in, you can still finish.

This is a different question from "can it finish", and worth asking separately.
A plan can have a working route and still have a trap sitting next to it.

---

## 6. The plan, and where the safety lives

The whole plan is three steps, and the safety is one word in one condition.

In the model, a step is written with the condition that has to hold before it
is allowed. The drop looks like this:

```lisp
(transition drop-column
  (when (and settled (is prod.new r2) (is flag-col.state present)))
  (do (set flag-col.state absent)))
```

Read it as prose: *dropping the column is allowed when the fleet is settled,
the new release is r2, and the column is still there.*

`settled` is the word that matters. It means one release is running rather than
two — in other words, the rollout has finished.

That is the whole plan. There is no clever part.

---

## 7. The shortcut

`drop-a-column-shortcut.writ` is the same file with `settled` deleted:

```lisp
(when (and (is prod.new r2) (is flag-col.state present)))   ; `settled`, gone
```

Now the drop is allowed as soon as the new release has *started* going out.

**Read the two conditions as English and they say the same thing.** Both mean
"drop the column once the new release is out". One of them means *out
everywhere*, and the other means *on its way*. In a sentence those are the same
sentence. In production they are minutes apart.

### What `writ` says

```
states: 5   edges: 5
gaps: none
dead ends: 1
  reached by: deploy-r2, settle, drop-column
equation read-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
  violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column
equation write-of-existing
  can be broken by: deploy-r2, settle, drop-column   (acknowledge in claims)
  violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column
holds  completes
  witness:  1. deploy-r2
            2. settle
            3. drop-column
holds  no-dead-ends
```

The exit code is 1, which means something is wrong.

### The new line

```
violated in 1 reachable situations   witness: 1. deploy-r2 2. drop-column
```

This says three things at once.

**The rule is actually broken.** Not "could be broken" — broken. There is a
situation you can genuinely reach in which a running release is reading a
column that is not there.

**Here is how to reach it, in two moves.** Start the deploy. Drop the column.
That is the entire route. No unusual ordering, no concurrency, no bad luck —
just the two things you were going to do anyway, in the order you were going to
do them.

**Both rules break**, reads and writes alike, because the old release does both
to that column.

### Compare the two state counts

The safe plan has four situations. The unsafe one has five.

Removing one word let the plan into one situation it previously could not
reach. That situation is the outage.

### And it still looks fine on every other measure

Look again at the bottom of the output. `holds completes` — the shortcut still
reaches the end. `holds no-dead-ends` — it never gets stuck. The route it
prints is the same three steps as the safe plan.

So: it finishes, it cannot strand you, and it does the same work. Every
question you would naturally think to ask answers in its favour.

The only question that catches it is whether it is safe *on the way*, and that
is not a question people usually think to ask, because answering it means
considering situations rather than steps.

---

## 8. Using it as a gate

`writ check` exits 0 when it finds nothing and 1 when it finds something. That
is all a CI step needs:

```sh
writ check drop-a-column.writ --claims drop-a-column.claims
```

If the exit code is 1, the build fails, and the output already names the rule,
counts the affected situations, and prints the shortest route to one of them.

One warning. `writ` has a command for comparing two models, and it is the wrong
tool here:

```console
$ writ compare drop-a-column.writ drop-a-column-shortcut.writ
```

It reports everything preserved and exits 0. That is correct — it answers
"which guarantees did this version give up?", and the shortcut gave none up. It
still declares both rules. It simply breaks one of them. Use `check`.

---

## 9. Adapting it to your own migration

Four things to change, and you do not need to understand the whole language to
change them.

**1. The column.** In the instance block:

```lisp
(column flag-col (state present))
```

`state` is whether the column exists. Add a line per column you are removing.

**2. What each release does.** This is the part worth getting right:

```lisp
(reads  rd1 (by r1) (col flag-col))
(writes wr1 (by r1) (col flag-col))
```

One line per release-and-column pair. `r2` appears in neither list, which is
exactly what makes it the release that no longer uses the column.

Work these out from your **code**, not from your plan. The plan says what you
meant to do. The code says what will actually happen. If some background job,
report or admin screen still reads the column, it belongs on this list, and it
is precisely the thing everyone forgets.

**3. The steps and their conditions.** Each `transition` is one action and its
`when` clause is the precondition you are claiming to have checked.

**4. Usually nothing in the rules.** The two `equation` blocks are about
columns and releases in general, not about your particular column, so they tend
to carry over unchanged.

If you add a step, `writ` will report it unacknowledged and exit 1 until you add
a line to the questions file saying you have considered which rules it could
affect. That is intentional.

---

## 10. How the model is put together

You can skip this. It is here for readers who want to understand the model
rather than use it.

**Everything is a state machine.** You describe the kinds of things that exist,
one starting situation, and the moves that are possible. `writ` works out every
situation reachable from the start, and answers questions about all of them at
once.

**The moves are what an operator can do**, and their conditions are the plan.
The rules are written separately. That separation is what makes the output
useful: if the rules were conditions on the moves, an unsafe move would simply
be impossible, and you would learn nothing. Because they are separate, `writ` can
say that a move is *allowed by your plan* but *breaks a rule* — which is the
finding you actually want.

**A release reads and writes several columns**, so "what r1 reads" is a list
rather than a single value. The model stores it as small records, one per
release-and-column pair, and asking "does r1 read this column?" means asking
whether such a record exists.

**The fleet has two slots**, `old` and `new`. When they hold the same release,
one version is running. When they differ, a rollout is in progress and both are
serving. `settled` is just the test that they are equal.

**Each rule is written from the fleet's point of view.** A rule in this
language ranges over one kind of thing, and its paths are written from that
kind rather than from a named item — which is why the rules read "there is no
release currently running that ..." rather than naming `r1` directly.

---

## 11. The files

| file | what it is |
| --- | --- |
| `01-before.sql` | the table with the column, and one row |
| `02-after.sql` | the table without it, and one row |
| `drop-a-column.writ` | the safe plan |
| `drop-a-column-shortcut.writ` | the same, one word lighter |
| `drop-a-column.claims` | the questions, and the acknowledgements |
| `drop-a-column.lib.writ` | definitions shared by the model and the questions |
| `drop-a-column.rules` | the same two questions written a second way |

The last file is a cross-check. The two questions get answered twice, by two
parts of `writ` that share no code. If the two answers ever disagree, one of them
has a bug — which is a better test than a number somebody chose by hand.

The shared definitions have their own file because the questions file cannot
see definitions made inside the model. They are two separate documents, so
anything used in both has to live somewhere both can load.

---

## 12. What this one teaches

That a migration can be **wrong in time rather than wrong in content**.

Every artifact here is correct. Both schemas are valid. Both releases are
correct. The three steps are in the right order. There is no bad line of SQL
and no bad line of code anywhere in this directory.

The only defect is that one step is permitted to begin before another has
finished — and that defect does not live in a statement. It lives in a
condition, and conditions are the part of a plan nobody writes down.

If you only ever check artifacts — the DDL, the diff, the code — you cannot see
this class of mistake at all. You have to check the sequence, and checking the
sequence means writing it somewhere a tool can read.

For a problem where the SQL alone *does* catch something, see
[`../rename-a-column/`](../rename-a-column/). For one where the mistake is
adding a constraint before the code that can satisfy it, see
[`../add-a-required-column/`](../add-a-required-column/).

---

## 13. Glossary

**claims file** — a file of questions, kept separate from the model. Keeping
them apart means one set of questions can be asked of several models, which is
exactly what happens here.

**equation** — a rule that must always hold. `writ` reports both which steps
could break it and whether any reachable situation actually does.

**fleet** — the running application, as the model sees it: which release is on
the way out and which is on the way in.

**holds / fails** — the verdict on a question. `holds` means yes.

**rolling deploy** — replacing a running version gradually rather than all at
once, so two versions serve traffic at the same time.

**settled** — one release running rather than two. The rollout has finished.

**situation** — one complete snapshot of everything the model tracks. Printed
as `states` in the output.

**transition** — one move: something an operator does, with a condition saying
when it is allowed.

**witness** — the concrete route `writ` prints to back up an answer. For a
question that holds, an example that works. For a broken rule, the shortest way
to break it.
