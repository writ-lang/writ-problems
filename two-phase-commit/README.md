# Agreeing to commit, when either side can vanish

This directory holds a worked example. It checks the oldest protocol for making
two machines change their minds together — and finds, by exhaustion, both the
guarantee it gives and the one it does not.

You do not need to know anything about `pol`, or about distributed systems, to
read this page. Every term is explained where it appears.

---

## 1. The problem, in plain terms

Money leaves one ledger and arrives in another. The two ledgers are separate
systems: neither can see inside the other, and either can crash at any moment.

What must never happen is obvious. **The money must not leave without
arriving**, and it must not arrive without leaving. Either both sides do the
work or neither does.

That property has a name — **atomicity** — and the difficulty is that there is
no shared instant in which both sides can act. They can only send each other
messages, and a message can be sent to a machine that is no longer there.

## 2. The protocol

**Two-phase commit** is the standard answer, and it is about seventy lines of
idea. One machine is the **coordinator**; the others are **participants**.

**Phase one — ask.** The coordinator asks every participant: *can you commit?*
Each answers yes or no. A participant that answers **yes** has done something
irreversible in the ordinary sense: it has *promised*. It has written enough to
disk that it could commit even after a restart, and it has given up the right to
change its mind. It is now **prepared**, and it holds its locks until somebody
tells it what was decided.

A participant that answers **no** has promised nothing, so it can simply abort.

**Phase two — tell.** If every answer was yes, the coordinator decides
*commit*; if any was no, it decides *abort*. Either way it decides **once**, and
then it tells each participant, one at a time.

That is the whole protocol. The question this directory answers is what it
buys and what it costs.

## 3. How the model is written

A `pol` model is three things: the kinds of thing that exist, one starting
arrangement, and the moves.

**A message is a slot.** The interesting choice is here. A participant has a
`vote` — the message travelling *to* the coordinator — and an `inbox` — the
message travelling *back*. Both are declared `maybe`, which means the slot is
allowed to be **empty**:

```lisp
(type participant
  (arrow state (to pstate))
  (maybe vote  vote-t)              ; in flight to the coordinator
  (maybe inbox dec-t))              ; in flight to this participant
```

An empty slot is not a special value meaning "nothing". It is the *absence* of
an answer, and `pol` can be asked about it directly. That is what lets "the
decision has been taken but has not arrived" be a situation the tool can find
and print, rather than something the model has to encode as a fake value.

**A move is a condition and a change.** Voting yes and preparing are the same
move, because in the protocol they are the same act:

```lisp
(transition YES
  (when (is P.state working))
  (do (set P.state prepared) (set P.vote yes)))
```

**A crash is just another move.** Nothing in `pol` distinguishes a failure from
an intention; both are things that can happen.

```lisp
(transition c-crash
  (when (not (is c.state crashed)))
  (do (set c.state crashed)))
```

Because the guard is only "not already crashed", this move exists in *every*
situation the coordinator is alive in — including after it has decided, and
including after it has told one participant and not the other. There is no need
to enumerate those cases. The tool does it.

From that page of rules, `pol` builds **84 situations** and every move between
them, and answers by looking at all of them.

## 4. What holds: the parties never disagree

```console
$ pol check two-phase-commit.pol --claims two-phase-commit.claims
states: 84   edges: 152
holds  atomic
holds  can-commit
  witness:  1. p1-yes  2. p2-yes  3. c-commit
            4. deliver-p1  5. p1-commit  6. deliver-p2  7. p2-commit
```

`atomic` is written as a **`never`**:

```lisp
(property atomic "no participant commits while another aborts"
  (never (and (some (p participant) (is p.state committed))
              (some (q participant) (is q.state aborted)))))
```

A holding `never` is worth more than it looks. It is not "we tested this and it
did not happen" — it is a **census**. All 84 situations were built and none of
them has one participant committed and another aborted. Under these rules, that
cannot occur.

`can-commit` matters too, for a duller reason: a protocol that never commits
anything would also satisfy `atomic`. The witness route is the proof that the
happy path exists, and `pol` prints it.

## 5. What fails: somebody can be left waiting

```console
fails  can-decide
  stuck at: (p1.state=prepared p2.state=working … c.state=crashed …)
  witness:  1. p1-yes
            2. c-crash
```

`can-decide` asks whether every participant can **still** reach a decision, from
every situation the model can get into. Two moves refute it. `p1` votes yes —
and is now prepared, holding its locks, no longer entitled to decide for itself
— and the coordinator dies before deciding anything.

Nobody is left who knows what should happen. `p1` cannot commit, because the
decision might have been abort. It cannot abort, because the decision might have
been commit. It waits, holding its locks, for ever.

This is the famous criticism of two-phase commit, and it is worth noticing that
the tool did not know it. It found the shortest route into it and printed it.

## 6. Two ways of asking "does it finish"

There are two questions here that sound like one, and the difference is the
reason this scenario exists.

- **`live F`** — from every situation, is F *still reachable*? Can it still
  finish?
- **`inevitable F`** — from every situation, does every **run** reach F? Must
  it finish?

A run is maximal: it goes on for ever, or it stops where the model stops. So a
run can avoid the goal in two ways — by stopping short of it, or by going round
for ever without taking it.

Above, both fail, and in that order: `inevitable` is the stronger of the two, so
nothing passes it and fails `live`.

Where they come apart is `two-phase-commit-lossy.pol`, and it has **no crash at
all**. The coordinator is alive throughout. The only new move is the network
losing a message — after which the coordinator simply sends it again, which is
what a real implementation does:

```console
$ pol check two-phase-commit-lossy.pol --claims two-phase-commit.claims
holds  can-decide
fails  must-decide
  stuck at: (p1.state=prepared p2.state=prepared … c.state=decided c.decision=commit)
```

Deciding is *always still available* — the message can always be sent again — so
`can-decide` holds. And there is a run in which it is lost every single time, so
`must-decide` fails, naming the situation the run circles in: both participants
prepared, the decision taken, both inboxes empty.

**`live` alone would have reported this protocol as fine.** That is the gap
`inevitable` exists to close.

## 7. Asking about the runs that actually happen

The run that loses every message for ever is real, but it is not what anybody
means by "does this terminate". So the question can say which runs it is about:

```lisp
(property must-decide-if-applied
  "…and no run avoids it, if a participant told the decision eventually applies it"
  (inevitable
    (all (p participant) (or (is p.state committed) (is p.state aborted)))
    (fair p1-commit p1-abort p2-commit p2-abort)))
```

`(fair …)` names moves and says: a run in which one of these is available again
and again, for ever, and never taken is not a run this question is about. On the
lossy model that property **holds**.

Three things about where it is written.

**It is in the claims file, not the model.** *Does this terminate whatever the
network does* and *does it terminate if a participant that has been told the
answer eventually acts on it* are two questions about one protocol. Both are
asked here, of the same file. A model that carried the assumption could only be
asked one of them.

**The verdict prints it.**

```
holds  must-decide-if-applied
  assuming fair: p1-commit, p1-abort, p2-commit, p2-abort
```

"This protocol always terminates" and "…unless a participant refuses to act for
ever" are different claims, and only one of them was checked.

**It does not rescue a deadlock, and should not.** On the crashing model above,
`must-decide-if-applied` still fails. Fairness is about runs that go on for
ever; a run that *stops* is finite, and nothing is being starved in it. No
assumption about scheduling fixes a protocol that has come to a halt.

## 8. The cure, and its price

The blocking in §5 is intolerable in practice — locks held for ever. The obvious
remedy is to let a stranded participant give up: if the coordinator is visibly
gone and nothing has arrived, abort. That is `two-phase-commit-timeout.pol`.

`pol compare` says what it costs:

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

Every liveness property is gained. **Atomicity is lost**, and the seven-move run
that breaks it is printed: the coordinator decides commit, tells `p1`, `p1`
commits — and *then* the coordinator dies before reaching `p2`, which times out
and aborts. One participant committed, the other aborted. The exact thing the
protocol exists to prevent.

This is not a bug in the cure. It is the trade, and it is a real one — the
theorem that no protocol of this shape can have both is a result about the
world, not about this model. What `pol compare` adds is that the trade is
**stated rather than argued**: two files, one table, and the run that costs you
the guarantee.

## 9. Files

| | |
| --- | --- |
| `two-phase-commit.pol` | the protocol, with a coordinator that can crash |
| `two-phase-commit-lossy.pol` | no crash; the network drops messages and they are resent |
| `two-phase-commit-timeout.pol` | the crashing model plus a participant that gives up |
| `two-phase-commit.claims` | the questions, asked of all three |
| `two-phase-commit.rules` | the same questions as derivations, for the cross-check |

The `.rules` file re-asks four of the five properties through the rules engine,
which computes them a completely different way — a closure over the situations
where the goal fails, rather than a partition of them. `modality-cross-check.sh`
runs both and compares. The fifth is skipped and says so: it carries a `(fair …)`
clause, and the rules encoding does not model fairness, so deriving it would
answer a different question and report the disagreement as a bug.

## 10. What this scenario is not

`pol` has no numbers, no unbounded collections and no clocks, and this model
shows the shape of what that rules out. There are **two** participants because
they are named, not because two is enough — three is another two lines. A
message is one slot, so a channel here cannot hold two messages at once, and
cannot reorder them. Adding a participant multiplies the situations.

So this is a tool for a protocol small enough to name every part of, asked
questions whose answers are "in every case" or "in none". A protocol with
retries *and* reordering, or one whose correctness depends on timeouts being
longer than round trips, is a question for a different instrument. Two-phase
commit fits because everything that matters about it fits in eighty-four
situations — which is also why its flaw is two moves deep and has been known for
forty years.

## Glossary

**atomicity** — every party does the work or none does; never some of each.

**coordinator / participant** — the machine that decides, and the machines that
do the work and are told.

**prepared** — a participant that has voted yes: it has promised to commit if
told to, so it may no longer decide for itself, and it holds its locks.

**situation** — one complete arrangement of everything the model can vary.
`pol` builds all of them.

**move** — a condition and a change. A move whose condition is false in a
situation simply does not exist there.

**`never F`** — no situation satisfies F. A census over all of them.

**`possible F`** — some situation does, and `pol` prints the route.

**`live F`** — from every situation, an F-situation is *still reachable*.

**`inevitable F`** — from every situation, *every run* reaches F.

**`(fair MOVE…)`** — narrows which runs a question is about: one where a named
move is offered for ever and never taken does not count.

**witness** — the numbered route `pol` prints with a verdict. For a failing
property it is the shortest counterexample; for a holding `possible` it is the
answer itself.
