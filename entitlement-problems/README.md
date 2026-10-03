# Entitlement problems

Three access-control designs, each with a control that reads correctly and
lets a privilege through anyway. Each directory writes the design down as a
writ model and checks every reachable configuration, not one access decision.
The safe version passes. A version with one condition removed (or, in
`scp-escalation/`, one administrative step added) fails, and writ names the
broken guarantee, the shortest sequence of grants or administrative steps
that reaches it, and who is affected.

| problem | the mistake | route to the fault |
| --- | --- | --- |
| [`separation-of-duties/`](separation-of-duties/) | checking grants against a table of group names, when the conflict lives in a role | 2 grants |
| [`scp-escalation/`](scp-escalation/) | moving an account between OUs, which swaps the SCP guardrails out from under its roles | 1–2 steps |
| [`joiner-mover-leaver/`](joiner-mover-leaver/) | offboarding through groups, which cannot see a direct assignment | 4 steps |

Start with `separation-of-duties/`. Each directory holds the two models, one
`.claims` file asked of both, a `.rules` file that answers the same questions
through `writ derive` as a cross-check (`../modality-cross-check.sh`) and
prints the privilege path as a table, and a README.

What the three have in common:

- **The mistake is never in one grant.** Every individual step is legitimate:
  joining a group, assuming a role, moving an account, offboarding a leaver.
  The privilege exists only in the composition.
- **The unsafe version still works.** People can still be given access and
  deploys still ship, so every question except "is it safe at every step"
  answers in its favour.
- **The answer is in the domain's vocabulary.** Each failing property names
  a query with `(show …)`, so the verdict says *who* (`a = alice`,
  `p = dev`, `e = prod-admin`), and each `.rules` file adds *through what*:
  the two groups, the role → account → OU path, the grant marked `direct`.

`writ compare` reports the difference between the two models of each pair as
guarantees `LOST`, exit 1. In `scp-escalation/` that is the natural gate,
because the change *is* the difference: one administrative step added. A law
both files declare and one of them breaks (`separation` in
`separation-of-duties/`) is reported `LOST` too, with the route to the
violation, so `compare` and `check` agree on every pair.

From any of the directories (here, `separation-of-duties/`):

```sh
writ check separation-of-duties.writ --claims separation-of-duties.claims           # exit 0
writ check separation-of-duties-shortcut.writ --claims separation-of-duties.claims  # exit 1
```

These are deliberately small, a few hundred situations at most, and each
README says what its reduction leaves out. A model built from a real IAM
export is the job of a bridge that reads the policies and writes the model.
That is a separate tool, not a scenario.
