# Designing an architecture, by exhaustion

The brief: classify 50TB of mostly-PDF files, re-runnably; make their contents
available to AI; surface them in an existing CRM. Which architectures built from
a bank of nineteen components satisfy it? [`arch.writ`](arch.writ) fills seven
stages in build order, one component each, with the brief's requirements as
guards, so every finished design is a dead end. The vocabulary lives in
[`../libraries/arch.lib.writ`](../libraries/arch.lib.writ). For the full
toolset version, see [`writ-arch`](https://github.com/writ-lang/writ-arch).

```console
$ writ check arch.writ --claims arch.claims
states: 184   edges: 185
regime: committing — no move can be undone
gaps: 1
  pdf-kind-unknown — "the brief is silent: are the 50TB of PDFs digital-native or scanned? extract choice depends on it" (min 2 moves)
dead ends: 96
…
fails  rerun-is-affordable
  "re-runnable classification implies persisted text"
  witness:  1. hold-object-store   → #1   hold.chosen: ∅ → object-store, cur.at: hold → enumerate
            2. enum-event-stream   → #2   enumerate.chosen: ∅ → event-stream, cur.at: enumerate → extract
            3. ext-llm-vision      → #5   extract.chosen: ∅ → llm-vision, cur.at: extract → classify
            4. cls-rules           → #10   classify.chosen: ∅ → rules-engine, cur.at: classify → catalog
…
```

96 designs satisfy the brief, out of 2,916 combinations; `realisable`,
`no-dead-end` and `crm-stays-loose` hold. The gap is the question to put back
to the brief's author: scanned or digital PDFs decide which extractors qualify.
The finding is `rerun-is-affordable`: `llm-vision` keeps no extracted text, so
re-running classification means re-running vision over 50TB. 88 of the 184
situations carry the defect (the check exits 1), and the brief never connected
the classify stage to the extract one.
`writ derive arch.writ arch.rules "(blueprint 183 K C)"` reads a design out.
The component attributes are hand-written; writ proves what follows from them.
