# Auditing a timetable somebody else decided

Every other scenario here hands `pol` a space to walk. This one hands it a
**finished artifact** and asks whether it is any good.

A CP-SAT solver produced the week in [`timetable.pol`](timetable.pol) — three
groups, twenty hours each, five days, six periods, six subjects, six rooms,
eight teachers, sixty lessons. The solver knew the constraints anyone would
think to encode: deliver the programme, nothing in two places at once, the right
kind of room, a big enough room, a qualified teacher who is free. It knew
nothing else, and the whole of what it did not know is
[`timetable.claims`](timetable.claims) — which it never saw.

The pipeline that produced the fixtures lives in a sibling repository,
`pol-scheduling-verification`; the schedules here are **frozen**, so the
verdicts below are exact and cannot change because somebody upgraded a solver.

## What `pol check` answers

```console
$ pol check timetable/timetable.pol --claims timetable/timetable.claims
states: 1   edges: 2
gaps: 2
  window-unstated — "the curriculum is silent: may a group have a free period
                     BETWEEN two lessons, and who supervises it?" (min 0 moves)
  doubling-unstated — "the curriculum is silent: may two hours of one subject
                     fall on the same day?" (min 0 moves)
holds  curriculum-delivered      holds  room-fit
holds  nothing-extra             holds  room-big-enough
holds  hours-not-doubled         holds  teacher-qualified
holds  no-group-clash            holds  teacher-available
holds  no-teacher-clash          holds  no-triple-run
holds  no-room-clash
fails  sport-not-first
fails  time-to-change-after-sport
```

**A. `states: 1`** — and that is the scenario's first contribution. Every arrow
in [`../libraries/school.lib.pol`](../libraries/school.lib.pol) is `fixed`,
because a decided timetable has nothing left to vary. The state set is the
product of the arrows that *can* vary, and that product is empty, so there is
one situation and `pol` spends its whole run evaluating the questions. Checking
is cheap in exactly the place generating is dear: asking `pol` to *produce* a
timetable — moves that place lessons, `possible` for a full week — passes the
200 000-state cap at about fifteen lesson-hours, because the set of hours still
owed is genuinely part of the state.

**B. Ten properties hold, and they were worth asking anyway.** They restate,
independently, what the CP model was told. Agreement between two statements of
the same requirement, written by different people in different languages, is
worth more than either alone — and if one ever fails, the two halves disagree
and one of them is wrong.

**C. Two rules fail, and neither was ever encoded.** No group should start a day
with sport; no group should be sent from sport straight into another lesson.
Both are sentences a teacher would say out loud and nobody thinks to write into
a solver. The timetable is feasible, optimal, and would be rejected by the first
person who read it.

**D. Two gaps, which are the better half of the output.** They are not
violations. The curriculum simply never says whether a group may have a free
period *between* two lessons, or whether two hours of one subject may fall on
the same day — so the solver settled both by accident. `gap` is how a Pol model
says "the rules are silent here" instead of inventing an answer, and **these are
questions to put back to whoever wrote the curriculum**, derived mechanically
rather than noticed by someone squinting at a grid.

## Naming the offenders

A failing property says *that* the timetable is wrong. The queries in the same
file say *which lessons* make it wrong — on this schedule they answer nothing,
because nothing collides, but point the same file at a damaged export:

```console
$ pol query timetable/timetable.pol clashes
clashes  (at state 0)
  a = g-7a-art-thu-p3, b = g-7b-art-thu-p3
```

That is what a `.claims` file is for beyond pass and fail. `missing-hours` names
the demand nobody delivered; `unqualified` names the cover teacher who should
not be in front of that class.

## One question suite, two timetables

[`timetable-strict.pol`](timetable-strict.pol) is the same week solved again
with the findings above encoded in the CP model. The **same claims file** is put
to it — a question suite is a document of its own (§3), and which model it is
asked of is the tool's business:

```console
$ pol check timetable/timetable-strict.pol --claims timetable/timetable.claims
gaps: none
… every property holds …          # exit 0
```

And the difference between the two weeks is a tool operation rather than a
reading exercise:

```console
$ pol compare timetable/timetable.pol timetable/timetable-strict.pol
properties:  curriculum-delivered        preserved
             …
             sport-not-first             gained
             time-to-change-after-sport  gained
```

Nothing was lost to buy them, which is the thing a timetabler actually needs to
know before accepting the tighter model.

## Counting hours with no arithmetic

"Five hours of maths a week" cannot be the numeral 5 — Pol has none. It is five
`demand` entities, told apart by an `ordinal`, and each lesson carries the
ordinal of the hour it fills. Then three properties do the counting between
them:

- `curriculum-delivered` — no demand without a lesson,
- `nothing-extra` — no lesson without a demand,
- `hours-not-doubled` — no two lessons claiming one demand.

Together they make lesson↔demand a **bijection**, which counts the hours exactly
without ever counting. Room capacity is the same move in a different direction:
seat counts become a ladder of classes walked by `bigger`, so "does this group
fit" is a four-step walk rather than a comparison (Appendix G's small named
scales, as in `jobshop-best`'s clock).

## Telling two bound entities apart

Most of these questions are of the form "no two lessons such that…", and that
needs the two binders to be *different* lessons. A `some`-binder may root a
chain but may never sit on the right of `is`, so `(differ a b)` cannot be said
of the binders themselves. Every booking therefore carries a `b-id` arrow into a
type whose only job is identity, and difference is asserted of that:

```lisp
(form (other A B) (differ A.b-id B.b-id))
```

It is `queens/` reading a row through a square rather than computing one — the
same discipline, applied to identity instead of arithmetic.

## What this scenario does not claim

The curriculum, the estate and the staff are a sketch, and the timetable is one
CP-SAT run. What is on offer here is the **arrangement**: a maker and a judge
that share only a statement of requirements, so that the judge's verdict is
evidence rather than a restatement of the maker's own assumptions.
