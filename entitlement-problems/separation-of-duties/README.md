# Separation of duties, through a role nobody listed

The person who raises a payment must not be the person who approves it.
Everyone knows the rule, and the usual control enforces it with a table of
*toxic combinations*: pairs of groups nobody may hold together. Every access
request is checked against the table before anyone is added to a group.

The table is written in group names, but the rule is about capabilities, and
a person gets capabilities from a group's *role*. The two agree only as long
as every group whose role can raise or approve appears in the table. Nothing
checks that. When the finance team creates a group for its own leads and
gives it a role that approves invoices, the table is still correct about every
pair it lists, and a requester can now become an approver.

## The model

[`separation-of-duties.writ`](separation-of-duties.writ) has three kinds of
thing:

- a **role** is a fixed bundle of capabilities: `can-request` and
  `can-approve`;
- a **group** grants exactly one role;
- an **account** is in at most two groups, as two slots `g1` and `g2`.

Three roles: `requester`, `approver`, and `ap-lead`, which approves invoices.
Three groups grant them: `requesters`, `approvers`, `finance-leads`. Two
accounts, `alice` and `bob`, start in no group. The moves add an account to a
group (`alice-joins-requesters` fills the first slot,
`alice-also-joins-finance-leads` the second) or take it out again.

The rule is a law, written once over the account's slots and read *through*
the group to its role:

```lisp
(equation separation (not (conflicted account)))
```

where `conflicted` (in [`separation-of-duties.lib.writ`](separation-of-duties.lib.writ))
spells out every pair of slots: `g1`'s role can request and `g2`'s can approve,
and so on. A law is reported whenever any reachable situation breaks it,
whatever the moves allowed.

The two files differ in one conjunct of the grant's guard. The safe plan
refuses a grant if the table lists the pair **or** if the group's role would
complete a conflict with the other slot:

```lisp
(when (and (not (defined A.g1))
           (not (listed-pair G A.g2))
           (not (grant-conflicts G A.g2))))
```

[`separation-of-duties-shortcut.writ`](separation-of-duties-shortcut.writ)
keeps `listed-pair` and drops `grant-conflicts`. That is the check most access
tooling performs.

## What writ answers

Both plans are asked the questions in
[`separation-of-duties.claims`](separation-of-duties.claims). The safe plan,
exit 0:

```
states: 144   edges: 768
regime: reversible — 144 of 144 situations lie on cycles
…
holds  staffable
  "someone can be given the power to approve"
  witness:  1. alice-joins-approvers   → #2   alice.g1: ∅ → approvers
holds  no-conflict
  "nobody ever holds both halves of a payment"
holds  revocable
  "from every reachable situation, everyone can still be taken out of every group"
certified: every answer re-derived from the model (writ-cert)
```

The shortcut, exit 1:

```
states: 196   edges: 1120
…
equation separation
  …
  violated in 52 reachable situations   witness: 1. alice-joins-requesters 2. alice-also-joins-finance-leads → #14
…
fails  no-conflict
  "nobody ever holds both halves of a payment"
  witness:  1. alice-joins-requesters           → #1   alice.g1: ∅ → requesters
            2. alice-also-joins-finance-leads   → #14   alice.g2: ∅ → finance-leads
  conflicted-accounts  (at state 14)
    a = alice
```

Two grants, each of which passes the table. The first is what Alice's job
needs. The second is a group whose name says nothing about approving. The
`conflicted-accounts` line answers the query the property names with
`(show …)`: who is in the bad situation.

The shortcut still lets anyone be made an approver and still lets everyone be
taken out of every group, so `staffable` and `revocable` hold for both. Only
the safety question tells them apart.

## Who, and through which grants

A law's subject is one account at a time, and a query's variables cannot be
compared with each other. So "which two groups" is a join, and joins are what
[`separation-of-duties.rules`](separation-of-duties.rules) is for:

```sh
writ derive separation-of-duties-shortcut.writ separation-of-duties.rules conflict
```

```
conflict  (56 rows)
  14  alice  requesters  finance-leads
  29  alice  requesters  finance-leads
  57  bob  requesters  finance-leads
  …
```

Every row is the same pair. `requesters` + `approvers`, the pair the table
lists, never appears. The first column is a situation number, and
`writ show` reads any of them back:

```sh
writ show separation-of-duties-shortcut.writ --at 14
```

```
situation 14 of 196
  cells:   (alice.g1=requesters bob.g1=∅ alice.g2=finance-leads bob.g2=∅)
  route:   1. alice-joins-requesters
           2. alice-also-joins-finance-leads
  moves:   … alice-leaves-first-group → 6   alice-leaves-second-group → 1
```

That is the violation stated in the domain's own terms: the account, the two
grants, the order they were made in, and the two moves that would undo it.

## Why two slots

Two slots per account is enough to show the finding, and it keeps the space
small (196 situations). The ceiling is the model's, not writ's: a third slot
is a third `maybe` arrow, and `conflicted` gains the pairs that involve it.

The slots are there because writ cannot compare two bound variables. "No
account holds two groups that conflict" cannot be a `some … some …` law. It
is a law rooted at **one** account over a bounded number of slots.

## What to take away

The mistake is never in one grant. Each of Alice's two grants is legitimate on
its own, and the control that checks grants against a list of group names
passed both. The conflict exists only in the composition, through a role that
was added later by someone else. A check that reads what a group *grants*
catches it on the second grant. A check that reads what a group is *called*
cannot.

To adapt it, list your roles' capabilities from the policy documents rather
than from group names, and add a slot if your people commonly hold three
groups.

## Run it

```sh
writ check separation-of-duties.writ --claims separation-of-duties.claims           # exit 0
writ check separation-of-duties-shortcut.writ --claims separation-of-duties.claims  # exit 1
```

[`separation-of-duties.rules`](separation-of-duties.rules) also encodes the
three properties for `writ derive`. `../../modality-cross-check.sh` checks the
two answers agree. Siblings: [`../scp-escalation/`](../scp-escalation/),
[`../joiner-mover-leaver/`](../joiner-mover-leaver/).
