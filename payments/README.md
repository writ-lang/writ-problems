# Payments: the reply that never comes

A shop takes payment in two steps: **authorize** the card, which reserves the
money, then **capture**, which takes it. The capture is a request to a payment
processor, and the processor's reply can be lost: a timeout, a dropped
connection, a load balancer restart. The shop then does not know whether the
money was taken, so it does what every integration does. It waits, and it
asks again.

If the first request did land, the retry is a second capture. The customer is
charged twice, and nothing on the shop's side looks wrong: it received one
reply, recorded one capture, and shipped one order. The usual cure is an
**idempotency key**: every request carries a key, and the processor answers a
repeated key with the original reply instead of acting again.

## The model

[`payments.writ`](payments.writ) follows one order:

- the shop's view, `o`: its `stage` (`placed`, `authorized`, `captured`,
  `settled`, `refunded`, `cancelled`) and whether it has shipped;
- the wire, `net`: a capture `request` on its way out, a `reply` on its way
  back, and a `void` (more below);
- the processor's view, `proc`: how many times it has taken the money
  (`none`, `one`, `two`), whether it has refunded, and the keys it has
  already honoured (`seen`).

The processor counts captures, not money. The questions are about how many
times the money was taken, so a three-member type is the honest size, and
`two` is the bug. A refund question that needed partial amounts would add a
band (`none`, `partial`, `full`), still not a number.

The shop's moves are `authorize`, `send-capture`, `receive-reply`, `settle`,
`ship`, `refund` and `cancel`. `send-capture` is the first attempt and every
retry: whenever the shop is waiting on a capture, with nothing out and
nothing back, it sends one. The network's move is `lose-reply`.

The processor's moves are where the two files differ. With the key
(`payments.writ`), `capture` records `k1`, and a request carrying a seen key
gets `replay-reply`: the original answer, no second capture.
[`payments-shortcut.writ`](payments-shortcut.writ) sends no key, so the
processor has nothing to record or check, and `capture-again` takes the money
a second time.

## What writ answers

The questions are in [`payments.claims`](payments.claims). With the key,
exit 0:

```
holds  settles
  "a payment can settle"
holds  never-double
  "the customer is never charged twice"
holds  never-charged-for-nothing
  "once the wire is quiet, a cancelled order never leaves the customer charged"
holds  always-terminal
  "from everywhere, the order can still reach an end"
certified: every answer re-derived from the model (writ-cert)
```

Without it, exit 1:

```
fails  never-double
  "the customer is never charged twice"
  witness:  1. authorize       → #1   o.stage: placed → authorized
            2. send-capture    → #3   net.request: no → yes
            3. capture         → #5   net.request: yes → no, net.reply: no → yes, proc.captures: none → one
            4. lose-reply      → #8   net.reply: yes → no
            5. send-capture    → #13   net.request: no → yes
            6. capture-again   → #16   net.request: yes → no, net.reply: no → yes, proc.captures: one → two
```

Read it as the support ticket it becomes. The shop asked for the money, the
processor took it, the answer got lost, the shop asked again, and the
processor took it again. Every step is correct from where it stands. No
single component misbehaved.

[`payments.rules`](payments.rules) shows where those double charges end up,
as the shop sees the order:

```sh
writ derive payments-shortcut.writ payments.rules double-charged
```

```
double-charged  (13 rows)
  22  authorized  no
  …
  29  settled  no
  30  captured  yes
  31  refunded  no
  …
  34  settled  yes
  35  cancelled  no
```

Settled and shipped, refunded (one capture given back, one kept), cancelled:
the double charge appears in every stage the shop has, and nothing marks it.
It reaches support as a complaint, not as an alert.

## The cancellation that loses the race

The shortcut fails a second question:

```
fails  never-charged-for-nothing
  "once the wire is quiet, a cancelled order never leaves the customer charged"
  witness:  1. authorize            → #1   o.stage: placed → authorized
            2. send-capture         → #3   net.request: no → yes
            3. cancel               → #5   o.stage: authorized → cancelled, net.void: no → yes
            4. void-uncaptured      → #8   net.void: yes → no
            5. capture              → #13   net.request: yes → no, net.reply: no → yes, proc.captures: none → one
            6. discard-late-reply   → #19   net.reply: yes → no
```

The shop cancels while its capture request is still on the wire, and sends a
void. The void arrives first, finds nothing to refund, and is done. Then the
capture lands. With a key, the void marks `k1` as used, so the late capture is
answered with a replay and takes nothing. Without a key there is nothing to
mark. The key is not only a retry mechanism: it is what lets a cancellation
refer to a request that has not arrived yet.

"Once the wire is quiet" is part of the question on purpose. While a request
or a void is still in flight, the charge is unresolved, not wrong. The
property asks about the situations where nothing more will arrive.

## What writ found while this was being written

The first draft of the safe file had no void. `cancel` was allowed whenever
the shop had not captured, because from its own records no money had moved.
writ failed it, key and all (change columns trimmed):

```
fails  never-charged-for-nothing
  witness:  1. authorize
            2. send-capture
            3. cancel
            4. capture
```

The shop's record says "not captured" in two different situations: nothing
was sent, or something was sent and nothing came back. Only the first is safe
to cancel on. The fix, in both files, is that cancelling also voids at the
processor. With the key the void is enough; without it, as above, it is not.

## What to take away

At-least-once delivery plus a non-idempotent operation means sometimes
twice, and testing rarely shows it, because the lost reply is rare and the
double charge looks like a normal order. The question that catches it,
"never two captures", is about the processor's state, which the shop never
sees. That is why it belongs in a model.

The shortcut still settles and still reaches an end. Unlike the migration
problems, it is not even faster. It skips no wait. It just leaves out one
field on the request.

## Run it

```sh
writ check payments.writ --claims payments.claims           # exit 0
writ check payments-shortcut.writ --claims payments.claims  # exit 1
writ compare payments.writ payments-shortcut.writ           # exit 1: both guarantees LOST
```

`../modality-cross-check.sh` checks the `.rules` encoding against `writ check`.
`../two-phase-commit/` has the same lossy-wire idiom, applied to agreement
rather than money.
