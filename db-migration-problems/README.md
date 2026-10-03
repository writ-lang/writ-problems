# Database migration problems

Three schema changes that look routine, each with a plan that reads correctly
and goes wrong anyway, mid-rollout. Each directory writes the expand/contract
plan down as a writ model and checks it at every instant, including while two
releases serve traffic at once. The safe plan passes. A "shortcut" with one
condition removed fails, and writ names the broken rule and the shortest route
to it.

| problem | the mistake | route to the fault |
| --- | --- | --- |
| [`drop-a-column/`](drop-a-column/) | dropping a column while a release that reads it is still live | 2 moves |
| [`add-a-required-column/`](add-a-required-column/) | adding `NOT NULL` before every live release writes the column | 3 moves |
| [`rename-a-column/`](rename-a-column/) | switching readers to the new column before the backfill finishes | 4 moves |

Start with `drop-a-column/`, the smallest. Each directory holds the SQL for
each step (with one representative row), the safe plan, the shortcut, one
`.claims` file asked of both, and a `.rules` file that answers the same
questions through `writ derive` as a cross-check (`../modality-cross-check.sh`).

What the three share: the shortcut is always shorter, because the removed
condition is always a wait. It still completes and never gets stuck, so every
question except "is it safe on the way" answers in its favour. And in most of
them every SQL file is correct on its own; the mistake is in the order, which
no single file records.

From any of the directories (here, `drop-a-column/`):

```sh
writ check drop-a-column.writ --claims drop-a-column.claims           # exit 0
writ check drop-a-column-shortcut.writ --claims drop-a-column.claims  # exit 1
```

To adapt one to your own migration, change the columns, what each release reads
and writes (taken from the code, not the plan), and the steps' `when`
conditions. The rules are about columns and releases in general and usually
carry over unchanged.
