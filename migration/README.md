# Expand / contract, gated

*Renaming a column under a live service, as a state machine — and `pol check`
as the thing that refuses the merge.*

## The problem

A rename cannot be one step. The database and the code deploy separately, and a
rolling deploy runs **two releases at once**. So `name` → `full_name` becomes a
sequence — add the column, teach the code to write both, backfill, switch the
readers, stop writing the old one, drop it — and the question is whether the
sequence is safe at *every instant*, including the instants when two releases
are serving traffic together.

That is a question about a state space rather than about a diff, which is why
it is worth exhausting. A reviewer checks the steps. `pol` checks every
situation the steps can produce, including the interleavings nobody wrote down.

## What is a move, and what is a law

The **moves** are the operator's — the DDL and the deploys — and their guards
*are* the runbook: each guard is a precondition the plan claims to have
checked.

The **laws** are the compatibility rules, and they are deliberately not guards.
A law is a claim the world is measured against rather than a filter on it, so
`pol check` reports not merely that a rule is violated but **which move can
break it**. That is the gate's output, and it is more than a boolean.

| law | what it forbids |
| --- | --- |
| `read-of-existing` | reading a column that is not there |
| `write-of-existing` | writing a column that is not there |
| `read-of-filled` | reading a column whose backfill has not finished |
| `read-implies-every-writer` | a column read by one live release and not written by the other |

The last one is the one humans get wrong. Mid-rollout the old release is still
serving writes; if it does not write the column the new release reads, the new
one reads nothing for the rows the old one just wrote. The window is only as
long as a deploy, which is exactly why it survives review and fails in
production.

## What `pol` answers

### The plan — `migration.pol`

```console
$ pol check migration.pol --claims migration.claims
states: 10   edges: 9
holds  completes
  witness:  1. add-column   2. deploy-r2   3. settle   4. backfill
            5. deploy-r3    6. settle      7. deploy-r4   8. settle
            9. drop-column
holds  no-dead-ends
$ echo $?
0
```

- **`holds completes`** — the rename can be finished, **and the witness is the
  runbook**. Nobody wrote those nine steps in that order; `pol` found them, and
  prints them as the evidence for its own answer.
- **`holds no-dead-ends`** — from *every* reachable situation the rename can
  still be finished. No step strands production half-migrated. This is the
  river's `no-blunders` asked of a deploy.
- **Exit 0.** The gate passes.

Four laws, and every one of them is listed as breakable by almost every step —
`settle` and each `deploy-*` write the fleet arrows all four rules range over.
The claims file acknowledges each pair explicitly, and **the length of that
list is the argument for the whole exercise**: nearly every step of a migration
can in principle break nearly every compatibility rule, which is why a runbook
is reviewed badly and exhausted well.

### The shortcut — `migration-shortcut.pol`

The same file with **one conjunct removed**: `(is full-col.filled yes)` struck
from `deploy-r3`'s guard, so the release that starts *reading* the new column
goes out before the backfill has finished. It is the tempting version, because
at that moment the column exists, every live release writes it, and a staging
database — whose rows were all written after the column arrived — looks fine.

The questions are the ones next door, unchanged. Holding them fixed is the
point of the pair: the difference in the verdicts is attributable to that one
conjunct and to nothing else.

```console
$ pol check migration-shortcut.pol --claims migration.claims
equation read-of-filled
  violated in 5 reachable situations
  witness: 1. add-column  2. deploy-r2  3. settle  4. deploy-r3
holds  completes
$ echo $?
1
```

**Exit 1 — the gate refuses the merge**, and names the step: four moves in,
`deploy-r3` puts a reader in front of an unfilled column, and five reachable
situations are broken.

Note what *else* it says. `holds completes` — the shortcut still finishes, in
**eight** steps rather than nine. It is genuinely faster. That is why it is
tempting, and why "it worked in staging" is not evidence.

### And one instrument that does not catch it

```console
$ pol compare migration.pol migration-shortcut.pol
equations:   read-of-filled  preserved
properties:  completes       preserved
             no-dead-ends    preserved
$ echo $?
0
```

`pol compare` reports **everything preserved, exit 0** — correctly. The
shortcut declares the same four laws and satisfies the same two properties.
What it loses is that one of its declared laws is now *violated in reachable
situations*, and `compare` does not look at that. Comparison answers "which
guarantees did this version drop"; the gate here has to be `check`, which
answers "does this version keep the ones it declares".

Worth knowing before someone wires the wrong verb into CI.

## The files

| | |
| --- | --- |
| `migration.pol` | the plan — schema, releases, runbook, four laws |
| `migration-shortcut.pol` | the same, one conjunct lighter |
| `migration.claims` | the questions and the ownership, put to both |
| `migration.lib.pol` | vocabulary shared by model and claims |
| `migration.rules` | the same two properties as derivations, for the cross-check |

## Two things the model is careful about

**The read/write sets are a relation, not an arrow.** A release reads and
writes *several* columns, so `reads` and `writes` are junction types, and
asking "does this release write that column" is an existential over one. They
are `fixed`: a release's behaviour is wiring, not state — r2 writes what r2
writes, in every situation.

**A law ranges over one type.** Each of the four is rooted at `fleet` and
reaches the read/write sets through `some`, because a law has exactly one free
root and its chains are written from the type rather than from an entity. That
constraint is why the rules are phrased as "there is no live release such
that…" rather than as a quantification over pairs.
