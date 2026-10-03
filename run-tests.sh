#!/bin/sh
# Copyright (C) 2026 Alex Kunich
# SPDX-License-Identifier: AGPL-3.0-or-later
# End-to-end tests: SOLVE the Prologue puzzles with `writ` and check the answers
# — including the SOLUTION PATH `writ` prints (the witness under a holding
# `possible`). Each `writ check` exits 1 because it HAS findings to report — that
# is the correct outcome here (a blunder IS possible; the census ISN'T
# completable) — so the tests assert exit 1.
#
# Usage:  run-tests.sh [NAME | NUMBER | all | list]   (default: all)
#   run-tests.sh list      # the numbered menu
#   run-tests.sh 3         # run test #3 by number
#   run-tests.sh river     # run one by name
# `writ` is taken from $WRIT (default: the one on PATH).
set -u

here=$(cd "$(dirname "$0")" && pwd)
WRIT=${WRIT:-writ}
pass=0
fail=0

ok() {
  pass=$((pass + 1))
  printf '  [ok]   %s\n' "$1"
}
bad() {
  fail=$((fail + 1))
  printf '  [FAIL] %s\n' "$1"
}
has() { # label  haystack  needle
  if printf '%s\n' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1 — missing: $3"; fi
}
near() { # label  haystack  anchor  needle  (needle within 6 lines after anchor)
  if printf '%s\n' "$2" | grep -A6 -F -- "$3" | grep -qF -- "$4"; then ok "$1"; else bad "$1 — '$4' not shown under '$3'"; fi
}
lacks() { # label  haystack  needle  (assert the needle is ABSENT)
  if printf '%s\n' "$2" | grep -qF -- "$3"; then bad "$1 — unexpected: $3"; else ok "$1"; fi
}
exit_is() { # label  actual  expected
  if [ "$2" = "$3" ]; then ok "$1 (exit $3)"; else bad "$1 — exit $2, want $3"; fi
}

river() {
  echo "== The river crossing (kernel-spec Appendix C) =="
  echo "   Q: can the farmer get the wolf, goat and cabbage across intact?"
  out=$("$WRIT" check "$here/river/river.writ" --claims "$here/river/river.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "river: check reports findings" "$st" 1
  has "river: 36 reachable arrangements" "$out" "states: 36"
  has "river: A. the crossing IS solvable" "$out" "holds  solvable"
  near "river:    and writ SHOWS a real, safe crossing (the solution path)" "$out" "holds  solvable" "witness:"
  near "river:    that brings the goat BACK — the hallmark of the real solution" "$out" "holds  solvable" "cross-goat-RL"
  near "river:    before ferrying the cabbage across" "$out" "holds  solvable" "cross-cabbage-LR"
  has "river: B. but a careless crossing dooms it" "$out" "fails  no-blunders"
  near "river:    writ names the blundering move" "$out" "fails  no-blunders" "witness:"
  near "river:    stranding prey with its predator is the mistake" "$out" "fails  no-blunders" "stuck at:"
}

island() {
  echo "== Knights & knaves (kernel-spec Appendix D) =="
  echo "   Q: can every native be classified, and who could be a knight?"
  out=$("$WRIT" check "$here/island/island.writ" --claims "$here/island/island.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "island: check reports findings" "$st" 1
  has "island: 9 reachable situations" "$out" "states: 9"
  has "island: A. the rules run out — a gap" "$out" "gaps: 1"
  has "island:    the hole is reading cal, the knave-sayer" "$out" "read-cal —"
  has "island:    the rules are silent there" "$out" "rules are silent"
  has "island: B. NOT everyone is classifiable" "$out" "fails  census-completable"
  has "island: C. abe could be a knight" "$out" "holds  abe-can-be-knight"
  near "island:    and writ shows the reading that makes it so" "$out" "holds  abe-can-be-knight" "abe-is-knight"
  has "island:    bea could be a knight" "$out" "holds  bea-can-be-knight"
  has "island:    cal could be nothing at all" "$out" "fails  cal-can-be-knight"
}

queens() {
  echo "== Eight queens =="
  echo "   Q: can eight queens stand on a board with none attacking another?"
  out=$("$WRIT" check "$here/queens/queens.writ" --claims "$here/queens/queens.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /' | head -14
  exit_is "queens: check exits clean — nothing is wrong with the board" "$st" 0
  has "queens: 2057 situations, the column-ordered search tree" "$out" "states: 2057"
  has "queens: A. eight queens CAN be placed" "$out" "holds  solvable"
  near "queens:    and writ shows where they go" "$out" "holds  solvable" "witness:"
  near "queens:    starting from a first-column placement" "$out" "holds  solvable" "1. place-"
  # `near` looks six lines past its anchor and the witness is eight moves, so
  # the last one is asserted on the numbered line it prints as — a spelling
  # that occurs nowhere else, since dead ends are listed as "reached by:".
  has "queens:    through to the eighth column" "$out" "8. place-"
  # A complete board is a dead end reached in EIGHT moves — one per column,
  # since the cursor advances exactly once per placement. The other dead ends
  # are stuck prefixes, whose routes are shorter, which is why this counts
  # route length rather than dead ends.
  n=$(printf '%s\n' "$out" | grep 'reached by:' \
      | awk -F'reached by:' '{ if (split($2, a, ",") == 8) c++ } END { print c+0 }')
  if [ "$n" -eq 92 ]; then
    ok "queens: B. all 92 complete boards are found (each a dead end)"
  else
    bad "queens: B. expected 92 complete boards, found $n"
  fi
}


jobshop_possible() {
  echo "== A blocking job shop =="
  echo "   Q: three jobs, three machines, no buffers — can every schedule still"
  echo "      finish, or can the shop walk into a deadlock?"
  out=$("$WRIT" check "$here/jobshop-possible/jobshop-possible.writ" --claims "$here/jobshop-possible/jobshop-possible.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "jobshop-possible: check reports findings" "$st" 1
  has "jobshop-possible: 51 reachable schedules" "$out" "states: 51"
  has "jobshop-possible: A. some schedule finishes every job" "$out" "holds  all-finish"
  near "jobshop-possible:    and writ shows one" "$out" "holds  all-finish" "witness:"
  has "jobshop-possible: B. but not EVERY schedule can still finish" "$out" "fails  never-stuck"
  has "jobshop-possible:    the deadlock is named in full" "$out" \
    "m1.held-by=a m2.held-by=b m3.held-by=c"
  near "jobshop-possible:    reached by three moves, one per job" "$out" "fails  never-stuck" "a-enters"
  near "jobshop-possible:    each job holding the machine the next one wants" "$out" \
    "fails  never-stuck" "c-enters"
}

jobshop_best() {
  echo "== The same job shop, with a clock =="
  echo "   Q: what is the SHORTEST schedule, and what does it look like?"
  out=$("$WRIT" check "$here/jobshop-best/jobshop-best.writ" \
    --claims "$here/jobshop-best/jobshop-best.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "jobshop-best: check reports a finding (the too-tight bound)" "$st" 1
  has "jobshop-best: 1314 situations — the shop times the clock" "$out" "states: 1314"
  has "jobshop-best: A. four ticks is NOT enough" "$out" "fails  done-by-4"
  has "jobshop-best: B. five ticks is — the optimum, pinned from both sides" "$out" \
    "holds  done-by-5"
  near "jobshop-best:    and writ prints the optimal schedule" "$out" \
    "holds  done-by-5" "witness:"
  # The optimum overlaps a and b while holding c back — which is exactly what
  # jobshop-possible proved was necessary, since all three in the shop at once
  # is the deadlock.
  near "jobshop-best:    it starts two jobs in the first tick" "$out" \
    "holds  done-by-5" "b-enters"
  near "jobshop-best:    and only then advances the clock" "$out" \
    "holds  done-by-5" "3. tick"
}



two_phase_commit() {
  d="$here/two-phase-commit"
  echo "== Two-phase commit — agreeing to commit across parties that can fail =="
  echo "   Q: can the parties disagree, can they be left waiting for ever, and"
  echo "      what does the obvious cure for the waiting cost?"
  out=$("$WRIT" check "$d/two-phase-commit.writ" --claims "$d/two-phase-commit.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /' | grep -v 'reached by:'
  exit_is "2pc: check reports findings" "$st" 1
  has "2pc: 84 situations of two participants and a coordinator" "$out" "states: 84"

  has "2pc: A. ATOMICITY holds — never one committed and another aborted" "$out" "holds  atomic"
  has "2pc:    and committing is actually reachable" "$out" "holds  can-commit"
  near "2pc:    with the route that gets there" "$out" "holds  can-commit" "witness:"

  # The textbook blocking result, and writ finds it in two moves: one participant
  # prepares — surrendering its right to decide — and the coordinator dies.
  has "2pc: B. but a prepared participant CAN be left unable to decide" "$out" "fails  can-decide"
  near "2pc:    two moves is all it takes" "$out" "fails  can-decide" "2. c-crash"
  near "2pc:    and it is stranded with the coordinator gone" "$out" "fails  can-decide" "c.state=crashed"

  # `live` and `inevitable` both fail here, and that is the expected order:
  # inevitable is the stronger of the two, so nothing passes it and fails live.
  has "2pc: C. and no run is obliged to decide either" "$out" "fails  must-decide"
  has "2pc:    which a fairness assumption cannot rescue — a stop is not a starve" "$out" "fails  must-decide-if-applied"
  near "2pc:    and the verdict prints what it assumed" "$out" "fails  must-decide-if-applied" "assuming fair:"

  # The retransmitting network: no crash at all, and the two liveness questions
  # come apart. This is the whole reason `inevitable` exists.
  lossy=$("$WRIT" check "$d/two-phase-commit-lossy.writ" --claims "$d/two-phase-commit.claims" 2>&1)
  printf '%s\n' "$lossy" | sed 's/^/     | /' | grep -v 'reached by:'
  has "2pc: D. over a network that drops and resends, deciding stays REACHABLE" "$lossy" "holds  can-decide"
  has "2pc:    and yet a run can decline it for ever" "$lossy" "fails  must-decide"
  near "2pc:    naming the situation the run circles in" "$lossy" "fails  must-decide" "c.decision=commit"
  has "2pc:    assume the told participant applies, and it terminates" "$lossy" "holds  must-decide-if-applied"

  # The trade, priced. Letting a stranded participant give up buys every
  # liveness property and sells the one the protocol exists for.
  cmp=$("$WRIT" compare "$d/two-phase-commit.writ" "$d/two-phase-commit-timeout.writ" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "2pc: E. compare reports a lost guarantee" "$cst" 1
  has "2pc:    the timeout cure LOSES atomicity" "$cmp" "atomic                  LOST"
  has "2pc:    and writ prints the run that breaks it" "$cmp" "p2-timeout"
  has "2pc:    while every liveness property is gained" "$cmp" "must-decide             gained"
  has "2pc:    including the plain reachability one" "$cmp" "can-decide              gained"
}




arch() {
  echo "== System architecture from a component bank =="
  echo "   Q: 50TB of files to classify, re-runnably, then feed AI and surface"
  echo "      in a CRM — which architectures satisfy that, and what does the"
  echo "      brief fail to say?"
  out=$("$WRIT" check "$here/arch/arch.writ" --claims "$here/arch/arch.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /' | grep -v 'reached by'
  exit_is "arch: check reports findings" "$st" 1
  # The cost law of the core README, as a regression: seven stages admitting
  # 1,2,2,2,3,2,2 parts give 1*2*2*2*3*2*2 = 96 designs, and the situations are
  # their prefixes — 1+1+2+4+8+24+48+96 = 184, under the 2x bound.
  has "arch: 184 situations — the prefixes of 96 designs" "$out" "states: 184"
  has "arch: A. 96 architectures survive the constraints" "$out" "dead ends: 96"
  has "arch:    and one can be realised" "$out" "holds  realisable"
  near "arch:    writ prints it, stage by stage" "$out" "holds  realisable" "witness:"
  near "arch:    starting at storage" "$out" "holds  realisable" "hold-object-store"
  has "arch: B. no partial choice strands the build" "$out" "holds  no-dead-end"
  has "arch: C. the brief is silent somewhere — a gap" "$out" "gaps: 1"
  has "arch:    scanned or digital-native is never stated" "$out" "digital-native or scanned"
  has "arch: D. re-runnable classification is NOT affordable everywhere" "$out" \
    "fails  rerun-is-affordable"
  # The finding: a stack meeting every STATED requirement whose extract stage
  # discards its output, so re-classifying means re-processing the whole corpus.
  near "arch:    the witness names the part that discards its output" "$out" \
    "fails  rerun-is-affordable" "ext-llm-vision"
  has "arch: E. the CRM is never coupled at the database" "$out" "holds  crm-stays-loose"

  echo "   Q: read one finished design out as data — what a query cannot do"
  bp=$("$WRIT" derive "$here/arch/arch.writ" "$here/arch/arch.rules" \
    "(blueprint 183 K C)" 2>&1)
  bst=$?
  printf '%s\n' "$bp" | sed 's/^/     | /'
  exit_is "arch: derive answers the blueprint" "$bst" 0
  has "arch: F. seven stages, one part each" "$bp" "blueprint  (7 rows)"
  has "arch:    storage is named" "$bp" "hold  object-store"
  has "arch:    and the CRM edge is named" "$bp" "surface  ipaas"
}

control() {
  echo "== writ control — a model's dynamics as data (kernel-spec §17) =="
  echo "   Q: can we export the move list and re-use it with the same machinery?"
  out=$("$WRIT" control "$here/payments/payments.writ" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "control: emits cleanly" "$st" 0
  has "control: it is an instance of the stdlib quiver schema" "$out" "-control quiver"
  has "control: an edge per transition — capture-again" "$out" "capture-again"
  has "control:    ... and void-uncaptured" "$out" "void-uncaptured"
  # Prove the emitted quiver is real data: wrap it as a model and re-check it.
  tmp=$(mktemp -d)
  printf '%s\n' "$out" >"$tmp/ctrl.writ"
  printf '(load "ctrl.writ")\n(use quiver)\n(initial payments-control)\n' >"$tmp/wrap.writ"
  if (cd "$tmp" && "$WRIT" check wrap.writ >/dev/null 2>&1); then
    ok "control: the emitted quiver re-parses and builds"
  else bad "control: the emitted quiver did not re-parse"; fi
  rm -rf "$tmp"
}

gitcompare() {
  echo "== writ compare --git — an amendment across commits (kernel-spec §17) =="
  echo "   Q: two git revisions of one model — what did the amendment cost?"
  if ! command -v git >/dev/null 2>&1; then
    printf '  [skip] writ compare --git needs git (not installed here)\n'
    return 0
  fi
  # A self-contained history: commit the keyed payment flow, then commit the
  # shortcut that drops the idempotency key, in a throwaway repo — so the demo
  # is deterministic and needs no shared history.
  tmp=$(mktemp -d)
  d="$here/payments"
  cp "$d/payments.writ" "$d/payments.claims" "$d/payments.lib.writ" "$tmp/"
  (cd "$tmp" && git init -q && git add . &&
    git -c user.email=t@t -c user.name=t commit -qm "v1: with the idempotency key") >/dev/null 2>&1
  cp "$d/payments-shortcut.writ" "$tmp/payments.writ"
  (cd "$tmp" && git add payments.writ &&
    git -c user.email=t@t -c user.name=t commit -qm "amendment: drop the key") >/dev/null 2>&1
  out=$(cd "$tmp" && "$WRIT" compare --git HEAD~1 HEAD payments.writ 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "git-compare: the amendment loses a guarantee" "$st" 1
  has "git-compare: never-double is LOST across the two commits" "$out" "never-double               LOST"
  has "git-compare: one-capture is preserved" "$out" "one-capture                preserved"
  rm -rf "$tmp"
}

crosscheck() {
  echo "== The modality cross-check — two implementations of one question =="
  echo "   Q: does the rules engine, asked the SAME properties over the SAME"
  echo "      space, reach the same verdicts as \`writ check\`?"
  out=$(WRIT="$WRIT" sh "$here/modality-cross-check.sh" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "cross-check: the two implementations agree everywhere" "$st" 0
  # The twenty-two scenarios this script walks by convention, and their 63
  # properties. Adding a property to any of the twenty-two fails this line, which is the point of it —
  # the count went 20 -> 22 -> 26 as the three db-migration-problems joined,
  # 26 -> 31 with two-phase-commit, 31 -> 41 with the three
  # entitlement-problems (3 + 3 + 4), 41 -> 45 with expense-approval, and
  # 45 -> 49 with agent-guardrails, 49 -> 52 with deployment, 52 -> 56 with
  # payments, 56 -> 60 with config-space, 60 -> 55 as oversight, workflow
  # and access left, 55 -> 57 with on-call-rota, 57 -> 63 with the second
  # batch of db-migration-problems (2 + 2 + 2), and this line is where each of
  # those had to be said out loud.
  has "cross-check: all 63 properties of the twenty-two scenarios were considered" \
    "$out" "considered 63 properties: 61 compared, 2 not compared"
  # Two of the 63 are not compared, and the count above is the only place that
  # would notice if the reason changed: two-phase-commit and expense-approval
  # each ask one property under a fairness assumption, which ct.rules §8 does
  # not encode.
  has "cross-check:    with the fair properties skipped, and saying why" \
    "$out" "carries (fair …) — no rules encoding, skipped"
  has "cross-check: A. a possible is its satisfying set — non-empty holds" \
    "$out" "river/solvable  possible: satisfying set of"
  has "cross-check: B. a live is its COUNTEREXAMPLE set — empty holds" \
    "$out" "payments/always-terminal  live: counterexample set of 0"
  has "cross-check:    and a failing live names its witnesses" \
    "$out" "deployment/can-roll-back  live: counterexample set of 4"
  # `arch` brought the repository's first two `never` properties, so this
  # branch — which announced itself as unexercised on every prior run — is now
  # measured. If it ever reads "unexercised" again, a scenario went missing.
  # two-phase-commit's atomicity is the third; the entitlement problems bring
  # four more, since "nobody ever holds X" is how an access rule is said, and
  # expense-approval, agent-guardrails, deployment and config-space one each,
  # payments two.
  has "cross-check: C. the never branch is exercised" "$out" \
    "never: 13 properties compared"
  # And `inevitable`, two of whose three are two-phase-commit's — the newest
  # modality, and the one whose second implementation is newest, so the line
  # that says it is being compared at all is worth having. The third is
  # expense-approval's `settles`, a fair one: this line counts properties
  # considered, so it counts that one too, though it is skipped.
  has "cross-check: D. the inevitable branch is exercised too" "$out" \
    "inevitable: 3"
  has "cross-check:    an inevitable is its ESCAPE set, empty holds" "$out" \
    "two-phase-commit/must-decide  inevitable: counterexample set of 10"
  has "cross-check:    a never is a COUNTEREXAMPLE set, like live" "$out" \
    "arch/crm-stays-loose  never: counterexample set of 0"
  has "cross-check:    and a failing never names its witnesses" "$out" \
    "arch/rerun-is-affordable  never: counterexample set of 88"
}

rename_a_column() {
  echo "== Expand/contract — renaming a column under a live service =="
  echo "   Q: is this migration plan safe at EVERY instant, including the ones"
  echo "      where a rolling deploy has two releases serving at once?"

  echo "   1/4: the DDL, read by \`writ sql\` — users generate SQL, not .writ"
  tmp=$(mktemp -d)
  for f in 01-before 02-expand 03-contract; do
    "$WRIT" sql "$here/db-migration-problems/rename-a-column/$f.sql" --with-data >"$tmp/$f.writ" 2>/dev/null
  done
  exp=$(cat "$tmp/02-expand.writ")
  # The expand step's whole content is that the new column is NULLABLE, which
  # `writ sql` writes as one character: `text?` rather than `text`.
  has "rename-a-column: the expand adds the column as NULLABLE" "$exp" "(text? full-name)"
  has "rename-a-column:    while the old column stays required" "$exp" "(text name)"
  bef=$(cat "$tmp/01-before.writ")
  lacks "rename-a-column:    and before the expand it does not exist" "$bef" "full-name"
  con=$(cat "$tmp/03-contract.writ")
  lacks "rename-a-column:    after the contract the old one is gone" "$con" "(text name)"
  for f in 01-before 02-expand 03-contract; do
    if (cd "$tmp" && "$WRIT" check "$f.writ" >/dev/null 2>&1); then
      ok "rename-a-column:    $f builds as a model"
    else bad "rename-a-column:    $f did not build"; fi
  done
  # The same expand with NOT NULL is not merely different, it is REFUSED: the
  # representative row has no value for a column that did not exist yet.
  "$WRIT" sql "$here/db-migration-problems/rename-a-column/02-expand-wrong.sql" --with-data \
    >"$tmp/wrong.writ" 2>/dev/null
  wrong=$(cd "$tmp" && "$WRIT" check wrong.writ 2>&1)
  wst=$?
  printf '%s\n' "$wrong" | sed 's/^/     | /'
  exit_is "rename-a-column: NOT NULL on the new column is refused" "$wst" 2
  has "rename-a-column:    and it names the row that cannot exist" "$wrong" "users.full-name for u1"
  rm -rf "$tmp"

  echo "   2/4: the plan"
  mg=$("$WRIT" check "$here/db-migration-problems/rename-a-column/rename-a-column.writ" --claims "$here/db-migration-problems/rename-a-column/rename-a-column.claims" 2>&1)
  mst=$?
  printf '%s\n' "$mg" | sed 's/^/     | /'
  exit_is "rename-a-column: the plan is clean" "$mst" 0
  has "rename-a-column: A. the rename can be finished" "$mg" "holds  completes"
  near "rename-a-column:    and writ prints the runbook, which nobody wrote" "$mg" "holds  completes" "add-column"
  near "rename-a-column:    the backfill comes before the readers switch" "$mg" "holds  completes" "backfill"
  has "rename-a-column: B. and no step strands production half-migrated" "$mg" "holds  no-dead-ends"
  lacks "rename-a-column:    no law is violated" "$mg" "violated in"
  lacks "rename-a-column:    and every breakable law is acknowledged" "$mg" "unadmitted"

  echo "   3/4: the shortcut — the same file, ONE conjunct lighter"
  sc=$("$WRIT" check "$here/db-migration-problems/rename-a-column/rename-a-column-shortcut.writ" --claims "$here/db-migration-problems/rename-a-column/rename-a-column.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "rename-a-column: the shortcut reports findings" "$sst" 1
  has "rename-a-column: C. a reader goes out before the backfill" "$sc" "violated in 5 reachable situations"
  near "rename-a-column:    and writ names the step that does it" "$sc" "violated in 5 reachable situations" "deploy-r3"
  has "rename-a-column: D. yet it still finishes — faster, which is the trap" "$sc" "holds  completes"
  has "rename-a-column:    and it never strands you either" "$sc" "holds  no-dead-ends"

  echo "   4/4: the verb that does NOT catch it"
  cm=$("$WRIT" compare "$here/db-migration-problems/rename-a-column/rename-a-column.writ" "$here/db-migration-problems/rename-a-column/rename-a-column-shortcut.writ" 2>&1)
  cst=$?
  printf '%s\n' "$cm" | sed 's/^/     | /'
  exit_is "rename-a-column: compare is content" "$cst" 0
  has "rename-a-column: E. compare says the guarantees survived" "$cm" "preserved"
  lacks "rename-a-column:    nothing is reported LOST" "$cm" "LOST"
  echo "      — the shortcut declares the same laws and keeps the same"
  echo "        properties; what it loses is that one law it declares is now"
  echo "        VIOLATED. So the gate is \`check\`, not \`compare\`."
}

drop_a_column() {
  d="$here/db-migration-problems/drop-a-column"
  echo "== Dropping a column that is still being read =="
  echo "   Q: how many moves from a normal-looking plan to an outage?"
  ok_=$("$WRIT" check "$d/drop-a-column.writ" --claims "$d/drop-a-column.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "drop-a-column: the plan is clean" "$ost" 0
  has "drop-a-column: A. the column can be dropped" "$ok_" "holds  completes"
  near "drop-a-column:    and the rollout finishes BEFORE the drop" "$ok_" "holds  completes" "settle"
  has "drop-a-column: B. and no step strands you" "$ok_" "holds  no-dead-ends"
  lacks "drop-a-column:    nothing is violated" "$ok_" "violated in"

  sc=$("$WRIT" check "$d/drop-a-column-shortcut.writ" --claims "$d/drop-a-column.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "drop-a-column: dropping mid-rollout is refused" "$sst" 1
  has "drop-a-column: C. the old release reads a column that is gone" "$sc" "violated in 1 reachable situations"
  near "drop-a-column:    two moves to the fault" "$sc" "violated in 1 reachable situations" "deploy-r2"
  has "drop-a-column: D. and its writes break too" "$sc" "equation write-of-existing"
  has "drop-a-column: E. yet it still finishes, and never strands you" "$sc" "holds  no-dead-ends"
}

add_a_required_column() {
  d="$here/db-migration-problems/add-a-required-column"
  echo "== Making a column required, before the code can keep the promise =="
  echo "   Q: NOT NULL is a promise about rows that do not exist yet — who checks it?"
  tmp=$(mktemp -d)
  "$WRIT" sql "$d/02-add-nullable.sql" --with-data >"$tmp/step2.writ" 2>/dev/null
  has "add-a-required-column: the column arrives NULLABLE" "$(cat "$tmp/step2.writ")" "(text? country)"
  rm -rf "$tmp"

  ok_=$("$WRIT" check "$d/add-a-required-column.writ" --claims "$d/add-a-required-column.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "add-a-required-column: the plan is clean" "$ost" 0
  has "add-a-required-column: A. the column can end up required" "$ok_" "holds  completes"
  near "add-a-required-column:    the deploy comes BEFORE the backfill" "$ok_" "holds  completes" "deploy-r2"
  has "add-a-required-column: B. and no step strands you" "$ok_" "holds  no-dead-ends"
  lacks "add-a-required-column:    nothing is violated" "$ok_" "violated in"

  sc=$("$WRIT" check "$d/add-a-required-column-shortcut.writ" --claims "$d/add-a-required-column.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "add-a-required-column: constraining before deploying is refused" "$sst" 1
  has "add-a-required-column: C. a live release does not write the column" "$sc" "violated in 2 reachable situations"
  near "add-a-required-column:    three moves, and no deploy among them" "$sc" "violated in 2 reachable situations" "backfill"
  has "add-a-required-column: D. yet it still finishes — faster" "$sc" "holds  completes"
  # Exactly ONE rule breaks. The database's own check (`required-needs-data`)
  # is still satisfied, which is the whole reason the mistake is easy: the half
  # you get reminded about is the half that was fine.
  nviol=$(printf '%s\n' "$sc" | grep -c "violated in")
  if [ "$nviol" = "1" ]; then
    ok "add-a-required-column: E. and only ONE rule breaks — the unchecked half"
  else
    bad "add-a-required-column: E. expected exactly one violated rule, got $nviol"
  fi
}

separation_of_duties() {
  d="$here/entitlement-problems/separation-of-duties"
  echo "== Separation of duties — a conflict that arrives through a role =="
  echo "   Q: the toxic-combination table is checked on every grant. Is that enough?"
  out=$("$WRIT" check "$d/separation-of-duties.writ" --claims "$d/separation-of-duties.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "separation-of-duties: checking capabilities, the plan is clean" "$st" 0
  has "separation-of-duties: A. an approver can still be appointed" "$out" "holds  staffable"
  has "separation-of-duties: B. nobody holds both halves of a payment" "$out" "holds  no-conflict"
  has "separation-of-duties:    and everyone can still be taken out of every group" "$out" "holds  revocable"
  lacks "separation-of-duties:    nothing is violated" "$out" "violated in"

  sc=$("$WRIT" check "$d/separation-of-duties-shortcut.writ" --claims "$d/separation-of-duties.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "separation-of-duties: checking the table alone is refused" "$sst" 1
  has "separation-of-duties: C. two grants the table never listed" "$sc" "violated in 52 reachable situations"
  near "separation-of-duties:    the first is innocent" "$sc" "fails  no-conflict" "1. alice-joins-requesters"
  near "separation-of-duties:    the second is a group nobody put in the table" "$sc" "fails  no-conflict" "2. alice-also-joins-finance-leads"
  near "separation-of-duties:    and the verdict names who" "$sc" "fails  no-conflict" "a = alice"
  # Which two groups is a join, which a query cannot do and the rules engine
  # can: every row it prints is the same pair, and that pair is the finding.
  dv=$("$WRIT" derive "$d/separation-of-duties-shortcut.writ" "$d/separation-of-duties.rules" conflict 2>&1)
  has "separation-of-duties: D. derive names the account and both groups" "$dv" "14  alice  requesters  finance-leads"
  lacks "separation-of-duties:    and the pair the table lists never appears" "$dv" "requesters  approvers"
}

scp_escalation() {
  d="$here/entitlement-problems/scp-escalation"
  echo "== An OU move — the guardrails stay behind =="
  echo "   Q: moving an account between OUs changes no role. What does it change?"
  out=$("$WRIT" check "$d/scp-escalation.writ" --claims "$d/scp-escalation.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "scp-escalation: the organization as approved is clean" "$st" 0
  has "scp-escalation: A. developers cannot modify CloudTrail" "$out" "holds  dev-never-edits-cloudtrail"
  has "scp-escalation: B. the security team can always reach the audit trail" "$out" "holds  sec-can-always-audit"

  cmp=$("$WRIT" compare "$d/scp-escalation.writ" "$d/scp-escalation-restructured.writ" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "scp-escalation: compare refuses the reorganisation" "$cst" 1
  has "scp-escalation: C. deploying still works" "$cmp" "dev-can-deploy              preserved"
  has "scp-escalation: D. the CloudTrail guardrail is LOST" "$cmp" "dev-never-edits-cloudtrail  LOST      witness: 1. dev-assumes-power 2. move-prod-to-workloads"
  has "scp-escalation: E. and the security team is locked out, by the move alone" "$cmp" "sec-can-always-audit        LOST      witness: 1. move-prod-to-workloads"

  dv=$("$WRIT" derive "$d/scp-escalation-restructured.writ" "$d/scp-escalation.rules" escalation 2>&1)
  has "scp-escalation: F. derive prints the privilege path" "$dv" "dev  power  prod-acct  workloads"
}

joiner_mover_leaver() {
  d="$here/entitlement-problems/joiner-mover-leaver"
  echo "== Joiner, mover, leaver — the grant that offboarding cannot see =="
  echo "   Q: offboarding removes people from their groups. Is that everything?"
  out=$("$WRIT" check "$d/joiner-mover-leaver.writ" --claims "$d/joiner-mover-leaver.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "joiner-mover-leaver: removing everything by name, the plan is clean" "$st" 0
  has "joiner-mover-leaver: A. Ada can be given production access" "$out" "holds  ada-gets-access"
  has "joiner-mover-leaver: B. a mover loses it" "$out" "holds  movers-lose-prod"
  has "joiner-mover-leaver: C. a leaver loses it" "$out" "holds  leavers-lose-everything"
  has "joiner-mover-leaver:    and can always be cut off" "$out" "holds  leavers-can-be-cut-off"

  sc=$("$WRIT" check "$d/joiner-mover-leaver-shortcut.writ" --claims "$d/joiner-mover-leaver.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "joiner-mover-leaver: group-only offboarding is refused" "$sst" 1
  has "joiner-mover-leaver: D. a leaver keeps production access" "$sc" "fails  leavers-lose-everything"
  near "joiner-mover-leaver:    after an ordinary four-step history" "$sc" "fails  leavers-lose-everything" "4. ada-leaves"
  # The query answer sits below the four-move witness, past `near`'s six lines,
  # so it is anchored on the situation the verdict singled out.
  near "joiner-mover-leaver:    and the verdict names what was left behind" "$sc" "stranded  (at state 13)" "e = prod-admin"
  has "joiner-mover-leaver: E. so does a mover" "$sc" "fails  movers-lose-prod"
  # Not a delay but a trap: nothing that runs later removes a direct grant.
  has "joiner-mover-leaver: F. and nothing left can cut the leaver off" "$sc" "fails  leavers-can-be-cut-off"
  near "joiner-mover-leaver:    stuck holding the direct assignment" "$sc" "fails  leavers-can-be-cut-off" "prod-admin.holder=ada"
  has "joiner-mover-leaver:    while the group grant was removed" "$sc" "prod-engineers.holder: ada → ∅"

  dv=$("$WRIT" derive "$d/joiner-mover-leaver-shortcut.writ" "$d/joiner-mover-leaver.rules" left-behind 2>&1)
  has "joiner-mover-leaver: G. every entitlement left behind was granted directly" "$dv" "prod-admin  direct  ada"
  lacks "joiner-mover-leaver:    and none through a group" "$dv" "  group  "
}

expense_approval() {
  d="$here/expense-approval"
  echo "== Expense approval — two signatures, one person =="
  echo "   Q: can a large expense be paid without two independent approvals?"
  out=$("$WRIT" check "$d/expense-approval.writ" --claims "$d/expense-approval.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "expense-approval: the process is clean" "$st" 0
  has "expense-approval: A. a large expense can be paid" "$out" "holds  payable"
  near "expense-approval:    on the manager's signature and finance's" "$out" "holds  payable" "cat-approves-for-finance"
  has "expense-approval: B. never on one person's say-so" "$out" "holds  never-on-one-person"
  has "expense-approval: C. and every run settles, paid or cancelled" "$out" "holds  settles"
  lacks "expense-approval:    nothing is violated" "$out" "violated in"

  sc=$("$WRIT" check "$d/expense-approval-shortcut.writ" --claims "$d/expense-approval.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "expense-approval: \"both slots filled\" is refused" "$sst" 1
  has "expense-approval: D. paid on two signatures by one person" "$sc" "violated in 2 reachable situations   witness: 1. submit 2. bob-approves-as-manager 3. bob-approves-for-finance 4. pay"
  has "expense-approval:    and only that rule breaks" "$sc" "fails  never-on-one-person"
  has "expense-approval: E. yet it still pays, and still settles" "$sc" "holds  settles"

  cmp=$("$WRIT" compare "$d/expense-approval.writ" "$d/expense-approval-shortcut.writ" 2>&1)
  has "expense-approval: F. compare reports the guarantee LOST" "$cmp" "never-on-one-person    LOST"
  # The law that breaks compares as preserved: compare matches laws by
  # declaration, and both files declare it. The property is what catches it.
  has "expense-approval:    while the law it breaks compares as preserved" "$cmp" "two-for-large          preserved"

  dv=$("$WRIT" derive "$d/expense-approval-shortcut.writ" "$d/expense-approval.rules" paid-by 2>&1)
  has "expense-approval: G. derive lists who signed each payment" "$dv" "13  bob  bob"
}

agent_guardrails() {
  d="$here/agent-guardrails"
  c="$d/agent-guardrails.claims"
  echo "== An AI agent's tool policy — and the read-only tool that leaks =="
  echo "   Q: can a secret leave the machine with no human saying yes?"
  out=$("$WRIT" check "$d/agent-guardrails.writ" --claims "$c" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "agent-guardrails: policy v1 is clean" "$st" 0
  has "agent-guardrails: A. the agent can work on its own" "$out" "holds  useful"
  has "agent-guardrails: B. no secret leaves unasked" "$out" "holds  no-unapproved-exfiltration"
  has "agent-guardrails:    and the human can always interrupt" "$out" "holds  human-can-interrupt"

  cmp=$("$WRIT" compare "$d/agent-guardrails.writ" "$d/agent-guardrails-v2.writ" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "agent-guardrails: compare refuses v2" "$cst" 1
  has "agent-guardrails: C. adding a read-only tool loses the guarantee, in three moves" "$cmp" \
    "no-unapproved-exfiltration  LOST      witness: 1. switch-to-auto 2. read-secret-with-file-read 3. send-secret-with-web-fetch"
  # The headline: the route contains no human move. Asserted on the route
  # line itself, since every human move's name starts with `human-`.
  route=$(printf '%s\n' "$cmp" | grep "no-unapproved-exfiltration  LOST")
  lacks "agent-guardrails:    and no human move is on the route" "$route" "human-"
  has "agent-guardrails:    while the agent stays exactly as useful" "$cmp" "useful                      preserved"

  v2=$("$WRIT" check "$d/agent-guardrails-v2.writ" --claims "$c" 2>&1)
  near "agent-guardrails: D. the verdict names the tool" "$v2" "carrier  (at state 6)" "t = web-fetch"
  has "agent-guardrails:    and the new move is one the human never acknowledged" "$v2" \
    "unadmitted  send-secret-with-web-fetch may break no-silent-exfiltration"

  # The loop: an agent asked to make v2 pass, the claims file held fixed.
  fx=$("$WRIT" check "$d/attempt-fetch-asks.writ" --claims "$c" 2>&1)
  fst=$?
  exit_is "agent-guardrails: E. the honest fix still awaits the human" "$fst" 1
  has "agent-guardrails:    every question holds" "$fx" "holds  no-unapproved-exfiltration"
  has "agent-guardrails:    but its new approval path is the human's to acknowledge" "$fx" \
    "unadmitted  human-approves-web-fetch may break no-silent-exfiltration"
  fc=$("$WRIT" compare "$d/agent-guardrails.writ" "$d/attempt-fetch-asks.writ" 2>&1)
  fcst=$?
  exit_is "agent-guardrails:    and compare against v1 accepts it" "$fcst" 0

  ch=$("$WRIT" check "$d/attempt-forget-out.writ" --claims "$c" 2>&1)
  chst=$?
  # The cheat: delete what the question reads. `check` answers n/a and EXITS 0
  # — asserted as it is, since a harness that gates on this exit code is the
  # failure the README warns about.
  has "agent-guardrails: F. deleting the record makes the question n/a" "$ch" "n/a  no-unapproved-exfiltration"
  exit_is "agent-guardrails:    and check alone exits clean" "$chst" 0
  cc=$("$WRIT" compare "$d/agent-guardrails.writ" "$d/attempt-forget-out.writ" 2>&1)
  ccst=$?
  exit_is "agent-guardrails: G. compare against v1 refuses it" "$ccst" 1
  has "agent-guardrails:    naming the question it took away" "$cc" "no-unapproved-exfiltration  LOST"

  dv=$("$WRIT" derive "$d/agent-guardrails-v2.writ" "$d/agent-guardrails.rules" exfil-path 2>&1)
  has "agent-guardrails: H. derive lists the tool and the mode" "$dv" "6  web-fetch  auto"
}

deployment() {
  d="$here/deployment"
  c="$d/deployment.claims"
  echo "== A rolling deploy — and the rollback that is not always there =="
  echo "   Q: is production ever dark, and can the fleet always roll back?"
  out=$("$WRIT" check "$d/deployment.writ" --claims "$c" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  # Exit 1 on the SAFE plan, and that is the finding: the rollout is fine, the
  # rollback is a promise one lawful move breaks.
  exit_is "deployment: even the gated rollout reports a finding" "$st" 1
  has "deployment: A. the release can finish" "$out" "holds  upgrades"
  has "deployment: B. production is never dark" "$out" "holds  never-dark"
  has "deployment: C. but rollback is not always possible" "$out" "fails  can-roll-back"
  has "deployment:    stuck once the schema is v2" "$out" "prod.target=r2 db.at=v2)"
  has "deployment:    and the last step there is the migration" "$out" "8. migrate"
  lacks "deployment:    no law is broken on the way" "$out" "violated in"

  sc=$("$WRIT" check "$d/deployment-shortcut.writ" --claims "$c" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "deployment: the ungated rollout is refused" "$sst" 1
  has "deployment: D. without the health gate, production goes dark" "$sc" "fails  never-dark"
  near "deployment:    three replacements, no health check between" "$sc" "fails  never-dark" "4. replace-c-with-r2"

  # Asked with no goal in mind: which moves can never be taken back? The
  # migration, and nothing else — a rollout move here would be a latch.
  dv=$("$WRIT" derive "$d/deployment.writ" "$d/deployment.rules" irreversible 2>&1)
  has "deployment: E. exactly one decision cannot be taken back" "$dv" "irreversible  (1 row)"
  has "deployment:    the migration" "$dv" "  migrate"
}

payments() {
  d="$here/payments"
  c="$d/payments.claims"
  echo "== Payments — the reply that never comes, and the retry =="
  echo "   Q: can a lost reply and a retry charge the customer twice?"
  out=$("$WRIT" check "$d/payments.writ" --claims "$c" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "payments: with an idempotency key, the integration is clean" "$st" 0
  has "payments: A. a payment can settle" "$out" "holds  settles"
  has "payments: B. never charged twice" "$out" "holds  never-double"
  has "payments: C. a cancelled order is never left charged" "$out" "holds  never-charged-for-nothing"
  has "payments:    and every order can still reach an end" "$out" "holds  always-terminal"
  lacks "payments:    nothing is violated" "$out" "violated in"

  sc=$("$WRIT" check "$d/payments-shortcut.writ" --claims "$c" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "payments: without the key, the integration is refused" "$sst" 1
  has "payments: D. a lost reply and a retry charge twice" "$sc" \
    "violated in 13 reachable situations   witness: 1. authorize 2. send-capture 3. capture 4. lose-reply 5. send-capture 6. capture-again"
  has "payments: E. and a void that overtakes the capture charges for a cancelled order" "$sc" "fails  never-charged-for-nothing"
  near "payments:    the void lands first, with nothing to refund" "$sc" "fails  never-charged-for-nothing" "4. void-uncaptured"
  near "payments:    then the capture" "$sc" "fails  never-charged-for-nothing" "5. capture"
  has "payments: F. yet it still settles" "$sc" "holds  settles"

  dv=$("$WRIT" derive "$d/payments-shortcut.writ" "$d/payments.rules" double-charged 2>&1)
  has "payments: G. double charges hide in orders that settled and shipped" "$dv" "settled  yes"
}

config_space() {
  d="$here/config-space"
  c="$d/config-space.claims"
  echo "== The configuration space — every combination, not a sample =="
  echo "   Q: can the admin operations reach a combination the product forbids?"
  out=$("$WRIT" check "$d/config-space.writ" --claims "$c" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "config-space: the guarded operations are clean" "$st" 0
  has "config-space: A. 21 of the 64 combinations are reachable" "$out" "states: 21"
  has "config-space: B. a fully-featured safe configuration exists" "$out" "holds  fully-featured"
  has "config-space: C. none the product forbids" "$out" "holds  never-unsafe"
  lacks "config-space:    nothing is violated" "$out" "violated in"

  sc=$("$WRIT" check "$d/config-space-shortcut.writ" --claims "$c" --fiber cfg.region 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "config-space: one forgotten check is refused" "$sst" 1
  # The order finding: every step is allowed, and only this order gets there —
  # turning SSO off first would block the shard.
  has "config-space: D. the forbidden state, in one order of three allowed steps" "$sc" \
    "violated in 3 reachable situations   witness: 1. enable-legacy-auth 2. shard 3. disable-sso"
  has "config-space: E. yet every configuration can still be made safe" "$sc" "holds  recoverable"
  # FR-10's fibers: the same question per region. Legacy auth is forbidden in
  # the EU, and it is the first step of the route.
  has "config-space: F. only the US deployment can reach it" "$sc" "fiber cfg.region=us   FAILS"
  has "config-space:    the EU one cannot" "$sc" "fiber cfg.region=eu   holds"

  cmp=$("$WRIT" compare "$d/config-space.writ" "$d/config-space-v2.writ" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "config-space: compare refuses the release that adds a flag" "$cst" 1
  has "config-space: G. the new flag reaches a forbidden state in one move" "$cmp" \
    "never-unsafe             LOST      witness: 1. enable-new-billing"
  v2=$("$WRIT" check "$d/config-space-v2.writ" --claims "$c" 2>&1)
  has "config-space:    an operation the claims never acknowledged" "$v2" \
    "unadmitted  enable-new-billing may break audit-when-multi-tenant"

  dv=$("$WRIT" derive "$d/config-space.writ" "$d/config-space.rules" final-db 2>&1)
  has "config-space: H. the last phase is the sharded configurations" "$dv" "final-db  (9 rows)"
  lacks "config-space:    and only those" "$dv" "single"
}

on_call_rota() {
  d="$here/on-call-rota"
  c="$d/on-call-rota.claims"
  echo "== An on-call rota — does one exist, and what did the policy not say? =="
  echo "   Q: six weeks, four people, the policy as written: is there a rota?"
  out=$("$WRIT" check "$d/on-call-rota.writ" --claims "$c" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "on-call-rota: the policy reports a finding" "$st" 1
  has "on-call-rota: A. a rota exists" "$out" "holds  rota-exists"
  near "on-call-rota:    and the witness IS the rota, week 1 first" "$out" "holds  rota-exists" "1. ann-takes-w1"
  has "on-call-rota:    through to week 6" "$out" "6. bob-takes-w6"
  has "on-call-rota: B. ten rotas in all, every one a dead end of six moves" "$out" "dead ends: 10"
  has "on-call-rota: C. the policy is silent on handing over into leave, twice" "$out" "gaps: 2"
  has "on-call-rota:    Bob before his week away" "$out" "bob-takes-w2 — \"the policy does not say"
  has "on-call-rota: D. and one first assignment strands the planner" "$out" "fails  no-dead-end-prefix"
  near "on-call-rota:    giving Cat week 1" "$out" "fails  no-dead-end-prefix" "1. cat-takes-w1"

  sc=$("$WRIT" check "$d/on-call-rota-strict.writ" --claims "$c" 2>&1)
  printf '%s\n' "$sc" | sed 's/^/     | /'
  has "on-call-rota: E. one more rule, and no rota exists" "$sc" "fails  rota-exists"
  # How far it gets: three weeks. Week 4 has nobody left, which is the
  # argument the README spells out, ending at the gap.
  has "on-call-rota:    every attempt stops after week 3" "$sc" "reached by: ann-takes-w1, cat-takes-w2, ann-takes-w3"
  has "on-call-rota:    unless the gap is answered" "$sc" "cat-takes-w3 — \"the policy does not say"

  cmp=$("$WRIT" compare "$d/on-call-rota.writ" "$d/on-call-rota-strict.writ" 2>&1)
  has "on-call-rota: F. compare: the rota is LOST, with no witness to give" "$cmp" "rota-exists  LOST"

  dv=$("$WRIT" derive "$d/on-call-rota.writ" "$d/on-call-rota.rules" rota 2>&1)
  has "on-call-rota: G. derive reads every rota out as rows" "$dv" "rota  (60 rows)"
  has "on-call-rota:    one row per week" "$dv" "17  w6  bob"
}

change_an_enum() {
  d="$here/db-migration-problems/change-an-enum"
  echo "== Adding a value to an enum — and writing it before every reader knows it =="
  echo "   Q: widening a CHECK is instant. When is the migration, really?"
  has "change-an-enum: writ sql reads the CHECK as two members before" \
    "$("$WRIT" sql "$d/01-before.sql" 2>/dev/null)" "(type tickets-status (open closed))"
  has "change-an-enum:    and three after" \
    "$("$WRIT" sql "$d/02-add-value.sql" 2>/dev/null)" "(type tickets-status (open closed archived))"

  ok_=$("$WRIT" check "$d/change-an-enum.writ" --claims "$d/change-an-enum.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "change-an-enum: the plan is clean" "$ost" 0
  has "change-an-enum: A. a ticket can be archived" "$ok_" "holds  completes"
  lacks "change-an-enum:    nothing is violated" "$ok_" "violated in"

  sc=$("$WRIT" check "$d/change-an-enum-shortcut.writ" --claims "$d/change-an-enum.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "change-an-enum: archiving during the rollout is refused" "$sst" 1
  has "change-an-enum: B. the first write of the value, while r1 still reads" "$sc" \
    "violated in 1 reachable situations   witness: 1. add-value 2. deploy-r2 3. archive-t1"
  # The database's own check is satisfied throughout: the value is allowed.
  nviol=$(printf '%s\n' "$sc" | grep -c "violated in")
  if [ "$nviol" = "1" ]; then
    ok "change-an-enum: C. and only the rule the database cannot check breaks"
  else
    bad "change-an-enum: C. expected exactly one violated rule, got $nviol"
  fi
}

split_a_table() {
  d="$here/db-migration-problems/split-a-table"
  echo "== Splitting a table — dual write, backfill, switch, contract =="
  echo "   Q: when may reads switch to the new table?"
  has "split-a-table: writ sql reads the new table's foreign key as an arrow" \
    "$("$WRIT" sql "$d/02-create-addresses.sql" 2>/dev/null)" "(fk user-id users)"

  ok_=$("$WRIT" check "$d/split-a-table.writ" --claims "$d/split-a-table.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "split-a-table: the plan is clean" "$ost" 0
  has "split-a-table: A. the move can finish" "$ok_" "holds  completes"
  lacks "split-a-table:    nothing is violated" "$ok_" "violated in"

  sc=$("$WRIT" check "$d/split-a-table-shortcut.writ" --claims "$d/split-a-table.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "split-a-table: switching on a started backfill is refused" "$sst" 1
  # The longest route to a fault in the collection: five steps, every one of
  # them in the runbook's order.
  has "split-a-table: B. reads switch to a half-filled table, five steps in" "$sc" \
    "violated in 3 reachable situations   witness: 1. create-table 2. deploy-r2 3. settle 4. backfill-start 5. deploy-r3"
  has "split-a-table:    and it is the completeness rule that breaks" "$sc" "equation complete-before-read"
}

add_a_foreign_key() {
  d="$here/db-migration-problems/add-a-foreign-key"
  echo "== Adding a foreign key, NOT VALID — the rows are spared, the code is not =="
  echo "   Q: NOT VALID skips the old rows. Does it make adding the key safe?"
  # Recorded as found: writ sql reads NOT VALID as an ordinary foreign key —
  # the output is the same with or without it, and --strict accepts it —
  # while it declines VALIDATE CONSTRAINT. The model carries the state.
  "$WRIT" sql "$d/02-add-not-valid.sql" --with-data --strict >/dev/null 2>&1
  exit_is "add-a-foreign-key: writ sql accepts NOT VALID, as a plain foreign key" "$?" 0
  has "add-a-foreign-key:    reading it as an arrow" \
    "$("$WRIT" sql "$d/02-add-not-valid.sql" 2>/dev/null)" "(fk customer-id customers)"
  vs=$("$WRIT" sql "$d/03-validate.sql" --with-data --strict 2>&1)
  vst=$?
  exit_is "add-a-foreign-key:    and declines VALIDATE CONSTRAINT under --strict" "$vst" 1
  has "add-a-foreign-key:    saying why" "$vs" "ALTER TABLE that adds no constraint"

  ok_=$("$WRIT" check "$d/add-a-foreign-key.writ" --claims "$d/add-a-foreign-key.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "add-a-foreign-key: the plan is clean" "$ost" 0
  has "add-a-foreign-key: A. the constraint can end up validated" "$ok_" "holds  completes"
  lacks "add-a-foreign-key:    nothing is violated" "$ok_" "violated in"

  sc=$("$WRIT" check "$d/add-a-foreign-key-shortcut.writ" --claims "$d/add-a-foreign-key.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "add-a-foreign-key: adding it mid-rollout is refused" "$sst" 1
  has "add-a-foreign-key: B. two steps: the old code's deletes now fail" "$sc" \
    "violated in 1 reachable situations   witness: 1. deploy-r2 2. add-not-valid"
  has "add-a-foreign-key:    the every-writer rule, a third time" "$sc" "equation enforced-means-every-writer-complies"
}

# The scenarios, in order — the single source of truth for `all`, numbering
# (1-based, as `list` prints), and name lookup. Each is a function above.
scenarios="river island queens jobshop_possible jobshop_best two_phase_commit arch timetable rename_a_column drop_a_column add_a_required_column change_an_enum split_a_table add_a_foreign_key separation_of_duties scp_escalation joiner_mover_leaver expense_approval agent_guardrails deployment payments config_space on_call_rota control gitcompare crosscheck"

list_scenarios() {
  echo "tests (run one by name or number, e.g. '$0 3' or '$0 river'):"
  i=1
  for s in $scenarios; do
    printf '  %d. %s\n' "$i" "$s"
    i=$((i + 1))
  done
}

nth() { # 1-based index -> scenario name on stdout (nothing if out of range)
  i=1
  for s in $scenarios; do
    [ "$i" = "$1" ] && {
      echo "$s"
      return 0
    }
    i=$((i + 1))
  done
}

timetable() {
  echo "== A timetable a CP-SAT solver decided =="
  echo "   Q: does it deliver the curriculum, could a school live with it, and"
  echo "      what did the curriculum forget to say?"
  out=$("$WRIT" check "$here/timetable/timetable.writ" --claims "$here/timetable/timetable.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "timetable: check reports findings" "$st" 1
  has "timetable: ONE state — a decided timetable has nothing left to vary" "$out" "states: 1"
  has "timetable: A. every hour the programme demands is delivered" "$out" "holds  curriculum-delivered"
  has "timetable:    and no lesson nobody asked for" "$out" "holds  nothing-extra"
  has "timetable:    nothing is in two places at once" "$out" "holds  no-room-clash"
  has "timetable:    every room is the right kind, and big enough" "$out" "holds  room-big-enough"
  has "timetable:    every teacher is qualified and available" "$out" "holds  teacher-qualified"
  has "timetable: B. but a group starts a day with sport" "$out" "fails  sport-not-first"
  has "timetable:    and is sent from sport straight into a lesson" "$out" "fails  time-to-change-after-sport"
  has "timetable: C. two questions the curriculum never answered" "$out" "gaps: 2"
  has "timetable:    may a group have a free period BETWEEN lessons?" "$out" "window-unstated"
  has "timetable:    may two hours of one subject fall on one day?" "$out" "doubling-unstated"

  # The SAME question suite, put to the week solved with those findings encoded.
  out=$("$WRIT" check "$here/timetable/timetable-strict.writ" --claims "$here/timetable/timetable.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "timetable: D. the tightened week has nothing to report" "$st" 0
  lacks "timetable:    no property fails" "$out" "fails  "
  has "timetable:    and no silence is reached" "$out" "gaps: none"

  # And the difference between the two weeks is a tool operation.
  out=$("$WRIT" compare "$here/timetable/timetable.writ" "$here/timetable/timetable-strict.writ" 2>&1)
  printf '%s\n' "$out" | sed 's/^/     | /'
  has "timetable: E. the school rules were GAINED" "$out" "sport-not-first             gained"
  has "timetable:    and nothing was lost to buy them" "$out" "curriculum-delivered        preserved"
}

unknown() {
  printf '%s\n' "$1" >&2
  list_scenarios >&2
  exit 2
}

sel=${1:-all}
case "$sel" in
list | -l | --list)
  list_scenarios
  exit 0
  ;;
all)
  n=0
  for s in $scenarios; do
    [ "$n" = 0 ] || echo
    "$s"
    n=1
  done
  ;;
*[!0-9]*) # a name
  case " $scenarios " in
  *" $sel "*) "$sel" ;;
  *) unknown "unknown test: $sel" ;;
  esac
  ;;
*) # a number
  name=$(nth "$sel")
  [ -n "$name" ] && "$name" || unknown "no test #$sel"
  ;;
esac

echo
echo "-------- $pass checks passed, $fail failed --------"
[ "$fail" -eq 0 ]
