# Expense approval: two signatures, one person

An expense above the approval threshold needs two approvals: the requester's
manager, then finance. The rule exists so that no one person can move money
alone. Every form, screen and audit report enforces it as "two approvals",
meaning both signature boxes are filled.

That is not the same rule. Bob is Ann's manager and also finance's deputy
approver, which is common in a small team. He can fill both boxes. The
expense is paid on two signatures, and one person decided it.

## The process

```
draft ──submit──▶ submitted ──manager signs──▶ ──finance signs──▶ ──pay──▶ paid
                    │   ▲
              reject│   │resubmit           (signatures are thrown away)
                    ▼   │
                  rejected

cancel: from draft, submitted or rejected, at any point before payment
change-bank-account: while submitted; throws away every signature so far
```

## Counting becomes naming

The model has no amounts. The rules only ever ask which side of the threshold
an amount falls on, so the expense carries a **band**, `small` or `large`, and
the process branches on that. Nothing is lost: no rule here would answer
differently for $12,000 than for $10,001. If a rule distinguished a middle
band (say, manager-only approval up to $5,000), the band would get a third
member. The model would still not do arithmetic.

## The model

[`expense-approval.writ`](expense-approval.writ) follows one large expense,
`e1`, filed by `ann`. Its stage, its bank account and two signature slots
(`manager-sign`, `finance-sign`) are what change. Three rules are laws,
reported whenever any reachable situation breaks them:

- `no-self-approval`: nobody signs their own expense;
- `finance-after-manager`: the finance slot is never filled before the
  manager's;
- `two-for-large`: a large expense is paid only on two independent
  approvals.

"Independent" is written in [`expense-approval.lib.writ`](expense-approval.lib.writ)
as both slots filled *and* different:

```lisp
(form (two-independent E)
  (and (defined E.manager-sign)
       (defined E.finance-sign)
       (differ E.manager-sign E.finance-sign)))
```

`differ` on its own would not do: it is true when either slot is empty.

The signing moves are one per person and slot (`bob-approves-as-manager`,
`bob-approves-for-finance`, `cat-approves-for-finance`, and
`ann-approves-as-manager`, which its guard always refuses). Changing the bank
account is one move with three effects that happen at once: the new account,
and both signatures thrown away, because the approvers approved paying the
*old* account.

The two files differ in `pay`. The safe process pays a large expense on
`two-independent`. [`expense-approval-shortcut.writ`](expense-approval-shortcut.writ)
pays it on both slots being filled.

## What writ answers

Both processes are asked the questions in
[`expense-approval.claims`](expense-approval.claims). The safe one, exit 0:

```
states: 21   edges: 34
…
holds  payable
  "a large expense can be paid"
  witness:  1. submit                     → #1   e1.stage: draft → submitted
            2. bob-approves-as-manager    → #3   e1.manager-sign: ∅ → bob
            3. cat-approves-for-finance   → #7   e1.finance-sign: ∅ → cat
            4. pay                        → #14   e1.stage: submitted → paid
holds  never-on-one-person
holds  always-settleable
holds  settles
  assuming fair: pay, cancel
certified: every answer re-derived from the model (writ-cert)
```

The shortcut, exit 1:

```
equation two-for-large
  …
  violated in 2 reachable situations   witness: 1. submit 2. bob-approves-as-manager 3. bob-approves-for-finance 4. pay → #13
…
fails  never-on-one-person
  "a large expense is never paid on one person's say-so"
  witness:  1. submit                     → #1   e1.stage: draft → submitted
            2. bob-approves-as-manager    → #3   e1.manager-sign: ∅ → bob
            3. bob-approves-for-finance   → #6   e1.finance-sign: ∅ → bob
            4. pay                        → #13   e1.stage: submitted → paid
holds  settles
```

Four steps, each allowed: Bob may approve as manager, Bob may approve for
finance, and the payment sees two signatures. Only one rule breaks, and the
shortcut still pays and still settles, so every question except "was it
independent" answers in its favour.

`writ derive` lists each payment with its two signatories, which is what an
auditor would ask for:

```sh
writ derive expense-approval-shortcut.writ expense-approval.rules paid-by
```

```
paid-by  (4 rows)
  13  bob  bob
  15  bob  cat
  20  bob  bob
  22  bob  cat
```

## Comparing the two

```sh
writ compare expense-approval.writ expense-approval-shortcut.writ   # exit 1
```

```
equations:   no-self-approval       preserved
             finance-after-manager  preserved
             two-for-large          LOST      witness: 1. submit 2. bob-approves-as-manager 3. bob-approves-for-finance 4. pay
properties:  payable                preserved
             never-on-one-person    LOST      witness: 1. submit 2. bob-approves-as-manager 3. bob-approves-for-finance 4. pay
             always-settleable      preserved
             settles                preserved
```

Both files declare `two-for-large`, and the shortcut breaks it, so `compare`
reports it lost with the same four steps as the property `never-on-one-person`,
which asks the same thing as a question. Either gate catches it.

## A question for whoever owns the process

In the safe process, an expense Bob has signed twice cannot be paid. That is
the point. But look at where it is stuck:

```sh
writ show expense-approval.writ --at 6
```

```
situation 6 of 21
  cells:   (e1.stage=submitted e1.bank=old-account e1.manager-sign=bob e1.finance-sign=bob)
  …
  moves:   reject → 4   cancel → 12   change-bank-account → 5
```

There is no way to withdraw one signature. The ways out are to reject the
expense, cancel it, or change its bank account, which throws the signatures
away as a side effect. Someone will find the third one. Either give finance an
explicit "withdraw my signature" step, or refuse the second signature from the
person who gave the first, at signing time rather than at payment.

## What to take away

The rule people state ("two approvals") and the rule people mean ("two
people") differ only when one person holds two roles. That happens most
where controls matter most: small teams, deputies, holiday cover. The check
that counts filled boxes passes. The check that compares names does not.

To adapt it, add your approval levels as slots and your bands as members, and
list who may sign which slot from the delegation-of-authority document, not
the org chart.

## Run it

```sh
writ check expense-approval.writ --claims expense-approval.claims           # exit 0
writ check expense-approval-shortcut.writ --claims expense-approval.claims  # exit 1
```

[`expense-approval.rules`](expense-approval.rules) encodes the same questions
for `writ derive`. `../modality-cross-check.sh` checks the two answers agree,
except `settles`, which carries a fairness assumption the rules encoding does
not model. In the rules, independence is a join (the same variable in both
slots) rather than `differ`, because a rules guard compares a path with a
constant or a variable, never with another path.
