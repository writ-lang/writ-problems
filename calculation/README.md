# The calculation problem — prices or a plan

One allotment of steel, three plants that want it. The clinic and the tractor
works need it; the monument does not. Each plant's real need is a fixed fact of
the world, but it sits at the plant: the allocator only sees the request each
plant sends. Two models of that world, one with prices and one with a plan, are
asked the same three questions from one claims file.

## The model

Both models load [`../libraries/economy.lib.writ`](../libraries/economy.lib.writ)
(plants, needs, the allotment, the allocation rule, the irreversible build, and
the law `signal-honest`) and declare the same twelve moves. They differ in one
conjunct. In [`market.writ`](market.writ) asking is a bid paid from the plant's
own budget, so only a plant with the need can make it.
[`planned.writ`](planned.writ) repeals it, so a request costs nothing:

```lisp
;; market.writ                                ;; planned.writ
(form (request NAME P LEVEL)                  (form (request NAME P LEVEL)
  (transition NAME                              (transition NAME
    (when (and (not (is P.ask LEVEL))             (when (not (is P.ask LEVEL)))
               (is P.need LEVEL)))                (do (set P.ask LEVEL))))
    (do (set P.ask LEVEL))))
```

`planned.writ` also declares a gap, `survey`: the plan has no procedure for
learning a need that no request carries.

## What writ answers

```console
$ writ check market.writ --claims market.claims
states: 12   edges: 18
…
holds  no-waste
…
holds  need-always-still-meetable
…
$ writ check planned.writ --claims market.claims
states: 56   edges: 260
…
gaps: 1
  survey — "the plan has no procedure by which the centre could learn a need that no request carries" (min 0 moves)
…
fails  need-always-still-meetable
  stuck at: #22 (clinic.ask=low tractor-works.ask=low monument.ask=high steel.at=monument steel.state=built)
…
$ writ compare market.writ planned.writ
equations:   signal-honest               preserved
properties:  need-can-be-met             preserved
             no-waste                    LOST      witness: 1. ask-monument-high 2. allocate-monument 3. build-monument
             need-always-still-meetable  LOST      witness: 1. ask-monument-high 2. allocate-monument 3. build-monument
```

- **`need-can-be-met` holds in both.** The plan can get it right; writ prints
  the three-move route to the clinic.
- **`no-waste` fails under the plan.** The monument asks, the allocator cannot
  tell its request from the clinic's, and the steel is built into a statue.
  Under prices the same moves exist, but the first one is never enabled.
- **`need-always-still-meetable` fails under the plan.** The build cannot be
  undone, so the waste is terminal: writ prints the stuck situation.
- **`signal-honest`**, the library's law that the steel's holder asked
  truthfully, is violated in 24 of the plan's 56 situations and none of the 12
  priced ones. A free signal makes every combination of requests reachable.

## Take away

A signal that costs the sender stays tied to the sender's situation. That
conjunct is the premise; writ checks what follows from it, over every reachable
situation. "Fails" means the plan permits the waste, not that it forces it. Need
is not weighted by wealth here, so the model says nothing else about markets;
the claims file lives apart so you can put it to a model of your own.

## Run it

```sh
writ check   market.writ  --claims market.claims
writ check   planned.writ --claims market.claims
writ compare market.writ  planned.writ
./cross-check.sh     # the same questions via market.rules, both models
```
