# A claim about common ownership, and its falsifier

*One mill. Seven situations. A claim that forbids something, and the three-move
route to the thing it forbids.*

## The claim, in a form that can be wrong

Popper's demarcation: a claim earns the right to be tested by **forbidding**
something. The class of its potential falsifiers must be non-empty — there has
to be an observable state of affairs whose occurrence would sink it.

Start with the version usually said out loud:

> *Communism is the end of exploitation; where exploitation persists, communism
> has not been achieved.*

This forbids nothing. Any situation you exhibit is met by withdrawing the
antecedent — the conventionalist twist, Popper's name for the move that saves a
theory by making it unsinkable. Nothing below tests that sentence, because
nothing can.

Here is the same doctrine stated so that it has content:

> **Once the means of production are held in common, no surplus goes to a party
> outside the work, by the decision of a party outside the work.**

That forbids a definite arrangement. In Writ a prohibition is `never`, so the
claim goes into [`gotha.claims`](gotha.claims) verbatim:

```lisp
(property no-exploitation
  "once the mill is common, no surplus goes to a party outside the work by the decision of a party outside the work"
  (never (and (is loom-house.title common)
              (is loom-house.surplus-to.produces no)
              (is loom-house.directed-by.produces no))))
```

`writ` searches every reachable situation for one that satisfies the forbidden
guard. If it finds one it prints the route to it, and the route is the
falsifier.

**The criterion is taken at its strongest**, which is what makes the answer
worth having. "No non-producer ever *receives* any of the surplus" would be
refuted by paying a bookkeeper — and refuting it would prove nothing, since the
Gotha Programme provides for exactly such payments and nobody disputes that it
does. "No non-producer ever *decides*" would be refuted by appointing a manager,
which is asked for just as plainly. What is forbidden here is the **conjunction**
— gone outside the work, *by a decision taken* outside the work — which is what
the word means when it is used of a proprietor. Refuted in that form, it is
refuted in the weaker forms too.

## The model

Three arrows where ordinary speech has one word. That is the whole of the
design, and it is fixed in the schema before any move is written, so the finding
cannot have been built into the moves:

| arrow | what it holds |
| --- | --- |
| `worked-by` | who does the work — `fixed`, a fact no move rewrites |
| `directed-by` | whose decision disposes of what the work produces |
| `surplus-to` | where this period's surplus actually went |

`title` is a fourth arrow, and it is the only one "abolish private property"
names.

Five moves, each one asked for by the programme itself:

| move | whose instruction |
| --- | --- |
| `expropriate` | *Manifesto* §II — "Abolition of private property" |
| `distribute` | *Gotha* — the remainder, after the deductions, to the producers |
| `appoint-board` | *Gotha* — the deductions are administered by someone; Lenin, April 1918, on one-man management |
| `fund-administration` | *Gotha* — "the general costs of administration not belonging to production", the second deduction from the total product |
| `recall-board` | the Paris Commune, and *State and Revolution* — every official elective and revocable at any time |

Not one of them is a betrayal, a degeneration or an outside attack. They are the
programme being carried out. And the expropriation is granted **in full and at
once** — title to the commons, direction to the weavers, the proprietor's claim
extinguished, with no move back. No restoration, no sabotage, no invasion. If
the claim fails here it does not fail for want of a revolution.

## What `writ` answers

```console
$ writ check gotha.writ --claims gotha.claims
states: 7   edges: 13
gaps: none
dead ends: none
equation surplus-to-producers
  can be broken by: expropriate, distribute, fund-administration   (acknowledge in claims)
  violated in 3 reachable situations   witness:
holds  expropriation-succeeds
  witness:  1. expropriate
            2. distribute
fails  no-exploitation
  witness:  1. expropriate
            2. appoint-board
            3. fund-administration
holds  exploitation-endable
non-producers  (at state 0)
  c = proprietor
  c = board
$ echo $?
1
```

**`holds expropriation-succeeds`** comes first for a reason. The antecedent is
reached: the mill really does become common and the surplus really does reach
the hands that worked it, in two moves, and `writ` prints them. A model in which
the revolution failed would refute nothing at all.

**`fails no-exploitation`** is the refutation, and the witness is the falsifier,
three moves long:

1. **`expropriate`** — the mill passes to the commons and the weavers direct it.
   The claim's antecedent is now true.
2. **`appoint-board`** — Gotha's deductions do not administer themselves, so the
   commune appoints a body to make them. This is a transfer of the *direction*,
   not of the bookkeeping alone: a body that may not decide cannot make a
   deduction.
3. **`fund-administration`** — the board makes Marx's own second deduction.

The resulting situation: `title = common`, and a surplus that has gone to a
party which does not work the mill, by the decision of a party which does not
work the mill. The claim said that cannot happen. It happens in three moves,
none of which anyone has to smuggle in.

**The programme's own law is broken on both sides of the revolution.**
`surplus-to-producers` — `(= mill.surplus-to mill.worked-by)` — is violated in 3
of the 7 situations. The witness printed for it is *empty*: zero moves, the
initial situation, the old regime, which is what the law was written to condemn.
The other two are on the far side of the expropriation.

## What the refutation does not establish

**`holds exploitation-endable`**, and it is in the claims file precisely so the
finding cannot be stretched. From *every* reachable situation the surplus can
still be returned to the hands that worked the mill — `recall-board` is in the
file, unguarded, available to anyone at any time. What the model exhibits is a
**permitted** condition, not a trap. "The claim is false" is what was proved.
"And therefore it is hopeless" is a different claim, and this model refutes it
too.

**Seven situations are not a century.** The model settles what the *claim*
entails, not what any country did. Its worth is that the claim was stated so it
could have survived, and did not — for a reason visible in the schema rather
than in a history book.

**Refuting a claim is not refuting a programme.** What the refutation locates is
a gap in an inference, and the gap is exact: "ownership" was three arrows, and
`expropriate` moves one of them. The claim that would have done the work is not
about title at all —

> *once the means of production are held in common **and direction stays with
> those who work them**, no surplus goes to a party outside the work.*

— which is a claim about `directed-by`, forbids something in its own right, and
is not refuted by anything here. Whether an economy can hold direction with the
producers while still making Gotha's deductions is the next model, and it is a
harder question than the one this file answers. The finding is that the first
claim does not imply it, and never did.

## The falsifiers, enumerated

`no-exploitation` is a `never`, so its potential-falsifier set is a thing the
tool can print rather than argue about
([`gotha.rules`](gotha.rules), checked against `writ check` by
[`cross-check.sh`](cross-check.sh) beside it):

```console
$ writ derive gotha.writ gotha.rules no-exploitation
no-exploitation  (1 row)
  5
```

One situation out of seven. A claim with exactly one potential falsifier in its
world is about as testable as a claim gets — and it is occupied.
