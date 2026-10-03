# A rolling deploy, and the rollback that is not always there

Three instances serve production on release r1 against schema v1. The
release is r2, and r2 comes with a migration to v2 that drops a column r1
reads. The runbook:

```
target r2 ──▶ replace a ──▶ a healthy ──▶ replace b ──▶ b healthy ──▶ replace c ──▶ c healthy ──▶ migrate
                                                                                                    │
rollback: target r1, then replace back                                     (no way back from here) ◀┘
```

Each instance is replaced only while the other two are serving (the **health
gate**). The migration runs when every instance is on r2 and serving. And the
runbook has a rollback section: point the fleet back at r1 and replace the
instances again.

The rollback section is true until the migration runs. After that it
describes a step that cannot happen: r1 cannot read v2, and nothing turns v2
back into v1. A rollback is a claim about the reachable states, not a button,
and here the claim stops being true one lawful step into the runbook.

## The model

[`deployment.writ`](deployment.writ) has three instances (`a`, `b`, `c`),
each with a release (`at`) and a state (`starting`, `healthy`, `down`); the
fleet's `target`; and the database's schema `at` (`v1`, `v2`).

- `target-r2` starts the release. `roll-back-target` points back at r1, but
  only while the schema is still v1.
- `replace-a-with-r2` and the rest take an instance out and start it on the
  target release. The safe guard is the health gate: the other two instances
  are `healthy`.
- `a-passes-health` and the rest: a starting instance becomes healthy only if
  its release can read the schema (`compatible` in
  [`deployment.lib.writ`](deployment.lib.writ)). An r1 instance started on v2
  crash-loops for ever.
- `a-crashes` and `a-restarts`: the environment. **One instance fails at a
  time.** A crash is only possible while the other two are serving. Without
  that fault model, three independent crashes darken production under any
  rollout, and the question would be about hardware, not the runbook.
- `migrate`: v1 → v2, once the rollout has finished. There is no inverse.

One law, `no-mismatch`: no r1 instance is serving once the schema is v2.

[`deployment-shortcut.writ`](deployment-shortcut.writ) removes the health gate
from the replacements: a surge, "to make the deploy faster".

## What writ answers

The questions are in [`deployment.claims`](deployment.claims). The safe plan,
exit 1:

```
states: 116   edges: 335
…
holds  upgrades
  "the release can finish: every instance on r2, serving, and the schema migrated"
holds  never-dark
  "production is never dark"
fails  can-roll-back
  "from every situation, the fleet can still get back to r1, serving"
  stuck at: #101 (a.at=r2 b.at=r2 c.at=r2 a.state=healthy b.state=healthy c.state=healthy prod.target=r2 db.at=v2)
  witness:  1. target-r2           → #1   prod.target: r1 → r2
            2. replace-a-with-r2   → #5   a.at: r1 → r2, a.state: healthy → starting
            3. a-passes-health     → #12   a.state: starting → healthy
            4. replace-b-with-r2   → #19   b.at: r1 → r2, b.state: healthy → starting
            5. b-passes-health     → #43   b.state: starting → healthy
            6. replace-c-with-r2   → #61   c.at: r1 → r2, c.state: healthy → starting
            7. c-passes-health     → #85   c.state: starting → healthy
            8. migrate             → #101   db.at: v1 → v2
```

The witness is the runbook, done correctly, eight steps. The situation it
ends in is the one everyone wants, a finished release. From there, r1 can
never be reached again. The safe plan exits 1 for this, and that is the
point: the rollout is safe, but the rollback section of the runbook isn't
always true.

This is not the pair's difference. Both plans fail `can-roll-back` the same
way. It is a property of having an irreversible migration at all. What to do
about it is a decision, not a fix: keep r2 for a soak period before
migrating, so the rollback window is explicit, or make the migration
reversible (keep the column, copy instead of drop). Either way, the runbook
should say when its rollback section stops applying.

## Which decisions cannot be taken back

`can-roll-back` names a goal. [`deployment.rules`](deployment.rules) also asks
without one, using `one-way` from ct.rules: which moves leave a situation that
can never be reached again?

```sh
writ derive deployment.writ deployment.rules irreversible
```

```
irreversible  (1 row)
  migrate
```

Only the migration. Every other step, including the release itself, can be
undone, so `migrate` is the one step to put behind a human decision. If a
rollout step appeared here too, the model would have a latch nobody intended.

## The surge

The shortcut, exit 1:

```
fails  never-dark
  "production is never dark"
  witness:  1. target-r2           → #1   prod.target: r1 → r2
            2. replace-a-with-r2   → #5   a.at: r1 → r2, a.state: healthy → starting
            3. replace-b-with-r2   → #12   b.at: r1 → r2, b.state: healthy → starting
            4. replace-c-with-r2   → #29   c.at: r1 → r2, c.state: healthy → starting
```

Three replacements with no health check between them, and nothing is
serving. The shortcut still finishes the release (`holds upgrades`), so a
test that only checks the deploy completes passes it.

## What writ found while this was being written

The first draft of the safe plan let `migrate` run whenever every instance
was on r2 and healthy. writ's `one-way` table named eleven moves instead of
one, and the situations behind them told the story:

1. finish the rollout to r2;
2. decide to roll back: `roll-back-target`, allowed because the schema is
   still v1;
3. `migrate` runs anyway, because its guard looked at the instances and not
   at where the release was heading;
4. the rollback starts r1 on v2, where it never passes a health check, and
   the only move left is to go forward again.

That is a migration job racing a rollback decision, which happens when the
migration is a separate pipeline stage triggered by "all instances on r2".
The fix, in both files, is that `migrate` also requires the target to still
be r2. After the fix, `one-way` names `migrate` alone.

## Run it

```sh
writ check deployment.writ --claims deployment.claims           # exit 1: the rollback
writ check deployment-shortcut.writ --claims deployment.claims  # exit 1: dark, and the rollback
writ derive deployment.writ deployment.rules irreversible
```

`../modality-cross-check.sh` checks the `.rules` encoding against `writ check`.
`../db-migration-problems/` has the column-level version of the same idiom:
two releases live at once against one schema.
