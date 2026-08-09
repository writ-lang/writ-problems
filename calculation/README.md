# The calculation problem — one allotment of steel, and who gets to say they need it

*A pair of models that differ in exactly one guard, asked exactly the same
questions. The priced one holds all three. The planned one loses two of them,
and `pol` names the three moves that lose them.*

## The files

| file | what it is |
| --- | --- |
| [`../libraries/economy.lib.pol`](../libraries/economy.lib.pol) | the world both models share: plants, needs, the allotment, the allocation rule, the commitment rule, the law |
| [`market.pol`](market.pol) | the base — the ask must be backed by the asking plant's own need |
| [`planned.pol`](planned.pol) | the same file with that one conjunct repealed |
| [`market.claims`](market.claims) | the three questions and the nine acknowledgments, put to **both** models unchanged |
| [`market.rules`](market.rules) | the same three questions re-asked relationally |
| [`cross-check.sh`](cross-check.sh) | runs both engines over both models and compares the six verdicts |

```console
$ pol check   market.pol  --claims market.claims
$ pol check   planned.pol --claims market.claims
$ pol compare market.pol  planned.pol
$ ../run-tests.sh calculation
```

## The problem, from the beginning

A quantity of steel exists. Three plants could use it:

| plant | what it would build | does it actually need the steel? |
| --- | --- | --- |
| `clinic` | a dialysis wing | **yes** |
| `tractor-works` | a press line | **yes** |
| `monument` | a statue of the founder | no |

Only one of them can have it. So somebody has to decide, and the decision needs
a fact: **how badly each plant needs the steel**. In the model that fact is
`plant.need`, and it is `fixed` — wiring, a feature of the world, not something
any move can change. It is in the model. `pol query market.pol who-needs-it`
prints it:

```console
$ pol query market.pol who-needs-it
who-needs-it  (at state 0)
  p = clinic
  p = tractor-works
```

**The difficulty is never that the information does not exist.** It exists, it
is true, and it is sitting right there in the schema. The difficulty is that it
sits *at the plants*, and the allocator is not standing in a plant. What the
allocator can read is the other arrow — `plant.ask`, the signal it is sent.

Two routes from a plant to the same type. Nothing in the schema makes them
agree. That gap is the whole scenario, and everything below is a consequence of
how each arrangement tries to close it.

## The two arrangements, and the one line that separates them

Both models load [`../libraries/economy.lib.pol`](../libraries/economy.lib.pol),
which holds the plants, their needs, the allotment, the allocation rule, the
commitment rule and the law. Both then declare the same twelve moves under the
same twelve names. They differ in one form:

```lisp
;; planned.pol — a request. Saying you need the steel costs nothing,
;;               so the guard has nothing to bind the saying to.
(form (request NAME P LEVEL)
  (transition NAME
    (when (not (is P.ask LEVEL)))
    (do (set P.ask LEVEL))))

;; market.pol — a bid. Asking means offering to pay out of the plant's own
;;              budget, so the move is not available to a plant with no need.
(form (request NAME P LEVEL)
  (transition NAME
    (when (and (not (is P.ask LEVEL))
               (is P.need LEVEL)))
    (do (set P.ask LEVEL))))
```

One conjunct. `planned.pol` is written as the **repeal** of it — the way
[`../oversight/oversight-repeal.pol`](../oversight/oversight-repeal.pol) is
written against its base — so that `pol compare` can price the repeal.

That conjunct is the only claim being made about prices anywhere in this
scenario, and it is worth stating flatly. It does **not** say markets are
efficient, or fair, or good. It says one thing: *a signal that costs the sender
something cannot be inflated for free, so it stays tied to the sender's own
situation.* Whether that is a fair reading of a budget constraint is a question
about the premise, and the premise is the one thing the tool does not check.
What the tool checks is what follows.

## What `pol` answers

### The priced economy — `market.pol`

```console
$ pol check market.pol --claims market.claims
states: 12   edges: 18
gaps: none
dead ends: 2
  reached by: ask-clinic-high, ask-tractor-high, allocate-clinic, build-clinic
  reached by: ask-clinic-high, ask-tractor-high, allocate-tractor, build-tractor
equation signal-honest
  can be broken by: ask-clinic-high, ask-clinic-low, …, allocate-monument   (acknowledge in claims)
holds  need-can-be-met
  witness:  1. ask-clinic-high
            2. allocate-clinic
            3. build-clinic
holds  no-waste
holds  need-always-still-meetable
$ echo $?
0
```

Twelve situations, two ways it can end, and both of them end with the steel in
a plant that needed it.

### The planned economy — `planned.pol`, the same questions

```console
$ pol check planned.pol --claims market.claims
states: 56   edges: 260
gaps: 1
  survey — "the plan has no procedure by which the centre could learn a need that no request carries" (min 0 moves)
dead ends: none
equation signal-honest
  can be broken by: ask-clinic-high, ask-clinic-low, …, allocate-monument   (acknowledge in claims)
  violated in 24 reachable situations   witness: 1. ask-monument-high 2. allocate-monument
holds  need-can-be-met
  witness:  1. ask-clinic-high
            2. allocate-clinic
            3. build-clinic
fails  no-waste
  witness:  1. ask-monument-high
            2. allocate-monument
            3. build-monument
fails  need-always-still-meetable
  stuck at: (clinic.ask=low tractor-works.ask=low monument.ask=high steel.at=monument steel.state=built)
  witness:  1. ask-monument-high
            2. allocate-monument
            3. build-monument
$ echo $?
1
```

### And what the repeal costs, as one command

```console
$ pol compare market.pol planned.pol
equations:   signal-honest               preserved
properties:  need-can-be-met             preserved
             no-waste                    LOST      witness: 1. ask-monument-high 2. allocate-monument 3. build-monument
             need-always-still-meetable  LOST      witness: 1. ask-monument-high 2. allocate-monument 3. build-monument
```

## Reading the three questions in order

They were written to be read as an argument, and each one is doing a job the
others cannot.

**1. `need-can-be-met` — holds in both.** *The steel can end up built at a plant
that needed it.* This is the question that clears the plan of the accusation
usually thrown at it. The centre is not incompetent; the plan is not incapable;
there is a route, three moves long, and `pol` prints it. Any argument that has
to begin "planners are stupid" is not the argument here, and this line is what
retires it.

**2. `no-waste` — holds under prices, fails under the plan.** *The steel is
never built at a plant that does not need it.* The monument asks, and asking is
free. The allocator sees a request identical in every respect to the clinic's,
because at the allocator's end **it is** identical — a request is a request.
The steel goes to the monument. Three moves; `pol` names them.

Under prices the same three moves are written down, `allocate-monument`
included, and nothing forbids them. The first one just never becomes available,
because the signal it waits on cannot be produced by a plant with no need. The
bad outcome is not policed. It is **unreachable**.

**3. `need-always-still-meetable` — holds under prices, fails under the plan.**
*From every situation the rules allow, the steel can still be built where it is
needed.* This is the one the tool exists for, and it is the difference between a
mistake and a loss. Question 2 says the bad outcome is permitted. Question 3
says it is **terminal**: `stuck at: (… steel.at=monument steel.state=built)`.
Steel welded into a statue is not an error to be corrected by a better plan next
quarter. There is no next quarter for that steel. The clinic's dialysis wing was
not delayed; it was cancelled, by an act nobody in the model intended and
nobody in the model can undo.

## Three things in the output worth not skipping

**The gap.** `planned.pol` carries one declared hole:

```lisp
(transition survey
  (when (is steel.state idle))
  (do (gap "the plan has no procedure by which the centre could learn a need that no request carries")))
```

A gap is *declared silence* — "we decided not to model this" — as against a dead
end, which is silence nobody wrote down. This one is the calculation problem in
the single word the language has for it. The centre would like to know which
plant actually needs the steel. Write the move that finds out, and the model
gets better; but you cannot write it out of the pieces this arrangement has,
because a plan is a procedure and this procedure has no step that reads a
`need`. `market.pol` has no gap, and not because it was let off: its channel is
specified, and it is the bid.

**The law it breaks is its own.** `signal-honest` — *the plant holding the steel
is one whose signal matches its situation* — is declared once, in the shared
library, and inherited by both models. The priced model never reaches a state
that violates it. The planned model violates it in **24 of its 56 situations**,
and `pol` prints the two moves that get there. Note that `can be broken by`
lists the same nine moves in both files: that line is about what a move
*writes*, not about what is reachable. Both models are handed the same ledger,
and both acknowledge the same nine moves in
[`market.claims`](market.claims). Only one of them then has to report a
violation.

**56 states against 12.** Same world, same plants, same steel, same twelve
moves. The plan has nearly five times the situations — because a signal that is
free to send makes every combination of signals reachable, and none of the extra
arrangements carries any extra information. That number is the cost of the
repealed conjunct, showing up as arithmetic before any question is asked.

## What this does and does not show

The scenario is called `calculation` and not something more satisfying, because
what it models is [the economic calculation
problem](https://en.wikipedia.org/wiki/Economic_calculation_problem) — Mises in
1920, Hayek's *The Use of Knowledge in Society* in 1945 — with the soft budget
constraint (Kornai) as the shape of the repeal. It is one mechanism, and the
honest boundaries around it are these:

**It proves a consequence, not a premise.** The two guards are assumptions,
written in plain sight at the top of two files, and `pol` never examines them.
What it establishes is what follows *from* them, exhaustively, over every one of
the 56 reachable situations — including the ones nobody thought to check. That
is the division of labour the tool is for, and it cuts both ways: disagree with
a guard, and the finding is yours to redirect, not to dismiss.

**"Fails" means permitted, not inevitable.** Pol is a possibility engine, not a
game solver. There are no incentives in it and no probabilities: a move that can
fire, can fire. So `fails no-waste` says the rules of the planned economy
*allow* the steel to be spent on the statue — not that they force it. The
planned model can still get it right; `need-can-be-met` holds, and the route is
printed. What it cannot do is **guarantee** it. That is a weaker claim than the
slogan, and a much harder one to argue with: the plan's guarantee is not
missing by bad luck. It is missing because the guard that would supply it has
nothing to read.

**It is three plants and one allotment.** It is not a country, an economy, or a
century. What survives the smallness is the shape of the failure — a signal
untied to a situation, an allocator with no other channel, and a commitment that
cannot be undone — and that shape does not need more plants to be visible. More
plants make it larger, not truer.

**It says nothing in favour of markets beyond the one conjunct.** `market.pol`
holds these three properties and no others were asked. Everything a priced
system is usually accused of — that the budget is what a plant *has* rather than
what it *needs*, that a clinic can be outbid by a better-funded statue — is
outside this model, because `need` here is not weighted by wealth. Change that,
and the priced model has findings of its own. Ask it; the claims file is
reusable and that is the point of it living apart.

**How to argue with it, concretely.** Write a move in `planned.pol` whose guard
reads a `need` and which costs the asker something. Nothing in the language
stops you, the file is thirty lines, and if the properties then hold, the
finding is overturned — that is what a model you can run is *for*. The
observation this scenario is really making is what such a move has to look like
once you have written it down.
