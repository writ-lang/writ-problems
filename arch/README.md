# Designing an architecture, by exhaustion

*50TB of files — mostly PDFs. Classify them, configurably and re-runnably. Make
what the files contain available to AI. Surface it in the CRM that already
exists.*

That is a brief, not a specification, and it is the kind of thing an architect
is normally left to answer by judgement. This scenario answers it by
**enumeration**: a bank of nineteen components, seven stages to fill, the
brief's requirements as guards, and `writ check` walking every architecture the
constraints permit.

It is [`queens/`](../queens/) one level up. A queen is placed on a square; a
stage is filled by a component. A cursor walks the stages in build order, so the
moves index stages rather than permutations, and a finished architecture is a
dead end because a filled ladder has no move left. The board lives next door in
[`../libraries/arch.lib.writ`](../libraries/arch.lib.writ) — vocabulary, not
behaviour — and this file is only the parts, the brief, and what may happen.

## What `writ check` answers

```
states: 184   edges: 185
gaps: 1
  pdf-kind-unknown — "the brief is silent: are the 50TB of PDFs digital-native
  or scanned? extract choice depends on it" (min 2 moves)
dead ends: 96
holds  realisable
  witness:  1. hold-object-store   2. enum-event-stream  3. ext-ocr
            4. cls-rules  5. cat-lakehouse  6. ai-vector-index  7. crm-api-push
holds  no-dead-end
fails  rerun-is-affordable
  witness:  1. hold-object-store   2. enum-event-stream
            3. ext-llm-vision      4. cls-rules
holds  crm-stays-loose
```

**A. 96 architectures satisfy the brief**, out of 2,916 raw combinations — each
a dead end, and `holds realisable` prints one of them as its witness, stage by
stage. The constraints did the cutting: `nas` cannot hold 50TB, a bucket listing
cannot enumerate it, a plain PDF library cannot read a scan, and `direct-db`
couples to the CRM at the wrong layer.

**B. `holds no-dead-end`** — no early choice strands the build half-finished.
Worth asking separately: a bank *can* offer a part whose own dependencies can
never then be met, and `live` is what finds it.

**C. One gap.** The brief never says whether the PDFs are digital-native or
scanned, and that single unstated fact decides whether a whole class of extract
component is admissible at all. `writ` does not guess it, does not average over
it, and does not quietly pick one: it reports the hole and where it is reached.
**This is the question to put back to whoever wrote the brief**, produced
mechanically rather than by intuition.

**D. `fails rerun-is-affordable` — the finding.** Read its witness:
`object-store → event-stream → llm-vision → rules-engine`. Every stated
requirement is met. But `llm-vision` does not persist what it extracts, so
"re-run the classification" silently means re-running vision inference over the
whole 50TB. **88 of the 184 situations carry that defect, and 48 of the 96
finished designs** — exactly half the answer set looks correct and is not.

The requirement it violates is one the brief never wrote down, which is the
point: `configurably, be able to rerun` is a sentence about the *classify*
stage, and it constrains the *extract* stage. Two stages apart, and nothing in
the brief connects them.

**E. `holds crm-stays-loose`** — an enforced constraint, verified rather than
assumed. `needs-loose` prunes `direct-db` in the guard, and the property
confirms the guard is doing what it claims.

## Reading the design out

A finished architecture is data, not prose:

```console
$ writ derive arch.writ arch.rules "(blueprint 183 K C)"
blueprint  (7 rows)
  183  hold       object-store        183  catalog    doc-store
  183  enumerate  db-index            183  serve-ai   dataset-export
  183  extract    llm-vision          183  classify   ml-model
                                      183  surface    ipaas
```

**A `.claims` query cannot do this**, and the failure is silent. Writing
`(query blueprint (where (k cap) (c comp)) (is k.chosen c))` answers **zero
rows** — the right of `is` is a literal or another chain, never a variable to
bind (§10.2). Reading a mutable cell needs the rules engine, where `holds`
binds its guard's free variables over a named situation (interrogator §2):

```lisp
(rule (choice S K C) (situation S) (holds S (is K.chosen C)))
```

## Why 184 situations for 96 designs

Because ordered decisions make the space the set of *prefixes* of a finished
configuration, not the product of every cell. Seven stages admitting 1, 2, 2, 2,
3, 2, 2 components give `1·2·2·2·3·2·2 = 96` designs and
`1+1+2+4+8+24+48+96 = 184` situations — the cost law in
[writ's README](https://github.com/writ-lang/writ#what-an-answer-costs), exactly.

Which means **tightening the brief makes this cheaper, not dearer**. Forbid one
more coupling and it is 144 designs in 232 situations; demand one more property
of the extract stage and it is 48 in 94. The bank can grow to hundreds of parts
for nothing; only the *answer set* costs.

## What this scenario does not claim

The component attributes — which parts survive 50TB, which are reproducible,
which persist their output — were **written by hand, and they are the model's
weakest link**. `writ` proves what follows from them exhaustively and will do so
just as faithfully if they are wrong. The mechanism is the contribution here;
the catalogue is a sketch, and a real one is a curation problem, not a language
problem.
