# Database migration problems

Six schema changes that look routine, each with a plan that reads correctly
and goes wrong anyway, mid-rollout. Each directory writes the expand/contract
plan down as a writ model and checks it at every instant, including while two
releases serve traffic at once. The safe plan passes. A "shortcut" with one
condition removed or weakened fails, and writ names the broken rule and the
shortest route to it.

| problem | the mistake | route to the fault |
| --- | --- | --- |
| [`drop-a-column/`](drop-a-column/) | dropping a column while a release that reads it is still live | 2 moves |
| [`add-a-foreign-key/`](add-a-foreign-key/) | adding the key `NOT VALID` while the old code still makes orphans | 2 moves |
| [`add-a-required-column/`](add-a-required-column/) | adding `NOT NULL` before every live release writes the column | 3 moves |
| [`change-an-enum/`](change-an-enum/) | writing the new value while a release that cannot read it is live | 3 moves |
| [`rename-a-column/`](rename-a-column/) | switching readers to the new column before the backfill finishes | 4 moves |
| [`split-a-table/`](split-a-table/) | switching reads to the new table once the backfill has *started* | 5 moves |

Start with `drop-a-column/`, the smallest. Each directory holds the SQL for
each step (with one representative row), the safe plan, the shortcut, one
`.claims` file asked of both, and a `.rules` file that answers the same
questions through `writ derive` as a cross-check (`../modality-cross-check.sh`).

What all six share:

- **The mistake is in the order, not in a file.** Every SQL file is a valid
  schema, and in most of them every statement is right. The defect is a step
  allowed to start before another has finished, which no single file records.
- **The shortcut still completes and never gets stuck**, so every question
  except "is it safe on the way" answers in its favour.
- **It is never slower.** The removed condition is always a wait. Measured as
  the shortest route to a finished migration, the shortcut is shorter in two
  of the six (`add-a-required-column`, 3 moves against 5; `rename-a-column`,
  8 against 9) and the same length in the other four. There it does not skip
  a step: it allows the steps in an order the safe plan forbids.
- **Both gates catch it.** The shortcut breaks a rule rather than dropping
  one. `check` reports the violation, and `writ compare` against the safe
  plan reports that rule `LOST` with the same route, since a rule declared in
  both but broken in one is a guarantee lost. (Before writ counted that, compare
  read "preserved" here, and these READMEs said to gate on `check`.)

From any of the directories (here, `drop-a-column/`):

```sh
writ check drop-a-column.writ --claims drop-a-column.claims           # exit 0
writ check drop-a-column-shortcut.writ --claims drop-a-column.claims  # exit 1
```

To adapt one to your own migration, change the columns, what each release reads
and writes (taken from the code, not the plan), and the steps' `when`
conditions. The rules are about columns and releases in general and usually
carry over unchanged.

What `writ sql` does with the newer steps is recorded where it matters:
`CHECK … IN` becomes an enumerated type (`change-an-enum/`), `REFERENCES`
becomes an arrow (`split-a-table/`), and `NOT VALID` and `VALIDATE CONSTRAINT`
are both declined, each saying why (`add-a-foreign-key/`). A constraint's
validation state is not part of a schema, so the models carry it themselves.
