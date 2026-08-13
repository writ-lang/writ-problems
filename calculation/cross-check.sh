#!/bin/sh
# Copyright (C) 2026 Alex Kunich
# SPDX-License-Identifier: AGPL-3.0-or-later
# calculation's three questions, asked twice — and asked of BOTH models.
#
# `writ check` reads the modalities in market.claims as CTL (runtime/checker.ml).
# `writ derive` answers the same three questions from market.rules as relations
# over the same enumerated space. They are two implementations, so a
# disagreement is a bug in one of them — never a number to adjust here.
#
# The pair is the reason this is a script of its own: one claims file and one
# rules file are put to both models, so the falsifying verdicts under
# `planned.writ` are cross-checked too, and not just the clean ones under
# `market.writ`.
#
# One line per (model, property), naming its modality. The polarity is the only
# thing that turns a row count into a verdict:
#
#   possible   the SATISFYING set        non-empty = holds
#   never      the COUNTEREXAMPLE set    empty     = holds
#   live       the COUNTEREXAMPLE set    empty     = holds
#
# Usage:  cross-check.sh        (`writ` from $WRIT; default: the one on PATH)
set -u

here=$(cd "$(dirname "$0")" && pwd)
WRIT=${WRIT:-writ}
bad=0

cross() { # model  property  modality
  check=$("$WRIT" check "$here/$1.writ" --claims "$here/market.claims" 2>&1)
  rows=$("$WRIT" derive "$here/$1.writ" "$here/market.rules" "$2" 2>&1 | grep -c '^  ')
  case "$3" in
  possible) [ "$rows" -gt 0 ] && derived=holds || derived=fails ;;
  never | live) [ "$rows" -eq 0 ] && derived=holds || derived=fails ;;
  esac
  if printf '%s\n' "$check" | grep -qx "holds  $2"; then said=holds; else said=fails; fi

  if [ "$derived" = "$said" ]; then
    printf '  [ok]   %s/%s (%s): %s rows from derive, both say %s\n' "$1" "$2" "$3" "$rows" "$said"
  else
    printf '  [FAIL] %s/%s (%s): %s rows ⇒ derive says %s, check says %s\n' \
      "$1" "$2" "$3" "$rows" "$derived" "$said"
    bad=1
  fi
}

cross market  need-can-be-met            possible
cross market  no-waste                   never
cross market  need-always-still-meetable live

cross planned need-can-be-met            possible
cross planned no-waste                   never
cross planned need-always-still-meetable live

[ "$bad" -eq 0 ] || echo "a DISAGREEMENT — a finding to report, not a number to adjust"
exit "$bad"
