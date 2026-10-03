# Solving problems with writ

<img src="docs/images/writ-mark-200.png" alt="writ" width="120" align="left" hspace="16" vspace="4">

Worked models for [writ](https://github.com/writ-lang/writ), each a real
question answered by exhaustion. Every scenario is a model (`.writ`) with its
questions beside it (`.claims`), and a test runner that checks writ gives the
expected answers — so this repository is both a gallery and a regression suite.

<br clear="left">

## Run it

The runner needs `writ` on your `PATH` — install it from a
[release tarball](https://github.com/writ-lang/writ/releases) or with
`make install-writ` in a writ checkout:

```sh
./run-tests.sh            # every scenario
./run-tests.sh river      # one, by name
./run-tests.sh --list     # the names
WRIT=/path/to/writ ./run-tests.sh
```

Or with nothing installed, using the image writ builds:

```sh
cd ../writ && make image && cd -     # tags writ:latest
docker compose up                    # every scenario
docker compose run --rm river        # one
```

Many `writ check` runs **exit 1** on purpose: a failing property is a finding
(a blunder, a deadlock), and the tests assert it.

## The scenarios

**Puzzles**

| | The question | writ's answer |
|---|---|---|
| [`river/`](river/) | Can the farmer get everything across? | Yes — the crossing is printed. But one careless first move makes it impossible. |
| [`island/`](island/) | Can every islander be classified as knight or knave? | No: "I am a knave" fits neither, and the rules declare a gap there. |
| [`queens/`](queens/) | Eight queens, none attacking. | Solvable; all 92 boards appear as dead ends. |

**Systems and institutions**

| | The question | writ's answer |
|---|---|---|
| [`jobshop-possible/`](jobshop-possible/) | Can three jobs on three blocking machines all finish? | Yes — but three moves can deadlock the shop. |
| [`jobshop-best/`](jobshop-best/) | What is the shortest schedule? | 5 ticks: `done-by-4` fails, `done-by-5` holds. |
| [`on-call-rota/`](on-call-rota/) | Does a valid on-call rota exist, and what does the policy not say? | Ten exist, and writ prints one. Add one kind rule and none does, unless a question the policy never answered is answered yes. |
| [`entitlement-problems/`](entitlement-problems/) | Can a requester approve, a developer edit CloudTrail, a leaver keep admin? | Yes, each through steps that are fine one at a time. writ names who, and through which grants. |
| [`expense-approval/`](expense-approval/) | Can a large expense be paid without two independent approvals? | Yes, when one person holds both roles: "two signatures" counted boxes, not people. |
| [`agent-guardrails/`](agent-guardrails/) | Can an AI agent's secret leave the machine with no human saying yes? | Not under v1. Add a "read-only" web-fetch and it can, in three moves, none of them human's. |
| [`deployment/`](deployment/) | Is production ever dark mid-rollout, and can the fleet always roll back? | Never dark behind a health gate; but after the migration, the runbook's rollback is unreachable for good. |
| [`payments/`](payments/) | Can a lost reply and a retry charge a customer twice? | Without an idempotency key, in six steps, each correct where it stood. The key also stops a late capture beating a cancellation. |
| [`config-space/`](config-space/) | Can the admin operations reach a flag combination the product forbids? | All 64 combinations walked: only if steps are done in one order. A release adding a flag loses the guarantee in one move. |
| [`two-phase-commit/`](two-phase-commit/) | Do the parties agree, and must they decide? | Always agree; a coordinator crash can strand them. Variants price a timeout and a lossy network. |

**Design, judgement and change**

| | The question | writ's answer |
|---|---|---|
| [`arch/`](arch/) | Which architectures satisfy a brief, from a bank of components? | 96 of 2,916 — and the one thing the brief forgot to say. |
| [`timetable/`](timetable/) | Is the week a constraint solver produced any good? | Valid, but two rules fail: sport first thing, and no time to change after it. |
| [`db-migration-problems/`](db-migration-problems/) | Is this schema migration safe at every instant, mid-rollout included? | The safe plans pass; the shortcuts fail with the breaking step. |

The runner also covers `writ control` and `writ compare --git`. Shared
vocabularies — scheduling, chess, architecture — live in
[`libraries/`](libraries/).

Most scenarios also re-ask their questions through writ's rules engine
(`.rules` files), and a cross-check compares the two answers: two independent
implementations of the same question.

## Adding a scenario

1. Create `<name>/<name>.writ` and `<name>/<name>.claims`. Put shared
   vocabulary in `libraries/`.
2. Add a `<name>()` function to `run-tests.sh` that runs `writ check` and
   asserts the answers (`has`, `lacks`, `near`, `exit_is`), and register it in
   the scenario list.
3. Name every move: the solution path prints move names, so named moves read
   as prose while unnamed ones print as `#0`, `#8`.
4. Optionally add a `.rules` file and a cross-check. A disagreement between the
   two answers is a bug in one of them — never a number to adjust.
