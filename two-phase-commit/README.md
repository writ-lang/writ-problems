# Agreeing to commit, when either side can vanish

This directory holds a worked example. It checks the oldest protocol for making
two machines change their minds together — and finds, by exhaustion, both the
guarantee it gives and the one it does not.

You do not need to know anything about `pol`, or about distributed systems, to
read this page. Every term is explained where it appears, and there is a
glossary at the end.

---

## 1. The problem, in plain terms

Money leaves one ledger and arrives in another.

```
        ledger A                            ledger B
    ┌──────────────┐                    ┌──────────────┐
    │   balance    │                    │   balance    │
    │   −  100     │                    │   +  100     │
    └──────────────┘                    └──────────────┘
           ╲                                   ╱
            ╲                                 ╱
             ╲____  only messages travel ____╱
                        between them
```

The two ledgers are separate systems. Neither can see inside the other. Either
can crash at any moment, and neither can tell the difference between "the other
one is slow" and "the other one is gone".

What must never happen is obvious. **The money must not leave without
arriving**, and it must not arrive without leaving. Either both sides do the
work, or neither does.

That property has a name — **atomicity** — and the difficulty is a small,
stubborn one:

> There is no shared instant in which both sides can act.

If there were, you would simply act in it and be done. There is not. All they
can do is send each other messages, and a message can be sent to a machine that
is no longer there.

---

## 2. The protocol

**Two-phase commit** is the standard answer. It is about seventy lines of idea.

One machine is the **coordinator**. The others are **participants**. The name
"two-phase" is literal: there is a phase where the coordinator asks, and a phase
where it tells.

### Phase one — ask

The coordinator asks every participant a single question: *can you commit?*

Each participant answers yes or no.

A participant that answers **yes** has done something irreversible in the
ordinary sense: it has **promised**. It has written enough to disk that it could
still commit after a restart, and it has given up the right to change its mind.
It is now **prepared**, and it holds its locks until somebody tells it what was
decided.

A participant that answers **no** has promised nothing, so it can simply abort
on the spot. Nobody is relying on it.

### Phase two — tell

If every answer was yes, the coordinator decides **commit**. If any answer was
no, it decides **abort**. Either way it decides **once**, and then it tells each
participant, one at a time.

### The whole protocol, in one picture

```
     p1                    coordinator                    p2
      │                         │                          │
      │────── vote: yes ───────>│<────── vote: yes ────────│      PHASE ONE
      │                         │                          │        ask
      │                    ┌────┴────┐                     │
      │                    │ decide  │  all yes → commit   │
      │                    │  once   │  any no  → abort    │
      │                    └────┬────┘                     │
      │                         │                          │
      │<───── commit ───────────│──────── commit ─────────>│      PHASE TWO
      │                         │                          │        tell
      │                         │                          │
  committed                                            committed
```

That is the whole thing. What this directory answers is what it buys, and what
it costs.

---

## 3. What a participant can do, and when

Everything difficult about this protocol lives in one state. Here is a
participant's whole life:

```
                     vote no
    working ───────────────────────────────►  aborted
       │                                         ▲
       │ vote yes                                │ told: abort
       ▼                                         │
    prepared ────────────────────────────────────┘
       │
       │ told: commit
       ▼
    committed
```

Look at `prepared` and ask which arrows leave it.

**Both of them are somebody else talking.** A prepared participant has no move
of its own. It cannot commit, because the decision might have been abort. It
cannot abort, because the decision might have been commit. It promised, and now
it waits.

That is not a flaw in the drawing. It is the protocol working as designed —
the promise is exactly what makes atomicity possible. It is also, as we are
about to see, exactly what makes the protocol able to hang.

---

## 4. How the model is written

You can skim this section. It is here so the rest is readable, not because you
need it to follow the results.

A `pol` model is three things: the kinds of thing that exist, one starting
arrangement, and the moves.

### A message is a slot

This is the one interesting modelling choice.

A participant has a `vote` — the message travelling *to* the coordinator — and
an `inbox` — the message travelling *back*. Both are declared `maybe`, which
means the slot is allowed to be **empty**:

```lisp
(type participant
  (arrow state (to pstate))
  (maybe vote  vote-t)              ; in flight to the coordinator
  (maybe inbox dec-t))              ; in flight to this participant
```

An empty slot is not a special value meaning "nothing". It is the *absence* of
an answer, and `pol` can be asked about it directly.

```
   c.decision = commit        the decision HAS been taken
   p2.inbox   = ∅             and p2 has NOT been told

   ─────────────────────────────────────────────────────
   a real situation, findable and printable, not a
   special case somebody had to remember to encode
```

That is what lets "the decision has been taken but has not arrived" be a
situation the tool finds on its own.

### A move is a condition and a change

Voting yes and preparing are one move, because in the protocol they are one act:

```lisp
(transition YES
  (when (is P.state working))
  (do (set P.state prepared) (set P.vote yes)))
```

### A crash is just another move

Nothing in `pol` distinguishes a failure from an intention. Both are things that
can happen.

```lisp
(transition c-crash
  (when (not (is c.state crashed)))
  (do (set c.state crashed)))
```

The condition is only "not already crashed". So this move exists in **every**
situation where the coordinator is alive — before deciding, after deciding,
after telling one participant and not the other. Nobody had to list those cases:

```
   ✗ ← the crash can land at any of these points, and does

   ──✗──> ask p1 ──✗──> ask p2 ──✗──> decide ──✗──> tell p1 ──✗──> tell p2 ──✗──>
```

From that page of rules, `pol` builds **84 situations** and all 152 moves
between them, then answers every question by looking at all of them.

---

## 5. What holds: the parties never disagree

```console
$ pol check two-phase-commit.pol --claims two-phase-commit.claims
states: 84   edges: 152
holds  atomic
holds  can-commit
  witness:  1. p1-yes  2. p2-yes  3. c-commit
            4. deliver-p1  5. p1-commit  6. deliver-p2  7. p2-commit
```

`atomic` is the property the protocol exists to provide, and it is written as a
**`never`**:

```lisp
(property atomic "no participant commits while another aborts"
  (never (and (some (p participant) (is p.state committed))
              (some (q participant) (is q.state aborted)))))
```

A holding `never` is worth more than it looks. It is not "we tried this and it
did not happen". It is a **census**:

```
   all 84 situations
   ┌──────────────────────────────────────────────────┐
   │  ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ●    │
   │  ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ●    │   every one built,
   │  ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ●    │   every one checked
   │  ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ● ●    │
   └──────────────────────────────────────────────────┘
     none has one committed and another aborted
```

Under these rules, that cannot occur. Not "was not observed" — cannot.

`can-commit` matters too, for a duller reason. A protocol that never commits
anything would also satisfy `atomic`, perfectly and uselessly. `can-commit` is
the check that the happy path exists at all, and the seven-move witness is the
proof, printed.

---

## 6. What fails: somebody can be left waiting

```console
fails  can-decide
  stuck at: (p1.state=prepared p2.state=working
             p1.vote=yes p2.vote=∅ p1.inbox=∅ p2.inbox=∅
             c.state=crashed c.decision=∅)
  witness:  1. p1-yes
            2. c-crash
```

`can-decide` asks whether every participant can **still** reach a decision, from
every situation the model can get into.

**Two moves refute it.**

```
   time ──────────────────────────────────────────────────────>

   p1    working ──yes──> prepared ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
                                   └─ holding locks, for ever

   c     collecting ─────────────── ✗ CRASH
                                    └─ decided nothing, told nobody

   p2    working ───────────────────────────────────────────────
                                   └─ never even asked
```

`p1` voted yes. It is prepared: it has promised, and given up deciding for
itself. Then the coordinator dies before deciding anything.

Now look for somebody who knows what should happen. There is nobody. The
decision was never taken, so there is no answer to find — not in a log, not on
another machine, nowhere. `p1` cannot commit, because the decision might have
been abort. It cannot abort, because it might have been commit.

It waits, holding its locks, for ever.

This is the famous criticism of two-phase commit. What is worth noticing is that
the tool did not know that. It was not told this was the interesting case. It
built every situation, found the ones with no way out, and printed the shortest
route into one.

### The dead ends, counted

The report also says `dead ends: 20`. A dead end is a situation with no moves
left at all, and twenty of them is a lot for a protocol this small. Every one is
reached by a crash:

```
  reached by: p1-yes, c-crash
  reached by: p1-yes, p2-yes, c-crash
  reached by: p1-yes, p2-yes, c-commit, c-crash
  reached by: p1-yes, p2-yes, c-commit, deliver-p1, p1-commit, c-crash
  …
```

Read that list downward and you are reading the crash walking later and later
through the protocol. The last one is the crash arriving after everything of
consequence has already happened — harmless. The early ones are not.

---

## 7. Two ways of asking "does it finish"

There are two questions here that sound like one, and the difference is the
reason this scenario exists at all.

| | asks |
| --- | --- |
| **`live F`** | from every situation, is F **still reachable**? *Can* it finish? |
| **`inevitable F`** | from every situation, does **every run** reach F? *Must* it finish? |

A **run** is maximal: it goes on for ever, or it stops where the model stops. So
a run can avoid the goal in two different ways — by stopping short of it, or by
going round for ever without ever taking it.

```
   the same picture, asked two ways:

        (A) ─────► (B) ─────► [done]
         ▲          │
         └──────────┘
           go round again

   live        ✔ HOLDS   — from A and from B, a path to [done] exists
   inevitable  ✘ FAILS   — going round for ever is a run, and it
                            never reaches [done]
```

**On the crashing model, both fail**, and in that order — `inevitable` is the
stronger question, so nothing passes it while failing `live`.

Where they come apart is the second file.

### The lossy model: alive throughout, and still not guaranteed to finish

`two-phase-commit-lossy.pol` has **no crash at all**. The coordinator is alive
the whole way through. The only new move is the network losing a message — after
which the coordinator simply sends it again, which is what every real
implementation does.

```console
$ pol check two-phase-commit-lossy.pol --claims two-phase-commit.claims
states: 42   edges: 82
holds  atomic
holds  can-commit
holds  can-decide
fails  must-decide
  stuck at: (p1.state=prepared p2.state=prepared
             p1.vote=yes p2.vote=yes p1.inbox=∅ p2.inbox=∅
             c.state=decided c.decision=commit)
```

`can-decide` **holds**. Deciding is always still available — the message can
always be sent one more time. There is no situation from which the goal has
become unreachable.

`must-decide` **fails**, and the situation it names is the one the bad run
circles in:

```
        the decision IS taken.  c.decision = commit
        neither participant has been told.  both inboxes ∅

              ┌─────────────────────────────┐
              │                             │
              ▼                             │
        send the decision ────► lost ───────┘
              ▲                             
              └──── and again ──► lost ─────┐
                    and again ──► lost ─────┤
                    and again ──► lost ─────┘
                          for ever
```

Every individual send *could* have arrived. No single moment is unfair. But the
run in which every one of them is lost is a run, and in it nobody ever decides.

> **`live` alone would have called this protocol fine.** That is precisely the
> gap `inevitable` exists to close.

Notice also the size: 42 situations against 84, and 4 dead ends against 20. A
model with **no crash in it** is half the size and has a fifth of the dead ends —
which is a fair measure of how much of two-phase commit's difficulty is the
crash rather than the network.

---

## 8. Asking about the runs that actually happen

The run that loses every message for ever is real. It is also not what anybody
means by "does this terminate".

So the question can say which runs it is about:

```lisp
(property must-decide-if-applied
  "…and no run avoids it, if a participant told the decision eventually applies it"
  (inevitable
    (all (p participant) (or (is p.state committed) (is p.state aborted)))
    (fair p1-commit p1-abort p2-commit p2-abort)))
```

`(fair …)` names moves and says: *a run in which one of these is available again
and again, for ever, and never taken is not a run this question is about.*

```
   without (fair …)              with (fair …)
   ┌──────────────────┐          ┌──────────────────┐
   │ every run counts │          │ every run counts │
   │                  │          │ EXCEPT those that│
   │  incl. the one   │          │ offer p1-commit  │
   │  that ignores a  │   ──►    │ for ever and     │
   │  waiting message │          │ never take it    │
   │  for ever        │          │                  │
   └──────────────────┘          └──────────────────┘
```

On the lossy model, that property **holds**.

Three things about it are worth stating plainly.

### It lives in the questions file, not the model

*Does this terminate whatever the network does?* and *does it terminate if a
participant that has been told the answer eventually acts on it?* are two
different questions about one protocol.

Both are asked here, of the same file. A model that carried the assumption
baked in could only ever be asked one of them.

### The verdict prints the assumption

```
holds  must-decide-if-applied
  assuming fair: p1-commit, p1-abort, p2-commit, p2-abort
```

"This protocol always terminates" and "…unless a participant refuses to act for
ever" are different claims. Only one of them was checked, and the output says
which.

### It does not rescue a deadlock, and should not

On the crashing model, `must-decide-if-applied` **still fails** — same
three-move witness, `p1-yes, p2-yes, c-crash`.

That is correct, and the reason is worth holding onto:

```
   fairness is about runs that go on FOR EVER
   ─────────────────────────────────────────────────
   a run that STOPS is finite.  Nothing is being
   starved in it.  There is simply nothing left.
```

No assumption about scheduling can fix a protocol that has come to a halt.

---

## 9. The cure, and its price

The blocking in §6 is intolerable in practice. Locks held for ever means a table
nobody else can touch.

The obvious remedy is to let a stranded participant give up: if the coordinator
is visibly gone and nothing has arrived, abort. That is
`two-phase-commit-timeout.pol`.

`pol compare` says exactly what it costs:

```console
$ pol compare two-phase-commit.pol two-phase-commit-timeout.pol
properties:  atomic                  LOST      witness: 1. p1-yes 2. p2-yes
                                     3. c-commit 4. deliver-p1 5. p1-commit
                                     6. c-crash 7. p2-timeout
             can-commit              preserved
             can-decide              gained
             must-decide             gained
             must-decide-if-applied  gained
```

Every liveness property is **gained**. And **atomicity is LOST** — the one thing
the protocol existed to provide.

Here is the seven-move run it prints, drawn out:

```
     p1                    coordinator                    p2
      │                         │                          │
   1  │────── vote: yes ───────>│                          │
   2  │                         │<────── vote: yes ────────│
   3  │                    [decide: commit]                │
   4  │<───── commit ───────────│                          │
   5  ▼                         │                          │
   COMMITTED                    │                          │
                           6    ✗ CRASH                    │
                                                           │  waiting…
                                                           │  waiting…
                                                     7  [timeout]
                                                           ▼
                                                        ABORTED

        p1 committed.  p2 aborted.  The money left and never arrived.
```

The coordinator decided commit, told `p1`, and `p1` committed — a correct,
irreversible act on a correct decision. *Then* the coordinator died before
reaching `p2`, which waited, gave up, and aborted. Also a locally reasonable
act.

Two locally correct decisions, one global disaster.

**This is not a bug in the cure.** It is the trade, and it is a real one — that
no protocol of this shape can have both is a theorem about the world, not a
property of this model. What `pol compare` adds is that the trade is **stated
rather than argued**: two files, one table, and the exact run that costs you the
guarantee.

```
   two-phase-commit.pol            two-phase-commit-timeout.pol
   ─────────────────────           ────────────────────────────
   ✔ atomic                        ✘ atomic
   ✘ can-decide                    ✔ can-decide
   ✘ must-decide                   ✔ must-decide

              pick one column
```

---

## 10. Files

| file | what it is |
| --- | --- |
| `two-phase-commit.pol` | the protocol, with a coordinator that can crash |
| `two-phase-commit-lossy.pol` | no crash; the network drops messages and they are resent |
| `two-phase-commit-timeout.pol` | the crashing model plus a participant that gives up |
| `two-phase-commit.claims` | the questions, asked of all three |
| `two-phase-commit.rules` | the same questions as derivations, for the cross-check |

The `.rules` file re-asks four of the five properties through the rules engine,
which computes them a completely different way — a closure over the situations
where the goal fails, rather than a partition of them. `modality-cross-check.sh`
runs both and compares.

The fifth is skipped, and says so rather than passing quietly. It carries a
`(fair …)` clause, and the rules encoding does not model fairness, so deriving
it would answer a different question and then report the disagreement as a bug.

---

## 11. What this scenario is not

`pol` has no numbers, no unbounded collections and no clocks, and this model
shows the shape of what that rules out.

There are **two** participants because they are named, not because two is
enough — a third is another two lines, and multiplies the situations. A message
is one slot, so a channel here cannot hold two messages at once and cannot
reorder them.

So this is a tool for a protocol small enough to name every part of, asked
questions whose answers are "in every case" or "in none". A protocol with
retries *and* reordering, or one whose correctness depends on timeouts being
longer than round trips, is a question for a different instrument.

Two-phase commit fits because everything that matters about it fits in
eighty-four situations — which is also why its flaw is two moves deep and has
been known for forty years.

---

## Glossary

**atomicity** — every party does the work or none does; never some of each.

**coordinator / participant** — the machine that decides, and the machines that
do the work and are told.

**prepared** — a participant that has voted yes: it has promised to commit if
told to, so it may no longer decide for itself, and it holds its locks.

**run** — one complete history: it goes on for ever, or it stops where the model
stops.

**situation** — one complete arrangement of everything the model can vary. `pol`
builds all of them; the output calls the count `states`.

**move** — a condition and a change. A move whose condition is false in a
situation simply does not exist there.

**dead end** — a situation with no moves left.

**`never F`** — no situation satisfies F. A census over all of them.

**`possible F`** — some situation does, and `pol` prints the route.

**`live F`** — from every situation, an F-situation is *still reachable*.

**`inevitable F`** — from every situation, *every run* reaches F. Strictly
stronger than `live`.

**`(fair MOVE…)`** — narrows which runs a question is about: a run where a named
move is offered for ever and never taken does not count.

**witness** — the numbered route `pol` prints with a verdict. For a failing
property it is the shortest counterexample; for a holding `possible` it is the
answer itself.
