# An on-call rota: does one exist, and what did the policy not say?

A team of four covers six weeks of on-call. The policy:

- every week has a primary;
- nobody is primary two weeks in a row;
- nobody is primary more than two weeks in the six;
- nobody is primary in a week they are on leave (Bob is away in week 3, Cat
  in week 4);
- Dan joined last month, and may not be primary until his second month
  (weeks 5 and 6).

The question is not which rota is best, but whether any rota satisfies the
policy, and if so, what one looks like. writ answers by building rotas
week by week, and the witness it prints *is* a rota.

## The model

[`on-call-rota.writ`](on-call-rota.writ) has six **weeks** on a ladder
(`w1` … `w6`, then `done`), each with a `primary` slot. A **cursor** walks
the ladder, so weeks are filled in order and every situation is a partial
rota. There is one move per person and week: `ann-takes-w1`, `bob-takes-w4`,
and so on. Each one checks the policy in its guard and moves the cursor on.

"At most two weeks" is counting, and the model does no arithmetic. Each
person carries a `load` on a three-step scale, `l0 → l1 → l2`, and the top
step has no `up`. Taking a week moves the load one step up, so a third week
isn't refused by a guard. It's absent: there is no step to move to.

## What writ answers

The questions are in [`on-call-rota.claims`](on-call-rota.claims):

```
states: 27   edges: 30
regime: committing — no move can be undone
gaps: 2
  bob-takes-w2 — "the policy does not say whether a primary may hand over straight into their own leave" (min 1 moves)
  cat-takes-w3 — "the policy does not say whether a primary may hand over straight into their own leave" (min 2 moves)
dead ends: 10
…
holds  rota-exists
  "six weeks can be covered under the policy"
  witness:  1. ann-takes-w1   …
            2. cat-takes-w2   …
            3. ann-takes-w3   …
            4. bob-takes-w4   …
            5. cat-takes-w5   …
            6. bob-takes-w6   …
fails  no-dead-end-prefix
  "from every partial rota, a complete one can still be reached"
  stuck at: #3 (w1.primary=cat …)
  witness:  1. cat-takes-w1
```

The witness, as a rota:

| week | 1 | 2 | 3 | 4 | 5 | 6 |
| --- | --- | --- | --- | --- | --- | --- |
| primary | Ann | Cat | Ann | Bob | Cat | Bob |

There are ten in all. Each complete rota is a dead end of six moves (there is
nothing left to fill), and the ten dead ends are the ten rotas.
[`on-call-rota.rules`](on-call-rota.rules) reads them all out as rows:

```sh
writ derive on-call-rota.writ on-call-rota.rules rota
```

```
rota  (60 rows)
  17  w1  ann
  17  w2  cat
  …
```

Ten rotas, six rows each.

**The planner's trap:** give Cat week 1 and no rota can be finished.
`no-dead-end-prefix` fails at that first step. Week 2 then has to be Ann:
Bob's week 2 is a gap (below), and Dan is too new. Week 3 has nobody: Ann
just did week 2, Bob is away, Cat's week 3 is a gap, and Dan is still too
new. A planner filling the calendar from the top finds out two weeks later,
at the one question the policy never answered.

## The question the policy never answers

Bob is away in week 3. May he be primary in week 2 and hand over straight
into his leave, with nobody back the next week to answer for what happened
on his watch? Cat has the same question for week 3. The policy does not
say. In the model, those two assignments are not moves but **gaps**:

```lisp
(do (gap "the policy does not say whether a primary may hand over straight into their own leave"))
```

writ lists each gap with the shortest route to it. That is the question to
put back to whoever owns the policy, the way `../timetable/` puts back what a
curriculum never said. Ten rotas exist without those two assignments, so the
policy as written does not need an answer. The trap above does: it is a dead
end only because the one way out is a gap.

## One more rule

[`on-call-rota-strict.writ`](on-call-rota-strict.writ) adds a rule teams
add after someone comes back from holiday straight into an incident: **nobody
is primary in the week they come back from leave**.

```
fails  rota-exists
  "six weeks can be covered under the policy"
…
dead ends: 2
  reached by: ann-takes-w1, cat-takes-w2, ann-takes-w3
  reached by: bob-takes-w1, cat-takes-w2, ann-takes-w3
```

No rota exists, and every attempt stops after week 3. The reason can be read
backwards from week 4:

- in **week 4**, Cat is away, Bob has just come back, and Dan is too new, so
  it has to be Ann;
- so **week 3** cannot be Ann, Bob is away, and Dan is still too new, so it
  has to be Cat;
- and Cat in week 3 is the week before her leave, which is one of the gaps.

So under the stricter policy, a rota exists **only if** the question nobody
answered is answered yes. The gap went from a loose end to the deciding
question. `writ compare` reports it as a lost guarantee with no witness:

```
properties:  rota-exists  LOST
```

A failed `possible` has no route to print. The absence is the answer, and the
dead ends show how far the policy gets.

## What to take away

Staffing rules are each reasonable, and a rota usually exists, until one more
rule meets the calendar's particular leave. Asking "does one exist" each time
the policy changes is cheap. Here it also turned up the question the policy
should have answered first.

To adapt it, add people with their leave and start dates, and weeks as rungs
of the ladder. Each rule is a conjunct in the `assign` form's guard.

## Run it

```sh
writ check on-call-rota.writ --claims on-call-rota.claims          # exit 1: the planner's trap
writ check on-call-rota-strict.writ --claims on-call-rota.claims   # exit 1: no rota
writ derive on-call-rota.writ on-call-rota.rules rota
```

`../modality-cross-check.sh` checks the `.rules` encoding against `writ check`.
