# An OU move that leaves the guardrails behind

In AWS Organizations, a *service control policy* (SCP) is attached to an
organizational unit (OU) and caps what any role in that OU's accounts can do.
It never grants anything; it only takes away. Teams lean on that: the roles
inside a production account are broad, because the production OU's SCP denies
the few things nobody should do there, like switching off CloudTrail.

So the guardrail belongs to the OU, not to the account. Move the account to
another OU, as a reorganisation does, and it leaves its guardrails behind and
picks up whatever the new OU carries. No role changes and no IAM policy is
edited. The change is drag-and-drop in the console, reviewed as an
organizational chore.

## Before and after

`writ compare` checks one set of questions against both versions of the
organization:

```sh
writ compare scp-escalation.writ scp-escalation-restructured.writ   # exit 1
```

```
equations:
properties:  dev-can-deploy              preserved
             dev-never-edits-cloudtrail  LOST      witness: 1. dev-assumes-power 2. move-prod-to-workloads
             sec-can-always-audit        LOST      witness: 1. move-prod-to-workloads
```

Deploying still works. Two guarantees are gone, each with the shortest route to
where it fails:

- **Developers can now modify CloudTrail.** An engineer signed in as `power`
  (PowerUserAccess, which includes CloudTrail) was held back only by the
  production OU's SCP. After the move, nothing holds them back.
- **The security team is locked out of production's audit trail.** No sign-in
  is needed for this one: the move alone does it, and nothing moves the account
  back.

The properties come from [`scp-escalation.claims`](scp-escalation.claims),
beside the original. `compare` reads the questions from there and asks them of
both files. A `LOST` line exits 1, so the comparison is a gate a pipeline can
run on every change to the organization model.

## The model, and what it leaves out

[`scp-escalation.writ`](scp-escalation.writ) keeps only what the three
questions need:

- **Three actions**: `prod-write`, `cloudtrail-edit`, `audit-read`.
- **OUs** as one deny flag per action. `production` denies CloudTrail edits.
  `security` denies production writes. `workloads` is new: its SCPs were copied
  from the sandbox template, which has no CloudTrail guardrail and denies access
  from outside the unit (the security team's read is cross-account).
- **Accounts**: `prod-acct` in `production`, `sec-acct` in `security`. Which OU
  an account sits in is the one thing an administrator changes here.
- **Roles**, each living in one account with fixed grants: `deploy`, `power`,
  `audit-reader`, all in `prod-acct`.
- **Principals** `dev` and `sec`, and the role each is signed in as, if any.

Who may assume which role is listed rather than computed: one move per trust
relationship (`dev-assumes-deploy`, `dev-assumes-power`,
`sec-assumes-audit-reader`), plus signing out.

AWS evaluation is reduced to one conjunction, in
[`scp-escalation.lib.writ`](scp-escalation.lib.writ): the role grants the
action **and** the role's account's OU does not deny it.

```lisp
(form (edits-cloudtrail P)
  (and (is P.assumed.cloudtrail-edit yes)
       (is P.assumed.in.ou.deny-cloudtrail-edit no)))
```

Left out: permission boundaries, resource policies, session policies, explicit
denies in identity policies, nested OUs and SCP inheritance, conditions, and
every action not named above. Each would be another conjunct in those forms.
A reader whose question depends on them needs a bridge that reads real policy
and writes the model. That is a separate tool, not this scenario.

[`scp-escalation-restructured.writ`](scp-escalation-restructured.writ) is the
same file plus one transition:

```lisp
(transition move-prod-to-workloads
  (when (is prod-acct.ou production))
  (do (set prod-acct.ou workloads)))
```

## Checking each version

The original, exit 0:

```
states: 6   edges: 14
…
holds  dev-can-deploy
holds  dev-never-edits-cloudtrail
holds  sec-can-always-audit
```

The restructured one, exit 1:

```
states: 12   edges: 34
…
fails  dev-never-edits-cloudtrail
  "developers cannot modify CloudTrail"
  witness:  1. dev-assumes-power        → #2   dev.assumed: ∅ → power
            2. move-prod-to-workloads   → #8   prod-acct.ou: production → workloads
  cloudtrail-editors  (at state 8)
    p = dev
fails  sec-can-always-audit
  "whatever has happened, the security team can still get to production's audit trail"
  stuck at: #4 (prod-acct.ou=workloads sec-acct.ou=security dev.assumed=∅ sec.assumed=∅)
  witness:  1. move-prod-to-workloads   → #4   prod-acct.ou: production → workloads
  audit-readers  (at state 4)
```

The CloudTrail witness happens in the order it would in practice. An engineer
is already signed in as `power` when the account moves, and their session
gains the capability without them doing anything. `audit-readers` at state 4
is empty: once the account has moved, nobody can read the trail, now or later.

## The privilege path

[`scp-escalation.rules`](scp-escalation.rules) lays out every effective
CloudTrail edit as a path: the principal, the role it assumed, the account the
role lives in, and the OU whose SCP failed to stop it.

```sh
writ derive scp-escalation-restructured.writ scp-escalation.rules escalation
```

```
escalation  (2 rows)
  8  dev  power  prod-acct  workloads
  11  dev  power  prod-acct  workloads
```

Read across a row: dev → power → prod-acct → workloads. The guardrail was the
last hop, and the move replaced it.

## What to take away

Guardrails that live on a container travel with the container, not with what
is in it. A review of the IAM change finds nothing, because there is no IAM
change. A review of the OU move sees a chore. Neither file says which
guarantees depended on which OU. Asking the same questions before and after
does.

`check` on the new model fails too, but `compare` is the gate that fits the
change. Its subject is a difference: it says which guarantees the
reorganisation took away, and keeps the ones it did not.

## Run it

```sh
writ check scp-escalation.writ --claims scp-escalation.claims                # exit 0
writ check scp-escalation-restructured.writ --claims scp-escalation.claims   # exit 1
writ compare scp-escalation.writ scp-escalation-restructured.writ            # exit 1
```

With the organization model under git, `writ compare --git HEAD~1 HEAD
scp-escalation.writ` asks the same questions across two commits.
`../../modality-cross-check.sh` checks the `.rules` encoding against `writ
check`. Siblings: [`../separation-of-duties/`](../separation-of-duties/),
[`../joiner-mover-leaver/`](../joiner-mover-leaver/).
