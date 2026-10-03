# A blocking job shop — does a schedule exist?

Three jobs share three machines, each visiting two in its own order: `a` goes
m1→m2, `b` m2→m3, `c` m3→m1. The shop is *blocking*: with no buffers, a job
cannot leave a machine until it has taken the next. Can every job finish, and
can the shop seize on the way? [`../jobshop-best/`](../jobshop-best/) asks which
schedule is shortest.

The shop and the blocking rule live in
[`../libraries/scheduling.lib.writ`](../libraries/scheduling.lib.writ);
[`jobshop-possible.writ`](jobshop-possible.writ) adds three move forms
(`enters`, `advances`, `leaves`) and one line per job. There is no clock, so the
space holds orders of events, not durations.

## What writ answers

```
states: 51   edges: 87
…
holds  all-finish
  "every job can finish"
…
fails  never-stuck
  "from every reachable schedule, every job can still finish"
  stuck at: #13 (clk.at=t1 m1.held-by=a m2.held-by=b m3.held-by=c a.stage=on-first b.stage=on-first c.stage=on-first a.moved=no b.moved=no c.moved=no)
  witness:  1. a-enters   → #1   m1.held-by: ∅ → a, a.stage: queued → on-first
            2. b-enters   → #5   m2.held-by: ∅ → b, b.stage: queued → on-first
            3. c-enters   → #13   m3.held-by: ∅ → c, c.stage: queued → on-first
```

`all-finish` (`possible`) holds, with a witness that runs the jobs one after
another. `never-stuck` (`live`) fails: three legal moves put each job on its
first machine, waiting for the one the next job holds, in a cycle. Nothing can
move again. (The untouched clock fields come from the shared library.)

**Take away:** `possible` alone says "yes, the shop can finish" and hides the
trap. `live` asks whether finishing stays possible from everywhere reachable,
and names the deadlock and the moves into it. Time plays no part.

## Run it

```sh
cd jobshop-possible
writ check jobshop-possible.writ --claims jobshop-possible.claims   # exits 1
```

[`jobshop-possible.rules`](jobshop-possible.rules) re-asks both questions of
the rules engine for the cross-check.
