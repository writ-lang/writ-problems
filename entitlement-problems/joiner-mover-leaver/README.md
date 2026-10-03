# Joiner, mover, leaver: the grant offboarding cannot see

Access follows a person through a job. They join and request access, someone
approves, and it is provisioned. Later they move to another team or leave,
and the access should go. The usual rule is "access is managed through
groups": provisioning adds the person to groups, and offboarding takes them
out. When the HR system's leaving date arrives, an automated integration
removes the person from every group the same day.

That covers every grant made through a group. It does not cover the grant
made directly, on the day the request needed something no group yet mapped
to: the administrator permission set assigned to one person by name.
Offboarding works on groups, and nothing that works on groups can see it.

## The model

[`joiner-mover-leaver.writ`](joiner-mover-leaver.writ) follows one person and
one request:

- **people**: `ada` (joins the platform team, needs production) and `bob`
  (her manager), each with a `status` (`active`, `left`) and a `team`
  (`platform`, `marketing`);
- **entitlements**: `prod-engineers`, the identity provider's production
  group, which syncs to AWS, and `prod-admin`, the administrator permission
  set assigned to Ada directly. Each records `via` (`group` or `direct`) and
  its holder;
- **the request** `ada-prod`, with its stage (`none` → `requested` →
  `approved` → `provisioned`) and its approver.

The moves are the lifecycle: `ada-requests-prod`, `bob-approves` (and
`ada-approves`, whose guard refuses her own request), `provision-ada` (grants
both entitlements), `ada-moves-to-marketing` and `ada-leaves`. The mover and
leaver steps run their own deprovisioning in the same step, as an HR-driven
SCIM integration does.

Two laws about the request hold in both plans:

- `provisioned-means-approved`: nothing is provisioned that nobody approved;
- `no-self-approval`: the approver is not the requester.

The two files differ in what deprovisioning removes. The safe plan removes
both entitlements:

```lisp
(transition ada-leaves
  (when (is ada.status active))
  (do (set ada.status left)
      (vacate prod-engineers.holder)
      (vacate prod-admin.holder)))
```

[`joiner-mover-leaver-shortcut.writ`](joiner-mover-leaver-shortcut.writ)
removes only the group membership, in both the mover and the leaver step.

## What writ answers

Both plans are asked the questions in
[`joiner-mover-leaver.claims`](joiner-mover-leaver.claims). The safe plan,
exit 0:

```
states: 16   edges: 19
regime: committing — no move can be undone
…
holds  ada-gets-access
holds  movers-lose-prod
holds  leavers-lose-everything
holds  leavers-can-be-cut-off
certified: every answer re-derived from the model (writ-cert)
```

The shortcut, exit 1:

```
fails  leavers-lose-everything
  "nobody who has left ever holds production access"
  witness:  1. ada-requests-prod   → #1   ada-prod.stage: none → requested
            2. bob-approves        → #4   ada-prod.stage: requested → approved, ada-prod.approver: ∅ → bob
            3. provision-ada       → #8   prod-engineers.holder: ∅ → ada, prod-admin.holder: ∅ → ada, ada-prod.stage: approved → provisioned
            4. ada-leaves          → #13   ada.status: active → left, prod-engineers.holder: ada → ∅
  stranded  (at state 13)
    e = prod-admin
fails  leavers-can-be-cut-off
  "from every reachable situation, a leaver can still end up holding nothing"
  stuck at: #13 (ada.status=left … prod-engineers.holder=∅ prod-admin.holder=ada …)
```

Read the witness as an incident timeline. Each line says what changed. Step 4
shows the leaver step doing its job: the group membership goes. The
administrator permission set is not in that line, because nothing removed it.
`stranded` answers the query the property names: what is left behind.

`leavers-can-be-cut-off` fails as well, which makes this a **trap**, not a
delay. At situation 13 nothing that can still run touches a direct grant. No
later batch job or second pass will fix it, because there isn't one. The
mover fails the same way (`movers-lose-prod`, ending in
`ada-moves-to-marketing`). A person who changes team keeps production admin
indefinitely, which is how privilege creep happens.

## What is left behind

[`joiner-mover-leaver.rules`](joiner-mover-leaver.rules) lists every
entitlement held by someone with no business holding it, with how it was
granted:

```sh
writ derive joiner-mover-leaver-shortcut.writ joiner-mover-leaver.rules left-behind
```

```
left-behind  (3 rows)
  12  prod-admin  direct  ada
  13  prod-admin  direct  ada
  15  prod-admin  direct  ada
```

The `via` column is the finding: every row says `direct`.

## What writ found while this was being written

The first draft of the safe plan had a second bug, and writ reported it before
the shortcut existed. `provision-ada` checked only that the request was
approved. The report, with each step's change column trimmed:

```
fails  leavers-lose-everything
  witness:  1. ada-requests-prod
            2. bob-approves
            3. ada-leaves
            4. provision-ada
  stranded  (at state 16)
    e = prod-engineers
    e = prod-admin
```

Approve, leave, *then* provision: an approval is a judgement about someone in
a role, and this one outlived the situation it judged. The fix, in both files,
is that provisioning re-checks the person (`ada.status active`,
`ada.team platform`) as well as the request. Queued provisioning jobs and
approvals that sit in a ticket for a week make this a real gap, and it is
easy to miss because every step is correct in the order the runbook shows.

## Why the law is written from the entitlement's side

"No leaver holds anything" would naturally be written about the person. writ
cannot put a type name on the right of `is`, so the property is written from
the other end of the arrow: no *entitlement* has a holder whose status is
`left`. The forms `held-by-leaver` and `held-outside-platform` in
[`joiner-mover-leaver.lib.writ`](joiner-mover-leaver.lib.writ) say so once,
for the claims and the rules alike.

## What to take away

The unsafe plan is the one the runbook describes, and it is right about every
grant it can see. The grant that survives was made outside the mechanism
offboarding relies on, for a good reason, on a busy day. The fix is either to
remove direct grants by name in every lifecycle step, as the safe plan does,
or to forbid them. Either way, the question to ask of the process is "can a
leaver still hold anything", not "did offboarding run".

To adapt it, add an entitlement per system access can live in (Vault
policies, SaaS seats, SSH keys) with its real `via`, and say in each lifecycle
step what it actually removes.

## Run it

```sh
writ check joiner-mover-leaver.writ --claims joiner-mover-leaver.claims           # exit 0
writ check joiner-mover-leaver-shortcut.writ --claims joiner-mover-leaver.claims  # exit 1
```

`../../modality-cross-check.sh` checks the `.rules` encoding against `writ
check`. Siblings: [`../separation-of-duties/`](../separation-of-duties/),
[`../scp-escalation/`](../scp-escalation/).
