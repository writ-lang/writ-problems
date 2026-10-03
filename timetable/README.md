# Auditing a timetable somebody else decided

A [CP-SAT](https://developers.google.com/optimization/cp/cp_solver) solver
built a school week: three groups, sixty lessons, six rooms, eight teachers, no
clashes. Is it any good? This scenario judges that finished timetable against
questions the solver never saw. It is the frozen fixture of
[`writ-scheduling-verification`](https://github.com/writ-lang/writ-scheduling-verification),
which tells the full story with the live solver pipeline.

## The model

[`timetable.writ`](timetable.writ) is the solver's week transcribed onto the
vocabulary in [`../libraries/school.lib.writ`](../libraries/school.lib.writ).
Every arrow is `fixed`, so there is one situation, and the run is spent on
[`timetable.claims`](timetable.claims). Each demanded hour is an entity, and
three properties make lesson↔demand a bijection, counting hours with no
arithmetic.

## What writ answers

```console
$ writ check timetable.writ --claims timetable.claims
states: 1   edges: 2
regime: committing — no move can be undone
gaps: 2
  window-unstated — "the curriculum is silent: may a group have a free period BETWEEN two lessons, and who supervises it?" (min 0 moves)
  doubling-unstated — "the curriculum is silent: may two hours of one subject fall on the same day?" (min 0 moves)
…
fails  sport-not-first
…
fails  time-to-change-after-sport
…
```

Eleven properties hold: the solver's own rules, restated independently. Two
fail: rules a teacher would say aloud and nobody gave the solver. The two gaps
are questions the curriculum never answered, to put back to whoever wrote it.
[`timetable-strict.writ`](timetable-strict.writ), the week re-solved with those
rules, passes the same claims file, and `writ compare` shows both properties
`gained` with nothing lost.

The takeaway: maker and judge share only the requirements, so the judge's
verdict is evidence rather than an echo of the maker's assumptions.

## Run it

```sh
writ check   timetable.writ        --claims timetable.claims
writ check   timetable-strict.writ --claims timetable.claims
writ compare timetable.writ timetable-strict.writ
```
