# Eight queens

Place eight queens on a chessboard so that none attacks another. Is it
solvable, and what are the solutions?

## The model

The board is a shared library,
[`../libraries/chess.lib.writ`](../libraries/chess.lib.writ): sixty-four
squares, their rows and diagonals, and a `free` test. Two ideas keep it small.

**Name the diagonals.** Queen `q3` *is* the queen of column 3, so columns cannot
clash. Each square carries fixed arrows to its row and its two diagonals
(entities `d1`…`d15`), so "same diagonal" is a lookup, not arithmetic, and
safety is one quantified form:

```lisp
(form (free B S)
  (all (B queen)
    (and (differ B.at.row S.row) (differ B.at.da S.da) (differ B.at.db S.db))))
```

**Let a cursor say which queen.** [`queens.writ`](queens.writ) is eight moves,
one per row. A cursor `cur` names the next column's queen, and each move places
it and advances the cursor:

```lisp
(form (fill N S)
  (transition N
       (when (and (not (defined cur.q.at)) (free p S)))
       (do (set cur.q.at S) (set cur.q cur.q.next))))

(fill place-1 cur.q.sq1)   ; …through place-8
```

After `q8` the cursor wraps to `q1`, already placed, so a full board has no
move left: it is a dead end.

## What writ answers

```
states: 2057   edges: 2056
regime: committing — no move can be undone
gaps: none
dead ends: 736
  reached by: place-1, place-4, place-6, place-3
…
holds  solvable
  "all eight queens placed, none attacking"
  witness:  1. place-1   → #1   q1.at: ∅ → s11, cur.q: q1 → q2
            2. place-5   → #11   q2.at: ∅ → s25, cur.q: q2 → q3
            3. place-8   → #61   q3.at: ∅ → s38, cur.q: q3 → q4
            4. place-6   → #212   q4.at: ∅ → s46, cur.q: q4 → q5
            5. place-3   → #570   q5.at: ∅ → s53, cur.q: q5 → q6
            6. place-7   → #1129   q6.at: ∅ → s67, cur.q: q6 → q7
            7. place-2   → #1664   q7.at: ∅ → s72, cur.q: q7 → q8
            8. place-4   → #1965   q8.at: ∅ → s84, cur.q: q8 → q1
```

The witness is a solution: queens on rows 1, 5, 8, 6, 3, 7, 2, 4. Of the 736 dead
ends, the 92 reached by eight moves are exactly the 92 solutions; the rest are
partial boards with no safe square in the next column. No query is needed to
list them.

## Order is the optimisation

[`queens-unordered.writ`](queens-unordered.writ) is the same puzzle without the
cursor: any column may be filled at any time, so it needs sixty-four moves.

| | moves | situations | `writ check` |
| --- | --- | --- | --- |
| `queens-unordered.writ` | 64 | 118 969 | ~40 s |
| `queens.writ` | 8 | 2 057 | 0.25 s |

Same legality, same 92 boards. The unordered space holds every safe *subset* of
columns, reached in every order; the ordered one holds every safe *prefix*.

## What to take away

Fixing the order of choices that do not depend on each other shrinks the space
58-fold, and committing to that order is what lets a cursor replace sixty-four
moves with eight. Keep moves that end at "nothing left to do" when that is what
"solved" means: then the dead-end list is the answer.

## Run it

```sh
cd queens
writ check queens.writ --claims queens.claims
writ check queens-unordered.writ --claims queens.claims   # the slow contrast; not in the test suite
```

[`queens.rules`](queens.rules) re-asks the question of the rules engine for the
cross-check.
