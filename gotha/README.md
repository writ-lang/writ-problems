# A claim about common ownership, and its falsifier

A claim is testable when it forbids something. "Where exploitation persists,
communism has not been achieved" forbids nothing. Stated so that it can be
wrong, the doctrine reads:

> Once the means of production are held in common, no surplus goes to a party
> outside the work, by the decision of a party outside the work.

## The model

One mill. Ownership is split into four arrows: `title`, `worked-by` (fixed),
`directed-by` (whose decision disposes of the product) and `surplus-to` (where
the surplus went). Five moves, each one the programme asks for: `expropriate`
(granted in full, with no way back), `distribute`, `appoint-board`,
`fund-administration` (Gotha's second deduction) and `recall-board`. The claim
is a `never` in [`gotha.claims`](gotha.claims): the mill is common and the
surplus has gone, by direction, to someone who does not work it.

## What writ answers

```console
$ writ check gotha.writ --claims gotha.claims
states: 7   edges: 13
…
holds  expropriation-succeeds
…
fails  no-exploitation
…
  witness:  1. expropriate           → #1   loom-house.title: private → common, loom-house.directed-by: proprietor → weavers, loom-house.surplus-to: proprietor → ∅
            2. appoint-board         → #3   loom-house.directed-by: weavers → board
            3. fund-administration   → #5   loom-house.surplus-to: ∅ → board
holds  exploitation-endable
…
```

The revolution succeeds (`expropriation-succeeds`), so the claim's antecedent
is really reached. Then the claim fails in three moves: the commune
appoints a board to administer the deductions, and the board makes one. None of
the moves is a betrayal; each is the programme carried out. The check exits 1.
`exploitation-endable` holds too: from every situation `recall-board` can
return the surplus to the weavers. The claim is false; the outcome is no trap.

## Take away

The refutation is exact. Ownership was several arrows and `expropriate` moves
only `title`; the claim that would have done the work is about `directed-by`,
and nothing here refutes that one. A `never` claim's potential falsifiers can
be listed: `gotha.rules` finds one, situation 5 of 7, and it is reachable.

## Run it

```sh
writ check gotha.writ --claims gotha.claims
writ derive gotha.writ gotha.rules no-exploitation
./cross-check.sh     # the same questions via gotha.rules
```
