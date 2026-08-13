# Domain libraries

A **domain library** says what *exists*. A model says what may *happen*. These
files hold the first half for the scenarios beside them, which is why those
scenarios are fifteen and twenty lines each.

| | serves | holds |
| --- | --- | --- |
| [`chess.lib.writ`](chess.lib.writ) | `queens/` | squares, rows, diagonals, the `free` test, the empty board |
| [`scheduling.lib.writ`](scheduling.lib.writ) | `jobshop-possible/`, `jobshop-best/` | machines, jobs, routings, the blocking rule, a clock |
| [`arch.lib.writ`](arch.lib.writ) | `arch/` | components and their properties, stages and their demands, the provides/requires spans, the `fits` test, the design cursor |
| [`school.lib.writ`](school.lib.writ) | `timetable/` | the week as a ladder, rooms and their facilities, capacity as a named scale, staff and what they may teach, the curriculum as one entity per hour, a booking, and the two places the curriculum runs out |
| [`economy.lib.writ`](economy.lib.writ) | `calculation/` | plants and their true needs, one scarce allotment, the allocation rule, the irreversible commitment, the `signal-honest` law |

Load one by relative path:

```lisp
(load "../libraries/chess.lib.writ")
```

## What makes a file a library

**Declarations only.** The loader refuses a loaded file containing `(use …)`,
`(initial …)` or a transition. So a library can carry a schema, an instance and
forms — never a model's own choice of what to run.

**It pays the namespace.** Names are global across the loaded universe and may
not be redeclared (kernel §7), so every model loading `chess.lib.writ` gives up
`board`, `square`, `queen`, `free`, `empty` and the entity names. That cost is
exactly why these are **domain** libraries and not additions to
[`core/stdlib/stdlib.writ`](../../../core/stdlib/stdlib.writ): the standard
library may not spend the shared namespace on a worldly concept. It is also the
difference in kind — `stdlib.writ` is shipped and installed; these are not.

**It offers rather than imposes.** `chess.lib.writ` declares a cursor;
`queens.writ` advances one and needs eight moves, `queens-unordered.writ` never
touches it and needs sixty-four. `scheduling.lib.writ` declares a clock;
`jobshop-best` runs it, `jobshop-possible` ignores it. Declining costs the
space nothing — a cell that is never written is the same cell in every
situation, which was measured rather than assumed.

**It is not only for models.** `jobshop-*.claims` and `jobshop-*.rules` load
`scheduling.lib.writ` too, for `all-done`. A model, a question and a derivation
can share one vocabulary without sharing a file — and questions still live in
their own document (wish 12).

## Why they are grouped here, and what that cost

Design D3 searches the **including file's own directory first**, deliberately so
that a library can sit next to the models that load it and be found with no
`WRIT_LIB` and no install step. Taken literally that argues for
`queens/chess.lib.writ` — and it is where this file started.

Grouping them trades a little of that for discoverability: one place to look for
"what vocabulary does this repository define", against loads that must now name
a path rather than a bare file. Both are legitimate. The bare-name form is still
what a *single* model's private library should use, and D3's first rule is what
makes `../libraries/…` resolve at all, so nothing about the search order
changed — only how much of it the load has to spell out.

`WRIT_TRACE_LOADS=1` prints which file each load actually resolved to, which is
how to check rather than assume:

```console
$ WRIT_TRACE_LOADS=1 writ check queens/queens.writ
writ: resolved "../libraries/chess.lib.writ" -> queens/../libraries/chess.lib.writ
writ: resolved "stdlib.writ" -> core/stdlib/stdlib.writ
```

## A third one, deliberately not here

[`tests/models/politics.lib.writ`](../../models/politics.lib.writ) is a domain
library too, and it stays with the unit-test corpus it serves. Moving it would
couple the unit tests to the examples tree for no gain — a library belongs
wherever all of its models can see it, and for that one, that is `tests/models/`.
