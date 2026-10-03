# Domain libraries

A domain library says what exists; a model says what may happen. These files
hold the shared vocabulary for the scenarios beside them.

| | serves | holds |
| --- | --- | --- |
| [`chess.lib.writ`](chess.lib.writ) | `queens/` | squares, rows, diagonals, the `free` test, the empty board |
| [`scheduling.lib.writ`](scheduling.lib.writ) | `jobshop-possible/`, `jobshop-best/` | machines, jobs, routings, the blocking rule, a clock |
| [`arch.lib.writ`](arch.lib.writ) | `arch/` | components, stages and their demands, the `fits` test, the design cursor |
| [`school.lib.writ`](school.lib.writ) | `timetable/` | the week, rooms, capacity, staff, the curriculum as one entity per hour, a booking |
| [`economy.lib.writ`](economy.lib.writ) | `calculation/` | plants and their needs, one scarce allotment, the allocation rule, the `signal-honest` law |

A model, claims file or rules file loads one by relative path:
`(load "../libraries/chess.lib.writ")`. A library holds declarations only (a
schema, an instance, forms); the loader refuses one that contains `(use …)`,
`(initial …)` or a transition. Its names are global to every model that loads
it, which is why these live here and not in writ's
[standard library](https://github.com/writ-lang/writ/blob/main/core/stdlib/stdlib.writ).
`WRIT_TRACE_LOADS=1` prints which file each load resolved to.
