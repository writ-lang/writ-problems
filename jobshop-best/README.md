# The same job shop — which schedule is shortest?

The shop from [`../jobshop-possible/`](../jobshop-possible/), asking for the
shortest schedule. writ has no arithmetic, so time is a ladder of ticks
`t1 → t2 → …` ([`scheduling.lib.writ`](../libraries/scheduling.lib.writ)). A job
acts once per tick; the `tick` move advances the clock and resets the turns.
"Done by tick N" is then an ordinary `possible`:

```lisp
(property done-by-5 "every job finished by tick 5 — the optimum"
  (possible (and (all-done j) (is clk.at t5))))
```

## What writ answers

```
states: 1314   edges: 2411
…
fails  done-by-4
  "every job finished by tick 4 — the bound that is too tight"
holds  done-by-5
  "every job finished by tick 5 — the optimum"
  witness:  1. a-enters     → #1   m1.held-by: ∅ → a, a.stage: queued → on-first, a.moved: no → yes
            2. b-enters     → #5   m2.held-by: ∅ → b, b.stage: queued → on-first, b.moved: no → yes
            3. tick         → #16   clk.at: t1 → t2, a.moved: yes → no, b.moved: yes → no
…
```

`done-by-4` fails and `done-by-5` holds, so five ticks is optimal, and the
witness is an optimal schedule. It runs `a` and `b` together and holds `c` back,
because the only state with all three machines busy is the deadlock.

**Take away:** optimise by repeated feasibility: the smallest N that holds is the
optimum, proved by one fail and one hold. The clock costs 51 → 1314 situations.

## Run it

```sh
cd jobshop-best && writ check jobshop-best.writ --claims jobshop-best.claims   # exits 1
```
