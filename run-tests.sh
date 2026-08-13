#!/bin/sh
# Copyright (C) 2026 Alex Kunich
# SPDX-License-Identifier: AGPL-3.0-or-later
# End-to-end tests: SOLVE the Prologue puzzles with `pol` and check the answers
# — including the SOLUTION PATH `pol` prints (the witness under a holding
# `possible`). Each `pol check` exits 1 because it HAS findings to report — that
# is the correct outcome here (a blunder IS possible; the census ISN'T
# completable) — so the tests assert exit 1.
#
# Usage:  run-tests.sh [NAME | NUMBER | all | list]   (default: all)
#   run-tests.sh list      # the numbered menu
#   run-tests.sh 3         # run test #3 by number
#   run-tests.sh river     # run one by name
# `pol` is taken from $POL (default: the one on PATH).
set -u

here=$(cd "$(dirname "$0")" && pwd)
POL=${POL:-pol}
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
  out=$("$POL" check "$here/river/river.pol" --claims "$here/river/river.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "river: check reports findings" "$st" 1
  has "river: 36 reachable arrangements" "$out" "states: 36"
  has "river: A. the crossing IS solvable" "$out" "holds  solvable"
  near "river:    and pol SHOWS a real, safe crossing (the solution path)" "$out" "holds  solvable" "witness:"
  near "river:    that brings the goat BACK — the hallmark of the real solution" "$out" "holds  solvable" "cross-goat-RL"
  near "river:    before ferrying the cabbage across" "$out" "holds  solvable" "cross-cabbage-LR"
  has "river: B. but a careless crossing dooms it" "$out" "fails  no-blunders"
  near "river:    pol names the blundering move" "$out" "fails  no-blunders" "witness:"
  near "river:    stranding prey with its predator is the mistake" "$out" "fails  no-blunders" "stuck at:"
}

queens() {
  echo "== Eight queens =="
  echo "   Q: can eight queens stand on a board with none attacking another?"
  out=$("$POL" check "$here/queens/queens.pol" --claims "$here/queens/queens.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /' | head -14
  exit_is "queens: check exits clean — nothing is wrong with the board" "$st" 0
  has "queens: 2057 situations, the column-ordered search tree" "$out" "states: 2057"
  has "queens: A. eight queens CAN be placed" "$out" "holds  solvable"
  near "queens:    and pol shows where they go" "$out" "holds  solvable" "witness:"
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

island() {
  echo "== Knights & knaves (kernel-spec Appendix D) =="
  echo "   Q: can every native be classified, and who could be a knight?"
  out=$("$POL" check "$here/island/island.pol" --claims "$here/island/island.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "island: check reports findings" "$st" 1
  has "island: 9 reachable situations" "$out" "states: 9"
  has "island: A. the rules run out — a gap" "$out" "gaps: 1"
  has "island:    the hole is reading cal, the knave-sayer" "$out" "read-cal —"
  has "island:    the rules are silent there" "$out" "rules are silent"
  has "island: B. NOT everyone is classifiable" "$out" "fails  census-completable"
  has "island: C. abe could be a knight" "$out" "holds  abe-can-be-knight"
  near "island:    and pol shows the reading that makes it so" "$out" "holds  abe-can-be-knight" "abe-is-knight"
  has "island:    bea could be a knight" "$out" "holds  bea-can-be-knight"
  has "island:    cal could be nothing at all" "$out" "fails  cal-can-be-knight"
}

jobshop_possible() {
  echo "== A blocking job shop =="
  echo "   Q: three jobs, three machines, no buffers — can every schedule still"
  echo "      finish, or can the shop walk into a deadlock?"
  out=$("$POL" check "$here/jobshop-possible/jobshop-possible.pol" --claims "$here/jobshop-possible/jobshop-possible.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "jobshop-possible: check reports findings" "$st" 1
  has "jobshop-possible: 51 reachable schedules" "$out" "states: 51"
  has "jobshop-possible: A. some schedule finishes every job" "$out" "holds  all-finish"
  near "jobshop-possible:    and pol shows one" "$out" "holds  all-finish" "witness:"
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
  out=$("$POL" check "$here/jobshop-best/jobshop-best.pol" \
    --claims "$here/jobshop-best/jobshop-best.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "jobshop-best: check reports a finding (the too-tight bound)" "$st" 1
  has "jobshop-best: 1314 situations — the shop times the clock" "$out" "states: 1314"
  has "jobshop-best: A. four ticks is NOT enough" "$out" "fails  done-by-4"
  has "jobshop-best: B. five ticks is — the optimum, pinned from both sides" "$out" \
    "holds  done-by-5"
  near "jobshop-best:    and pol prints the optimal schedule" "$out" \
    "holds  done-by-5" "witness:"
  # The optimum overlaps a and b while holding c back — which is exactly what
  # jobshop-possible proved was necessary, since all three in the shop at once
  # is the deadlock.
  near "jobshop-best:    it starts two jobs in the first tick" "$out" \
    "holds  done-by-5" "b-enters"
  near "jobshop-best:    and only then advances the clock" "$out" \
    "holds  done-by-5" "3. tick"
}

oversight() {
  echo "== Institutional architecture (kernel-spec §3, §4 running example) =="
  echo "   Q: can one lawful move permanently destroy accountability, and what"
  echo "      does repealing restoration actually cost?"
  out=$("$POL" check "$here/oversight/oversight.pol" --claims "$here/oversight/oversight.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "oversight: check reports findings" "$st" 1
  has "oversight: A. our own powers can violate our own law" "$out" "equation same-agency"
  has "oversight:    the law's breakers are named" "$out" "can be broken by: capture-watchdog, restore-watchdog"
  lacks "oversight:    and both are accepted — nothing unadmitted" "$out" "unadmitted"
  has "oversight: B. the case can conclude" "$out" "holds  conviction-possible"
  near "oversight:    and pol prints the concluding move" "$out" "holds  conviction-possible" "witness:"
  has "oversight: C. accountability holds (restoration exists)" "$out" "holds  accountability"

  echo "   Q: this amendment repeals restoration — what does it change?"
  cmp=$("$POL" compare "$here/oversight/oversight.pol" "$here/oversight/oversight-repeal.pol" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "oversight: compare reports a loss" "$cst" 1
  has "oversight: D. the repeal LOSES accountability" "$cmp" "accountability       LOST"
  near "oversight:    one capture now traps the case forever" "$cmp" "accountability" "capture-watchdog"
  has "oversight:    same-agency itself is preserved" "$cmp" "same-agency          preserved"
}

workflow() {
  echo "== Regulated workflow — KYC / claims (kernel-spec §3) =="
  echo "   Q: where does automation end, which reassignments break the law, and"
  echo "      can a case get stuck?"
  out=$("$POL" check "$here/workflow/workflow.pol" --claims "$here/workflow/workflow.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "workflow: check reports findings" "$st" 1
  has "workflow: A. automation ends at an escalation gap" "$out" "gaps: 1"
  has "workflow:    the gap hands off to a human" "$out" "escalated to a human"
  has "workflow: B. the unit-of-record law's breakers are named" "$out" "can be broken by: reassign-to-fraud, reassign-to-kyc"
  lacks "workflow:    and both reassignments are accepted" "$out" "unadmitted"
  has "workflow: C. no case gets stuck — always still settleable" "$out" "holds  settle-able"
  has "workflow:    and the assignee slot stays fillable" "$out" "holds  assignee-fillable"
}

two_phase_commit() {
  d="$here/two-phase-commit"
  echo "== Two-phase commit — agreeing to commit across parties that can fail =="
  echo "   Q: can the parties disagree, can they be left waiting for ever, and"
  echo "      what does the obvious cure for the waiting cost?"
  out=$("$POL" check "$d/two-phase-commit.pol" --claims "$d/two-phase-commit.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /' | grep -v 'reached by:'
  exit_is "2pc: check reports findings" "$st" 1
  has "2pc: 84 situations of two participants and a coordinator" "$out" "states: 84"

  has "2pc: A. ATOMICITY holds — never one committed and another aborted" "$out" "holds  atomic"
  has "2pc:    and committing is actually reachable" "$out" "holds  can-commit"
  near "2pc:    with the route that gets there" "$out" "holds  can-commit" "witness:"

  # The textbook blocking result, and pol finds it in two moves: one participant
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
  lossy=$("$POL" check "$d/two-phase-commit-lossy.pol" --claims "$d/two-phase-commit.claims" 2>&1)
  printf '%s\n' "$lossy" | sed 's/^/     | /' | grep -v 'reached by:'
  has "2pc: D. over a network that drops and resends, deciding stays REACHABLE" "$lossy" "holds  can-decide"
  has "2pc:    and yet a run can decline it for ever" "$lossy" "fails  must-decide"
  near "2pc:    naming the situation the run circles in" "$lossy" "fails  must-decide" "c.decision=commit"
  has "2pc:    assume the told participant applies, and it terminates" "$lossy" "holds  must-decide-if-applied"

  # The trade, priced. Letting a stranded participant give up buys every
  # liveness property and sells the one the protocol exists for.
  cmp=$("$POL" compare "$d/two-phase-commit.pol" "$d/two-phase-commit-timeout.pol" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "2pc: E. compare reports a lost guarantee" "$cst" 1
  has "2pc:    the timeout cure LOSES atomicity" "$cmp" "atomic                  LOST"
  has "2pc:    and pol prints the run that breaks it" "$cmp" "p2-timeout"
  has "2pc:    while every liveness property is gained" "$cmp" "must-decide             gained"
  has "2pc:    including the plain reachability one" "$cmp" "can-decide              gained"
}

access() {
  echo "== Access & privilege (kernel-spec §3) =="
  echo "   Q: is revocation always possible, or is some privilege permanent?"
  out=$("$POL" check "$here/access/access.pol" --claims "$here/access/access.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "access: check reports findings" "$st" 1
  has "access: A. the root-tracing law's breaker is named" "$out" "can be broken by: delegate-alice-to-mallory"
  lacks "access:    and the delegation is accepted" "$out" "unadmitted"
  has "access: B. revocation is NOT always possible — a latch" "$out" "fails  revocation-possible"
  near "access:    the break-glass grant is the latching move" "$out" "fails  revocation-possible" "grant-breakglass-admin"
  near "access:    it strands the state with mallory admin forever" "$out" "fails  revocation-possible" "mallory.role=admin"
  has "access: C. the admins query is answered" "$out" "admins  (at state"
}

gotha() {
  echo "== A claim about common ownership, put to the test =="
  echo "   Q: \"once the means of production are held in common, no surplus is"
  echo "      disposed of by anyone who does not work them\" — does it survive?"
  out=$("$POL" check "$here/gotha/gotha.pol" --claims "$here/gotha/gotha.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "gotha: check reports findings" "$st" 1
  has "gotha: seven situations — the whole world of the claim" "$out" "states: 7"
  has "gotha: A. the antecedent is reached: the mill DOES become common" "$out" \
    "holds  expropriation-succeeds"
  near "gotha:    expropriation, then distribution to the weavers" "$out" \
    "holds  expropriation-succeeds" "1. expropriate"
  has "gotha: B. and the claim is REFUTED" "$out" "fails  no-exploitation"
  near "gotha:    the falsifier begins with the expropriation itself" "$out" \
    "fails  no-exploitation" "1. expropriate"
  near "gotha:    someone must administer the deductions" "$out" \
    "fails  no-exploitation" "2. appoint-board"
  near "gotha:    and Gotha's own second deduction is what breaks it" "$out" \
    "fails  no-exploitation" "3. fund-administration"
  has "gotha: C. but the condition is not a trap — recall still works" "$out" \
    "holds  exploitation-endable"
  has "gotha: D. the programme's own law is broken before AND after" "$out" \
    "violated in 3 reachable situations"
  has "gotha:    by the three moves that write the surplus" "$out" \
    "can be broken by: expropriate, distribute, fund-administration"
  lacks "gotha:    all three acknowledged — nothing unadmitted" "$out" "unadmitted"
  has "gotha: E. and the non-producers are named" "$out" "non-producers  (at state"

  echo "   Q: does the rules engine reach the same three verdicts?"
  xc=$(POL="$POL" sh "$here/gotha/cross-check.sh" 2>&1)
  xst=$?
  printf '%s\n' "$xc" | sed 's/^/     | /'
  exit_is "gotha: check and derive agree on all three" "$xst" 0
  has "gotha:    the refutation survives a second implementation" "$xc" \
    "no-exploitation (never): 1 rows"
}

calculation() {
  echo "== The calculation problem — one allotment of steel, three plants =="
  echo "   Q: two economies differing in ONE guard, asked the SAME questions —"
  echo "      which guarantees does the difference cost?"

  echo "   1/2: prices — the ask must be backed by the plant's own need"
  mkt=$("$POL" check "$here/calculation/market.pol" --claims "$here/calculation/market.claims" 2>&1)
  mst=$?
  printf '%s\n' "$mkt" | sed 's/^/     | /'
  exit_is "calculation: the priced model is clean" "$mst" 0
  has "calculation: A. the steel can reach a plant that needs it" "$mkt" "holds  need-can-be-met"
  near "calculation:    and pol prints the route it takes" "$mkt" "holds  need-can-be-met" "allocate-clinic"
  has "calculation:    it is never built where it is not needed" "$mkt" "holds  no-waste"
  has "calculation:    and that stays true from every situation" "$mkt" "holds  need-always-still-meetable"
  lacks "calculation:    the model's own law is never violated" "$mkt" "violated in"
  lacks "calculation:    and nothing is unadmitted" "$mkt" "unadmitted"

  echo "   2/2: the plan — the same file with that one conjunct repealed"
  pln=$("$POL" check "$here/calculation/planned.pol" --claims "$here/calculation/market.claims" 2>&1)
  pst=$?
  printf '%s\n' "$pln" | sed 's/^/     | /'
  exit_is "calculation: the planned model reports findings" "$pst" 1
  has "calculation: B. the plan is NOT incapable — it can still get it right" "$pln" "holds  need-can-be-met"
  has "calculation:    but waste is permitted by its rules" "$pln" "fails  no-waste"
  near "calculation:    a costless request is what buys the steel" "$pln" "fails  no-waste" "ask-monument-high"
  near "calculation:    and the monument gets it" "$pln" "fails  no-waste" "allocate-monument"
  has "calculation: C. and the waste is terminal, not a delay" "$pln" "fails  need-always-still-meetable"
  near "calculation:    steel welded into a statue is steel no longer" "$pln" "fails  need-always-still-meetable" "steel.state=built"
  has "calculation: D. it violates the law both models declare" "$pln" "violated in 24 reachable situations"
  has "calculation:    and has no procedure for what requests omit" "$pln" "gaps: 1"
  has "calculation:    which is written down as a gap, not invented" "$pln" "no request carries"
  lacks "calculation:    the same nine acknowledgments serve both models" "$pln" "unadmitted"

  echo "   Q: what does the repeal cost, as one command?"
  cmp=$("$POL" compare "$here/calculation/market.pol" "$here/calculation/planned.pol" 2>&1)
  cst=$?
  printf '%s\n' "$cmp" | sed 's/^/     | /'
  exit_is "calculation: compare reports a loss" "$cst" 1
  has "calculation: E. no-waste is LOST" "$cmp" "no-waste                    LOST"
  has "calculation:    and so is the recovery from waste" "$cmp" "need-always-still-meetable  LOST"
  has "calculation:    while the ability to get it right is preserved" "$cmp" "need-can-be-met             preserved"

  echo "   Q: does the rules engine reach the same verdicts, for BOTH models?"
  xc=$(POL="$POL" sh "$here/calculation/cross-check.sh" 2>&1)
  xst=$?
  printf '%s\n' "$xc" | sed 's/^/     | /'
  exit_is "calculation: check and derive agree on all six" "$xst" 0
  has "calculation:    including the plan's failing never" "$xc" \
    "planned/no-waste (never): 8 rows"
}

arch() {
  echo "== System architecture from a component bank =="
  echo "   Q: 50TB of files to classify, re-runnably, then feed AI and surface"
  echo "      in a CRM — which architectures satisfy that, and what does the"
  echo "      brief fail to say?"
  out=$("$POL" check "$here/arch/arch.pol" --claims "$here/arch/arch.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /' | grep -v 'reached by'
  exit_is "arch: check reports findings" "$st" 1
  # The cost law of the core README, as a regression: seven stages admitting
  # 1,2,2,2,3,2,2 parts give 1*2*2*2*3*2*2 = 96 designs, and the situations are
  # their prefixes — 1+1+2+4+8+24+48+96 = 184, under the 2x bound.
  has "arch: 184 situations — the prefixes of 96 designs" "$out" "states: 184"
  has "arch: A. 96 architectures survive the constraints" "$out" "dead ends: 96"
  has "arch:    and one can be realised" "$out" "holds  realisable"
  near "arch:    pol prints it, stage by stage" "$out" "holds  realisable" "witness:"
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
  bp=$("$POL" derive "$here/arch/arch.pol" "$here/arch/arch.rules" \
    "(blueprint 183 K C)" 2>&1)
  bst=$?
  printf '%s\n' "$bp" | sed 's/^/     | /'
  exit_is "arch: derive answers the blueprint" "$bst" 0
  has "arch: F. seven stages, one part each" "$bp" "blueprint  (7 rows)"
  has "arch:    storage is named" "$bp" "hold  object-store"
  has "arch:    and the CRM edge is named" "$bp" "surface  ipaas"
}

control() {
  echo "== pol control — a model's dynamics as data (kernel-spec §17) =="
  echo "   Q: can we export the move list and re-use it with the same machinery?"
  out=$("$POL" control "$here/oversight/oversight.pol" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "control: emits cleanly" "$st" 0
  has "control: it is an instance of the stdlib quiver schema" "$out" "-control quiver"
  has "control: an edge per transition — capture-watchdog" "$out" "capture-watchdog"
  has "control:    ... and assign-judge" "$out" "assign-judge"
  # Prove the emitted quiver is real data: wrap it as a model and re-check it.
  tmp=$(mktemp -d)
  printf '%s\n' "$out" >"$tmp/ctrl.pol"
  printf '(load "ctrl.pol")\n(use quiver)\n(initial oversight-control)\n' >"$tmp/wrap.pol"
  if (cd "$tmp" && "$POL" check wrap.pol >/dev/null 2>&1); then
    ok "control: the emitted quiver re-parses and builds"
  else bad "control: the emitted quiver did not re-parse"; fi
  rm -rf "$tmp"
}

gitcompare() {
  echo "== pol compare --git — an amendment across commits (kernel-spec §17) =="
  echo "   Q: two git revisions of one model — what did the amendment cost?"
  if ! command -v git >/dev/null 2>&1; then
    printf '  [skip] pol compare --git needs git (not installed here)\n'
    return 0
  fi
  # A self-contained history: commit the law, then commit the repeal, in a
  # throwaway repo — so the demo is deterministic and needs no shared history.
  tmp=$(mktemp -d)
  cp "$here/oversight/oversight.pol" "$tmp/law.pol"
  cp "$here/oversight/oversight.claims" "$tmp/law.claims"
  (cd "$tmp" && git init -q && git add law.pol law.claims &&
    git -c user.email=t@t -c user.name=t commit -qm "v1: with restoration") >/dev/null 2>&1
  cp "$here/oversight/oversight-repeal.pol" "$tmp/law.pol"
  (cd "$tmp" && git add law.pol &&
    git -c user.email=t@t -c user.name=t commit -qm "amendment: repeal restoration") >/dev/null 2>&1
  out=$(cd "$tmp" && "$POL" compare --git HEAD~1 HEAD law.pol 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "git-compare: the amendment loses a guarantee" "$st" 1
  has "git-compare: accountability is LOST across the two commits" "$out" "accountability       LOST"
  has "git-compare: same-agency is preserved" "$out" "same-agency          preserved"
  rm -rf "$tmp"
}

crosscheck() {
  echo "== The modality cross-check — two implementations of one question =="
  echo "   Q: does the rules engine, asked the SAME properties over the SAME"
  echo "      space, reach the same verdicts as \`pol check\`?"
  out=$(POL="$POL" sh "$here/modality-cross-check.sh" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "cross-check: the two implementations agree everywhere" "$st" 0
  # The thirteen scenarios this script walks by convention, and their 31
  # properties. `calculation/` and `gotha/` are not among them: each carries its
  # own explicit cross-check.sh, run from its own test function above. Adding a
  # property to any of the thirteen fails this line, which is the point of it —
  # the count went 20 -> 22 -> 26 as the three db-migration-problems joined, and
  # 26 -> 31 with two-phase-commit, and this line is where each of those had to
  # be said out loud.
  has "cross-check: all 31 properties of the thirteen scenarios were considered" \
    "$out" "considered 31 properties"
  # One of the 31 is not compared, and the count above is the only place that
  # would notice if the reason changed: two-phase-commit asks one property under
  # a fairness assumption, which ct.rules §8 does not encode.
  has "cross-check:    with the one fair property skipped, and saying why" \
    "$out" "carries (fair …) — no rules encoding, skipped"
  has "cross-check: A. a possible is its satisfying set — non-empty holds" \
    "$out" "river/solvable  possible: satisfying set of"
  has "cross-check: B. a live is its COUNTEREXAMPLE set — empty holds" \
    "$out" "workflow/settle-able  live: counterexample set of 0"
  has "cross-check:    and a failing live names its witnesses" \
    "$out" "access/revocation-possible  live: counterexample set of 4"
  # `arch` brought the repository's first two `never` properties, so this
  # branch — which announced itself as unexercised on every prior run — is now
  # measured. If it ever reads "unexercised" again, a scenario went missing.
  # two-phase-commit's atomicity is the third.
  has "cross-check: C. the never branch is exercised" "$out" \
    "never: 3 properties compared"
  # And `inevitable`, whose two are two-phase-commit's — the newest modality,
  # and the one whose second implementation is newest, so the line that says it
  # is being compared at all is worth having.
  has "cross-check: D. the inevitable branch is exercised too" "$out" \
    "inevitable: 2"
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

  echo "   1/4: the DDL, read by \`pol sql\` — users generate SQL, not .pol"
  tmp=$(mktemp -d)
  for f in 01-before 02-expand 03-contract; do
    "$POL" sql "$here/db-migration-problems/rename-a-column/$f.sql" --with-data >"$tmp/$f.pol" 2>/dev/null
  done
  exp=$(cat "$tmp/02-expand.pol")
  # The expand step's whole content is that the new column is NULLABLE, which
  # `pol sql` writes as one character: `text?` rather than `text`.
  has "rename-a-column: the expand adds the column as NULLABLE" "$exp" "(text? full-name)"
  has "rename-a-column:    while the old column stays required" "$exp" "(text name)"
  bef=$(cat "$tmp/01-before.pol")
  lacks "rename-a-column:    and before the expand it does not exist" "$bef" "full-name"
  con=$(cat "$tmp/03-contract.pol")
  lacks "rename-a-column:    after the contract the old one is gone" "$con" "(text name)"
  for f in 01-before 02-expand 03-contract; do
    if (cd "$tmp" && "$POL" check "$f.pol" >/dev/null 2>&1); then
      ok "rename-a-column:    $f builds as a model"
    else bad "rename-a-column:    $f did not build"; fi
  done
  # The same expand with NOT NULL is not merely different, it is REFUSED: the
  # representative row has no value for a column that did not exist yet.
  "$POL" sql "$here/db-migration-problems/rename-a-column/02-expand-wrong.sql" --with-data \
    >"$tmp/wrong.pol" 2>/dev/null
  wrong=$(cd "$tmp" && "$POL" check wrong.pol 2>&1)
  wst=$?
  printf '%s\n' "$wrong" | sed 's/^/     | /'
  exit_is "rename-a-column: NOT NULL on the new column is refused" "$wst" 2
  has "rename-a-column:    and it names the row that cannot exist" "$wrong" "users.full-name for u1"
  rm -rf "$tmp"

  echo "   2/4: the plan"
  mg=$("$POL" check "$here/db-migration-problems/rename-a-column/rename-a-column.pol" --claims "$here/db-migration-problems/rename-a-column/rename-a-column.claims" 2>&1)
  mst=$?
  printf '%s\n' "$mg" | sed 's/^/     | /'
  exit_is "rename-a-column: the plan is clean" "$mst" 0
  has "rename-a-column: A. the rename can be finished" "$mg" "holds  completes"
  near "rename-a-column:    and pol prints the runbook, which nobody wrote" "$mg" "holds  completes" "add-column"
  near "rename-a-column:    the backfill comes before the readers switch" "$mg" "holds  completes" "backfill"
  has "rename-a-column: B. and no step strands production half-migrated" "$mg" "holds  no-dead-ends"
  lacks "rename-a-column:    no law is violated" "$mg" "violated in"
  lacks "rename-a-column:    and every breakable law is acknowledged" "$mg" "unadmitted"

  echo "   3/4: the shortcut — the same file, ONE conjunct lighter"
  sc=$("$POL" check "$here/db-migration-problems/rename-a-column/rename-a-column-shortcut.pol" --claims "$here/db-migration-problems/rename-a-column/rename-a-column.claims" 2>&1)
  sst=$?
  printf '%s\n' "$sc" | sed 's/^/     | /'
  exit_is "rename-a-column: the shortcut reports findings" "$sst" 1
  has "rename-a-column: C. a reader goes out before the backfill" "$sc" "violated in 5 reachable situations"
  near "rename-a-column:    and pol names the step that does it" "$sc" "violated in 5 reachable situations" "deploy-r3"
  has "rename-a-column: D. yet it still finishes — faster, which is the trap" "$sc" "holds  completes"
  has "rename-a-column:    and it never strands you either" "$sc" "holds  no-dead-ends"

  echo "   4/4: the verb that does NOT catch it"
  cm=$("$POL" compare "$here/db-migration-problems/rename-a-column/rename-a-column.pol" "$here/db-migration-problems/rename-a-column/rename-a-column-shortcut.pol" 2>&1)
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
  ok_=$("$POL" check "$d/drop-a-column.pol" --claims "$d/drop-a-column.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "drop-a-column: the plan is clean" "$ost" 0
  has "drop-a-column: A. the column can be dropped" "$ok_" "holds  completes"
  near "drop-a-column:    and the rollout finishes BEFORE the drop" "$ok_" "holds  completes" "settle"
  has "drop-a-column: B. and no step strands you" "$ok_" "holds  no-dead-ends"
  lacks "drop-a-column:    nothing is violated" "$ok_" "violated in"

  sc=$("$POL" check "$d/drop-a-column-shortcut.pol" --claims "$d/drop-a-column.claims" 2>&1)
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
  "$POL" sql "$d/02-add-nullable.sql" --with-data >"$tmp/step2.pol" 2>/dev/null
  has "add-a-required-column: the column arrives NULLABLE" "$(cat "$tmp/step2.pol")" "(text? country)"
  rm -rf "$tmp"

  ok_=$("$POL" check "$d/add-a-required-column.pol" --claims "$d/add-a-required-column.claims" 2>&1)
  ost=$?
  printf '%s\n' "$ok_" | sed 's/^/     | /'
  exit_is "add-a-required-column: the plan is clean" "$ost" 0
  has "add-a-required-column: A. the column can end up required" "$ok_" "holds  completes"
  near "add-a-required-column:    the deploy comes BEFORE the backfill" "$ok_" "holds  completes" "deploy-r2"
  has "add-a-required-column: B. and no step strands you" "$ok_" "holds  no-dead-ends"
  lacks "add-a-required-column:    nothing is violated" "$ok_" "violated in"

  sc=$("$POL" check "$d/add-a-required-column-shortcut.pol" --claims "$d/add-a-required-column.claims" 2>&1)
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

# The scenarios, in order — the single source of truth for `all`, numbering
# (1-based, as `list` prints), and name lookup. Each is a function above.
scenarios="river island queens jobshop_possible jobshop_best oversight workflow two_phase_commit access calculation gotha arch timetable rename_a_column drop_a_column add_a_required_column control gitcompare crosscheck"

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
  out=$("$POL" check "$here/timetable/timetable.pol" --claims "$here/timetable/timetable.claims" 2>&1)
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
  out=$("$POL" check "$here/timetable/timetable-strict.pol" --claims "$here/timetable/timetable.claims" 2>&1)
  st=$?
  printf '%s\n' "$out" | sed 's/^/     | /'
  exit_is "timetable: D. the tightened week has nothing to report" "$st" 0
  lacks "timetable:    no property fails" "$out" "fails  "
  has "timetable:    and no silence is reached" "$out" "gaps: none"

  # And the difference between the two weeks is a tool operation.
  out=$("$POL" compare "$here/timetable/timetable.pol" "$here/timetable/timetable-strict.pol" 2>&1)
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
