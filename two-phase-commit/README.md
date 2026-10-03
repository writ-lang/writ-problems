# Two-phase commit: agreeing when either side can vanish

Two ledgers must change together: money must not leave one without arriving at
the other. They share no instant in which to act, only messages, and any
machine can crash. Two-phase commit is the standard answer: a coordinator asks
each participant to vote, decides **commit** only if all vote yes, then tells
each one. Does it keep the parties in agreement, and must they always reach a
decision?

## The model

[`two-phase-commit.writ`](two-phase-commit.writ) has a coordinator `c` and two
participants. A message in flight is a `maybe` slot, so "decided but not yet
told" is an empty `inbox` that writ can find and print:

```lisp
(type participant
  (arrow state (to pstate))         ; working, prepared, committed, aborted
  (maybe vote  vote-t)              ; in flight to the coordinator
  (maybe inbox dec-t))              ; in flight to this participant
```

A participant that votes yes is `prepared`: it has promised, and can no longer
decide alone. A crash is just another move, enabled everywhere the coordinator
is alive, so it lands at every point in the protocol without anyone listing the
cases:

```lisp
(transition c-crash
  (when (not (is c.state crashed)))
  (do (set c.state crashed)))
```

Two variants change one thing each:

| file | change |
| --- | --- |
| [`two-phase-commit-lossy.writ`](two-phase-commit-lossy.writ) | no crash; the network can drop a delivered decision (`lose-p1`, `lose-p2`), and it is sent again |
| [`two-phase-commit-timeout.writ`](two-phase-commit-timeout.writ) | the crashing model, plus `p1-timeout`/`p2-timeout`: a prepared participant aborts if the coordinator is down and nothing has arrived |

[`two-phase-commit.claims`](two-phase-commit.claims) asks all three the same
five questions, one per modality, with `inevitable` asked twice:

| property | modality | plain | lossy | timeout |
| --- | --- | --- | --- | --- |
| `atomic` — never one committed while another aborted | `never` | holds | holds | **fails** |
| `can-commit` — all can commit | `possible` | holds | holds | holds |
| `can-decide` — from anywhere, deciding is still reachable | `live` | **fails** | holds | holds |
| `must-decide` — every run decides | `inevitable` | **fails** | **fails** | holds |
| `must-decide-if-applied` — the same, if a told participant eventually acts | `inevitable` + `fair` | **fails** | holds | holds |

## What writ answers

**The plain protocol is safe but can hang.**

```
states: 84   edges: 152
…
dead ends: 20
…
holds  atomic
  "no participant commits while another aborts"
holds  can-commit
…
fails  can-decide
  "from anywhere, every participant can still decide"
  stuck at: #8 (p1.state=prepared p2.state=working p1.vote=yes p2.vote=∅ p1.inbox=∅ p2.inbox=∅ c.state=crashed c.decision=∅)
  witness:  1. p1-yes    → #1   p1.state: working → prepared, p1.vote: ∅ → yes
            2. c-crash   → #8   c.state: collecting → crashed
```

`atomic` is a `never`, so it holding is a census of all 84 situations, not a
search that came up empty. `can-decide` fails in two moves: `p1` prepares, the
coordinator dies before deciding, and `p1` holds its locks for ever. It cannot
commit (the decision might have been abort) or abort (it might have been
commit). All 20 dead ends are reached by `c-crash`.

**The lossy protocol can always decide, but need not.**

```
states: 42   edges: 82
regime: reversible — 16 of 42 situations lie on cycles
…
holds  can-decide
  "from anywhere, every participant can still decide"
fails  must-decide
  "no run avoids deciding"
  stuck at: #11 (p1.state=prepared p2.state=prepared p1.vote=yes p2.vote=yes p1.inbox=∅ p2.inbox=∅ c.state=decided c.decision=commit)
…
holds  must-decide-if-applied
  "…and no run avoids it, if a participant told the decision eventually applies it"
  assuming fair: p1-commit, p1-abort, p2-commit, p2-abort
```

The coordinator never dies, so a decision is always one send away: `live`
holds. But the run that loses every send for ever is a run, and in it nobody
decides: `inevitable` fails. Adding `(fair p1-commit p1-abort p2-commit
p2-abort)` drops runs that offer a participant its decision for ever and never
let it act, and then the property holds. The assumption sits in the claims
file, not the model, and the verdict prints it. On the crashing model the fair
version still fails: a run that stops has nothing being starved.

**The timeout cures the hang and breaks atomicity.**

```
equations:
properties:  atomic                  LOST      witness: 1. p1-yes 2. p2-yes 3. c-commit 4. deliver-p1 5. p1-commit 6. c-crash 7. p2-timeout
             can-commit              preserved
             can-decide              gained
             must-decide             gained
             must-decide-if-applied  gained
```

Every liveness property is gained, and `atomic` is lost. The coordinator
decides commit, tells `p1`, which commits, then crashes before telling `p2`,
which times out and aborts. Two locally reasonable acts; the money left and
never arrived.

## What to take away

`live` and `inevitable` are different questions. "Can it still finish?" holds on
the lossy protocol; "must it finish?" fails there, and only a stated fairness
assumption recovers it. And the classic trade-off of two-phase commit, safety
against progress under a crash, comes out of `writ compare` as one table and
the exact run that costs the guarantee.

## Run it

```sh
cd two-phase-commit
writ check two-phase-commit.writ         --claims two-phase-commit.claims   # exits 1
writ check two-phase-commit-lossy.writ   --claims two-phase-commit.claims   # exits 1
writ check two-phase-commit-timeout.writ --claims two-phase-commit.claims   # exits 1
writ compare two-phase-commit.writ two-phase-commit-timeout.writ
```

[`two-phase-commit.rules`](two-phase-commit.rules) re-asks four of the five
properties through the rules engine for `modality-cross-check.sh`. It skips
`must-decide-if-applied`, and says so, because the rules encoding does not
model fairness. See the [writ tour](https://github.com/writ-lang/writ/blob/main/docs/tour.md)
for the modalities.
