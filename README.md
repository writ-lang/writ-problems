# Solving problems with `pol`

*Worked models for [pol](https://github.com/sajonaro/pol). The language, the
checker and the CLI live there; this repository is the problems and their
answers.*

A sequence of end-to-end tests that **use the `pol` tooling to solve real
problems** and check the answers. Each problem is written as a Pol model
(`.pol`) with its questions kept next door (`.claims`), exactly as the spec
prescribes; the test runner calls `pol check` (and, for `oversight`, `pol
compare`) and asserts the verdicts.

The first batch is puzzles: the two from the spec's **Prologue** (Appendices C
and D), faithful to the spec, plus **eight queens**, which is not from the spec
but is the first thing the language could state once `differ` existed, and a
**blocking job shop**, whose deadlock is the trap detector at work on a real
scheduling question. Each
move is given a name so `pol` prints a legible solution path (see *Notes on the
solution path* below). The second batch is the three **§3 scenarios** — institutional architecture, a regulated
workflow, and access & privilege — which exercise `equation` laws, `accept`
acknowledgments and `pol compare`.

The third is one scenario that turns the tool around. Every model above
**checks** something already designed; `arch/` **designs** it — a component
bank, a brief, and every architecture the constraints permit, enumerated. Its
most useful output is not the answer but the question it hands back: the one
thing the brief forgot to say.

The fourth is a **pair**. `calculation/` holds two models of one world that
differ in a single conjunct, and one claims file put to both: the questions are
held fixed so that the difference in the verdicts is attributable to the
difference in the models, and to nothing else.

The sixth turns the tool the other way round again. Every model above is
written to be walked; `timetable/` is handed a **finished artifact** — a school
week a CP-SAT solver decided — and asked whether it is any good. Its schema is
`fixed` throughout, so the space is one situation and the whole run is spent on
the questions.

The fifth is the smallest file here and the only one whose subject is a
**claim**. `gotha/` states a proposition that forbids something, in Popper's
sense, and asks `pol` for a situation it forbids. There is one, three moves
away.

## The puzzles, and what `pol` answers

### 1. The river crossing (Appendix C) — `river/`
A farmer must ferry a wolf, a goat and a cabbage across a river; left
unattended with its prey, the wolf eats the goat and the goat eats the cabbage.

`pol check` answers:
- **`holds solvable`** — yes, everything *can* reach the far bank intact, **and
  `pol` prints the crossing** as the witness (the solution the question asked
  for): `cross-wolf-LR → cross-empty-RL → cross-goat-LR → …`.
- **`fails no-blunders`** — but not every path stays safe: there is a reachable
  arrangement from which the crossing can no longer succeed. The witness is the
  blunder — `cross-empty-LR → wolf-eats-goat-L` — and `stuck at:` shows
  `goat.at=∅`, the goat eaten.

### 2. Knights & knaves (Appendix D) — `island/`
Knights always tell the truth, knaves always lie. Reading a native's recorded
claim assigns a consistent kind — but "I am a knave" is consistent with
*neither* kind.

`pol check` answers:
- **`gaps: 1`** — the rules run out exactly once: reading cal (who said "I am a
  knave") is a declared hole ("the island's rules are silent").
- **`fails census-completable`** — so *not* everyone can be classified.
- **`holds abe-can-be-knight` / `holds bea-can-be-knight` / `fails
  cal-can-be-knight`** — abe and bea (who each said "knight") could each be a
  knight; cal could be *nothing at all*. That is the paradox, made mechanical.

Each `pol check` **exits 1** — not because anything is broken, but because it
*has a finding to report* (a possible blunder; an unclassifiable native). The
tests assert exit 1 as the correct outcome.

### 3. Eight queens — `queens/`
Eight queens on a board, none attacking another.

`pol check` answers **`holds solvable`**, and the witness *is* a solution —
the eight moves that place the queens. All 92 complete boards appear as dead
ends, a full board having no move left.

It earns its place for two reasons beyond the puzzle. It is the first thing
Pol can state that it could not before: a row clash is
`(differ q1.row q2.row)`, which had no spelling until §8.6 let a law hold a
guard and `differ` joined the standard library. And it carries the clearest
measurement here of *which* optimisation matters — the same puzzle without
one ordering conjunct has 118 969 situations instead of 2 057 and does not
finish in ten minutes, while an engine-level change that looked obviously
right measured to nothing. Both are written up in
[`queens/README.md`](queens/README.md).

Diagonals cannot be computed — `|Δrow| = |Δcol|` is arithmetic and Pol has
none — but they need not be enumerated either: rows are **entities on a
ladder** with `next`/`prev`, so the square a queen *d* columns away attacks
is `R.next` walked *d* times, and a form names that test once per distance.
Twenty literal conjuncts per move became nine that read. The models are still
generated, there being one move per (column, row), but that is the move set's
doing rather than the arithmetic's.

### 4. A blocking job shop, asked twice — `jobshop-possible/`, `jobshop-best/`
Three jobs, three machines, routed in a cycle, with no buffers: a job holds the
machine it is on until it has *acquired* the next one.

A shop has two different questions, and they need two different models.

**`jobshop-possible/` — does a schedule exist?** `pol check` answers **`holds
all-finish`**, then **`fails never-stuck`**, naming a three-move circular
deadlock in full: `a-enters, b-enters, c-enters`, after which each job holds
the machine the next one waits for. No time in this model at all — and it does
not need any, because the shop seizes on the *shape* of the routings and would
seize identically whether an operation took a minute or a week. 51 situations.

**`jobshop-best/` — which schedule is shortest?** The same shop with a clock:
ticks as a **small named scale** (Appendix G's own escape clause), a ladder of
entities walked by `next`, so "finishes within 5 ticks" is an ordinary
`possible`. `done-by-4` **fails** and `done-by-5` **holds**, which pins the
optimum from both sides, and the witness is the optimal schedule. Optimisation
by repeated feasibility rather than a cost function. 1314 situations — time is
expensive, which is why the untimed model stays.

The pair is the lesson. The optimum overlaps two jobs and holds the third back,
and the *other* model is what proves it must: full utilisation is the deadlock.
Neither answers that alone. See
[`jobshop-possible/README.md`](jobshop-possible/README.md) and
[`jobshop-best/README.md`](jobshop-best/README.md).

Both are **19 and 20 lines**, because the shop itself is not in either of them:
[`libraries/scheduling.lib.pol`](libraries/scheduling.lib.pol) is a **domain
library** holding the
machines, the routings, the blocking rule and a clock, and the two models load
it and then differ only in their moves — which is the one thing a pair exists
to compare. Their `.claims` and `.rules` files load it too, so a model, a
question and a derivation share one vocabulary without sharing a file.
[`libraries/chess.lib.pol`](libraries/chess.lib.pol) does the same for the
board. Both live in [`libraries/`](libraries/README.md), which explains what
makes a file a library and what grouping them cost.

## The spec's §3 scenarios

Three institutional models, each exercising machinery the Prologue puzzles do
not: **`equation` laws + `accept` acknowledgments** (§8.6, §15, §16.3) and
**`pol compare`** (§17).

### 5. Institutional architecture (§3 / §4 running example) — `oversight/`
The kernel-spec's own running example: two oversight agencies, one case
(`docket`), a possibly-vacant judge, and the structural law `same-agency` (the
investigating and prosecuting agencies must stand on equal footing). Schema,
instance, equation and moves are transcribed from §4; a single guard token is
changed (see the honest note below).

`pol check` answers:
- **`equation same-agency` / `can be broken by: capture-watchdog,
  restore-watchdog`** — the tool's guard-and-effect analysis names exactly which
  of our own powers can violate our own declared law (both write
  `watchdog.independence`, an arrow both routes of the law traverse). The
  `.claims` file **`accept`s both**, so neither is reported `unadmitted`;
  accepting a non-breaker (`conclude`, `assign-judge`) would be reported `stale`.
  Reachable violations are still listed.
- **`holds conviction-possible`** — the docket can conclude, and `pol` prints the
  concluding move as the witness.
- **`holds accountability`** — `(live (is docket.stage concluded))`: from every
  reachable situation the case can *still* conclude, because `restore-watchdog`
  can always undo a capture.

`oversight-repeal.pol` is the same model with `restore-watchdog` **deleted** —
an amendment that looks procedural. `pol compare oversight.pol
oversight-repeal.pol` reports its true cost:
```
properties:  accountability       LOST      witness: 1. capture-watchdog
```
and **exits 1**. One lawful capture now permanently destroys accountability: the
watchdog can never be restored, the investigation stalls, and the docket can
never conclude from that situation. `same-agency` and `conviction-possible` stay
`preserved` — the loss is precisely accountability.

> **Honest note.** In §4 *as printed*, `conclude` guards on the *prosecutor*'s
> independence while the capture power targets the *watchdog* (investigator) — so
> the two are decoupled and deleting `restore-watchdog` costs nothing (verified:
> the compare stays `preserved`, exit 0). To make the amendment's cost real —
> and keep the `same-agency` breaker list exactly `{capture-watchdog,
> restore-watchdog}` — `conclude` here guards on `docket.investigator.independence`
> (the bureau the capture power actually targets). That is the only departure
> from §4; capturing the prosecutor instead would add two more breakers.

### 6. Regulated workflow — KYC / claims (§3) — `workflow/`
A case wired (fixed) to a reviewing officer and its unit of record, a mutable
approving `officer`, and a vacatable `assignee` slot. The law `officer-in-unit`
(`(= case.officer.unit case.unit)`) demands the approving officer belong to the
unit of record.

`pol check` answers:
- **`gaps: 1` — `escalate`** — the automated process settles a case that has an
  assignee; where there is none it ends at a declared `gap` ("escalated to a
  human"). That is the boundary where automation stops and a person takes over.
- **`can be broken by: reassign-to-fraud, reassign-to-kyc`** — the reassignment
  moves are the law's breakers (both write `case.officer`); the `.claims`
  **`accept`s both**, so nothing is `unadmitted`.
- **`holds settle-able`** — `(live (is case.stage settled))`: **no case ever gets
  stuck**. Even in the escalation state (no assignee) the case can be assigned
  and then settled, so a settled situation stays reachable from everywhere.

### 7. Access & privilege (§3) — `access/`
Accounts with a `role` (user | admin), a `sponsor` (who vouches for them), and a
fixed `source` of authority. The law `traces-to-root`
(`(= account.sponsor.source account.source)`) demands each account inherit its
authority from its sponsor — the chain back to the security root.

`pol check` answers:
- **`can be broken by: delegate-alice-to-mallory`** — the one grant that rewires
  a `sponsor` to an externally-sourced account breaks the root-tracing law; the
  `.claims` **`accept`s** it (the role grants write `role`, off the law's route,
  so accepting them would be `stale`).
- **`fails revocation-possible`** — `(live (not (some (a account) (is a.role
  admin))))`: revocation is **not** always possible. `grant-breakglass-admin` is
  a **designed latch** — an emergency admin with no revoke move — so once it
  fires, `mallory` is admin forever and a "nobody is admin" situation can never
  be reached again. `pol` prints the stuck state and the single latching move as
  the witness (`1. grant-breakglass-admin`). §3 asks the model to say whether an
  irreversible grant is a latch or a defect; here the model declares it a latch.
- **`query admins`** — the accounts holding admin now (empty at the baseline).

## Designing, rather than checking

### 8. System architecture from a component bank — `arch/`

*50TB of files, mostly PDFs. Classify them, configurably and re-runnably. Feed
what they contain to AI. Surface it in the CRM that already exists.*

The scenarios above **check** a design someone wrote. This one **produces** one:
nineteen components, seven stages, the brief's requirements as guards, and every
architecture the constraints permit walked by exhaustion. It is `queens/` one
level up — a queen is placed on a square, a stage is filled by a component, and
the same cursor keeps it to seven moves. The vocabulary is in
[`libraries/arch.lib.pol`](libraries/arch.lib.pol).

`pol check` answers:
- **`dead ends: 96`** — 96 architectures satisfy the brief, out of 2,916 raw
  combinations, and **`holds realisable`** prints one of them stage by stage.
- **`gaps: 1`** — the brief never says whether the PDFs are digital-native or
  **scanned**, and that one unstated fact decides which extract components are
  admissible. `pol` reports the hole rather than guessing past it. *This is the
  question to put back to whoever wrote the brief*, derived rather than intuited.
- **`fails rerun-is-affordable`** — and this is the finding. The witness is
  `object-store → event-stream → llm-vision → rules-engine`: every **stated**
  requirement met, but `llm-vision` discards what it extracts, so re-running the
  classification silently re-processes all 50TB. **Half the answer set — 48 of
  the 96 designs — looks correct and is not.** "Be able to re-run" is a sentence
  about the *classify* stage that constrains the *extract* stage two steps away,
  and nothing in the brief connects them.
- **`holds no-dead-end`** / **`holds crm-stays-loose`** — no partial choice
  strands the build, and the CRM is never coupled at the database.

It is also the repository's first **`never`** properties, which is why the
modality cross-check no longer reports that branch as unexercised.

Reading a finished design out is `pol derive`'s job, not a query's — see the
scenario's [README](arch/README.md) for why `(is k.chosen c)` in a query
silently answers zero rows.

## Two arrangements of one world, asked the same questions

### 9. The calculation problem — `calculation/`

*One allotment of steel. Three plants: two that need it, one that would build a
statue with it. Only one can have it.*

Every scenario above puts questions to **one** model. This one is a **pair**,
and the pair is the instrument: `market.pol` and `planned.pol` share a schema,
an instance, a law, a move set and every transition name, and differ in one
conjunct — whether the request an allocator reads must be backed by the asking
plant's own situation. The same [`market.claims`](calculation/market.claims) is
put to both, and the verdicts are what move. The vocabulary is in
[`libraries/economy.lib.pol`](libraries/economy.lib.pol).

`pol check` answers, of both:
- **`holds need-can-be-met`, in each** — neither arrangement is *incapable*;
  both can end with the steel built where it was needed, and `pol` prints the
  three-move route in each.
- **`holds no-waste`** under prices, **`fails`** under the plan — a costless
  request cannot be weighed against anything, so the monument's request buys the
  steel: `ask-monument-high → allocate-monument → build-monument`. Under prices
  the same three moves are written down; the first never becomes available.
- **`holds need-always-still-meetable`** under prices, **`fails`** under the
  plan — and this is the finding. The waste is not a delay: `stuck at: (…
  steel.at=monument steel.state=built)`. Steel welded into a statue is steel no
  longer, so no future move can put it right.
- **`gaps: 1`**, in the plan only — `survey`, the move that would find out what
  the requests do not carry, is a **declared hole** rather than an invented
  procedure. That gap is the economic calculation problem in the one word the
  language has for it.
- **`violated in 24 reachable situations`** — of its 56, against the law both
  models declare and both `accept` the same nine breakers for. The priced model
  reaches no violation of it at all. (56 states against 12, for the same world:
  a signal that is free to send multiplies the arrangements without adding
  information.)

And the pair supports the operation a pair exists for:

```console
$ pol compare calculation/market.pol calculation/planned.pol
properties:  need-can-be-met             preserved
             no-waste                    LOST      witness: 1. ask-monument-high 2. allocate-monument 3. build-monument
             need-always-still-meetable  LOST      witness: 1. ask-monument-high 2. allocate-monument 3. build-monument
```

What the finding is and is not — Pol is a possibility engine, so `fails` means
*permitted by the rules*, not *inevitable* — is worked through in the scenario's
[README](calculation/README.md), along with what to write if you want to
overturn it.

## Refuting a claim

### 10. A claim, and its falsifier — `gotha/`

*One mill; seven situations; twenty-six lines. The smallest scenario here, and
the only one whose subject is a **claim** rather than a system.*

A claim earns testing, in Popper's sense, by **forbidding** something — and a
prohibition is what `never` is, which makes the shape of this scenario the
tool's own. The claim: *once the means of production are held in common, no
surplus goes to a party outside the work, by the decision of a party outside the
work.* The model grants the expropriation in full and at once, with no move
back, and every move in it is one the programme itself asks for — the Manifesto's
abolition, Gotha's deductions, the Commune's recall.

`pol check` answers:
- **`holds expropriation-succeeds`** — the antecedent is reached: the mill does
  become common and the surplus does reach the hands that worked it. A model in
  which the revolution failed would refute nothing.
- **`fails no-exploitation`** — and the witness is the falsifier, three moves
  long: `expropriate → appoint-board → fund-administration`. Gotha's own second
  deduction, "the general costs of administration not belonging to production",
  is made by a body that does not work the mill, from a mill the claim says
  cannot be exploited.
- **`holds exploitation-endable`** — and this is in the claims file so the
  finding cannot be stretched: recall works, so what is exhibited is a
  *permitted* condition, not a trap.

The mechanism is in the schema rather than the moves: `worked-by`,
`directed-by` and `surplus-to` are three arrows where speech has one word, and
`expropriate` moves a fourth, `title`. See
[`gotha/README.md`](gotha/README.md) for the claim's untestable sibling, why the
criterion is taken at its strongest, and the amended claim the refutation leaves
standing.

## Judging what another tool decided

### 11. A timetable a solver produced — `timetable/`

*Sixty lessons, three groups, five days: every hour the curriculum demands,
placed in a period, a room and a teacher's diary. Every hard constraint met.
Would a school accept it?*

`arch/` designs and the rest walk a space; this one is handed a **decided
artifact** and audits it. The week was produced by CP-SAT — the constraint
solver in Google's OR-Tools, which is given unknowns and the rules they must
obey and searches for values satisfying all of them — running in the sibling
repository [`pol-scheduling-verification`](https://github.com/sajonaro/pol-scheduling-verification); the schedules here are frozen
fixtures, so the verdicts are exact. The solver never saw the questions, which
is the only reason its answers are worth checking.

`pol check` answers:
- **`states: 1`** — every arrow is `fixed`, because a decided timetable has
  nothing left to vary, so there is one situation and the run is spent
  evaluating questions rather than enumerating. Checking is cheap exactly where
  generating is dear: asking `pol` to *produce* a timetable passes the
  200 000-state cap at about fifteen lesson-hours.
- **ten properties hold** — the programme is delivered exactly (no hour missing,
  none invented, none delivered twice), nothing is in two places at once, every
  room is the right kind and big enough, every teacher qualified and available.
  These restate independently what the CP model was told; agreement between two
  statements of one requirement, in two languages, is worth more than either.
- **`fails sport-not-first` / `fails time-to-change-after-sport`** — two rules
  any teacher would say out loud and nobody encodes. The timetable is feasible,
  optimal, and would be rejected by the first person to read it.
- **`gaps: 2`** — and these are the better half. The curriculum never says
  whether a group may have a free period *between* lessons, or whether two hours
  of one subject may fall on one day, so the solver settled both by accident.
  **Questions to put back to whoever wrote the curriculum.**
- **the same claims file, put to `timetable-strict.pol`** — the week re-solved
  with those findings encoded — reports `gaps: none` and exits 0, and
  `pol compare` between the two prints `sport-not-first gained` with everything
  else `preserved`. One question suite, two timetables, and the difference
  read off rather than argued.

Counting is the other thing to look at: five hours of maths is five `demand`
entities told apart by an `ordinal`, and three properties make lesson↔demand a
bijection — exact counting with no arithmetic anywhere. See
[`timetable/README.md`](timetable/README.md).

## The remaining §17 surfaces — `control/`, `gitcompare/`

Two thin tests that exercise the last of the §17 command line on the models
above (no new model files).

### 12. `pol control` — dynamics as data — `control`
`pol control oversight.pol` emits the model's **move list** as an instance of the
standard library's `quiver` schema: one `node`, one `edge` per transition. The
test asserts it is a `(of quiver)` instance and then **wraps and re-checks it**,
proving the export is real Pol data that builds with the same machinery — the
seam toward simulation maps between two models' move lists.

### 13. `pol compare --git` — an amendment across commits — `gitcompare`
The `oversight` repeal, but as *history* rather than two files. The test spins up
a throwaway git repo, commits the law, then commits the repeal to the same path,
and runs `pol compare --git HEAD~1 HEAD law.pol` — reporting `accountability
LOST` across the two commits, exactly as `pol compare OLD NEW` did on the two
files. (Needs `git`; the Docker image installs it, and the local runner skips
this one gracefully if `git` is absent.)

## Run it

This repository contains **no engine**. Install
[pol](https://github.com/sajonaro/pol) first — the runner needs `pol` on your
`PATH`, and the models need the standard library the install puts alongside it:

```sh
opam install pol         # or: make install-pol, from a pol checkout
pol --version
```

Then:

```sh
./run-tests.sh                  # every scenario
./run-tests.sh river            # just one
POL=/path/to/pol ./run-tests.sh # a pol that is not on PATH
```

`(load "stdlib.pol")` resolves with nothing configured: the installed layout
puts the standard library at `<prefix>/share/pol/lib`, which is where the
resolver looks (design D3). `POL_TRACE_LOADS=1` prints what each load actually
resolved to, if a model ever surprises you.

### With Docker — nothing installed on the host

Everything above needs `pol` on your machine. If you would rather install
nothing, the scenarios run in a container built **from the image the pol
repository produces**:

```sh
cd ../pol && make image        # tags pol:latest — once, and only when pol changes
cd -                           # back here
docker compose up              # every scenario; exits non-zero if any check fails
docker compose run --rm river  # just one
```

That image carries `pol`, the standard library where the resolver looks, and
`git` — which `pol compare --git` shells out to, so the `gitcompare` scenario
needs it at runtime rather than as a build tool.

The base image is named by a build ARG, so the day pol publishes one, this
repository needs no change:

```sh
docker compose build --build-arg POL_IMAGE=ghcr.io/sajonaro/pol:0.1.0
```

Until then, building it yourself is the one step that still wants a pol
checkout. Nothing else here does.

## Adding a puzzle
1. Create `<name>/<name>.pol` (the model) and `<name>.claims` (the questions).
   A `pol compare` scenario also ships a second `.pol` (see
   `oversight/oversight-repeal.pol`), and where the pair is the point the files
   may take a stem of their own (`calculation/market.pol`, `.../planned.pol`) —
   `pol compare` and `pol query` read the claims file as a sibling of the base
   model. Shared vocabulary goes in [`libraries/`](libraries/README.md) as a
   domain library.
2. Add a `<name>()` function to `run-tests.sh` — run `pol check` (and
   `pol compare` if the scenario needs it, on absolute paths under `$here`) and
   assert the answers with `has …` / `near …` / `lacks …` / `exit_is …` — plus a
   case in the dispatch and the `all` runner at the bottom.
3. If the scenario re-asks its questions of the rules engine, add a `.rules`
   file too, and compare the two answers — a disagreement is a bug in one of
   them, never a number to adjust. Two ways to run that comparison:
   `modality-cross-check.sh` walks the nine scenarios named in it, discovering
   properties from their claims files; or the scenario carries its own
   `cross-check.sh`, one line per property, naming the modality and the polarity
   outright (`calculation/`, `gotha/`). Prefer the second — it is a dozen lines,
   it reads without a parser, and it can put one rules file to two models.

## Notes on the solution path
- **A holding `possible` now prints its witness — the solution.** `possible F`
  asks "can this happen"; when it holds, `pol` shows the shortest path to an
  F-situation, which *is* the answer (the river's crossing; the reading that
  makes abe a knight). This matches the spec's Appendix C.
- **The moves are named.** A bare `form` produces *unnamed* transitions, which
  §10.1 renders only by position (`#0`, `#8`); a `form` can't synthesise a name.
  So each move here takes an explicit name slot (`cross-goat-LR`, `abe-is-knight`,
  `read-cal`), and the solution path reads as prose — faithful to the named moves
  Appendix C's own report shows.
