#!/bin/sh
# Copyright (C) 2026 Alex Kunich
# SPDX-License-Identifier: AGPL-3.0-or-later
# gotha's three questions, asked twice.
#
# `pol check` reads the modalities in gotha.claims as CTL (runtime/checker.ml).
# `pol derive` answers the same three questions from gotha.rules as relations
# over the same enumerated space. They are two implementations, so a
# disagreement is a bug in one of them — never a number to adjust here.
#
# One line per property, naming its modality. The polarity is the only thing
# that turns a row count into a verdict, and getting it backwards is the failure
# mode that leaves a cross-check green while meaning nothing:
#
#   possible   the SATISFYING set        non-empty = holds
#   never      the COUNTEREXAMPLE set    empty     = holds
#   live       the COUNTEREXAMPLE set    empty     = holds
#
# Usage:  cross-check.sh        (`pol` from $POL; default: the one on PATH)
set -u

here=$(cd "$(dirname "$0")" && pwd)
POL=${POL:-pol}
model="$here/gotha.pol"
check=$("$POL" check "$model" --claims "$here/gotha.claims" 2>&1)
bad=0

cross() { # property  modality
  rows=$("$POL" derive "$model" "$here/gotha.rules" "$1" 2>&1 | grep -c '^  ')
  case "$2" in
  possible) [ "$rows" -gt 0 ] && derived=holds || derived=fails ;;
  never | live) [ "$rows" -eq 0 ] && derived=holds || derived=fails ;;
  esac
  if printf '%s\n' "$check" | grep -qx "holds  $1"; then said=holds; else said=fails; fi

  if [ "$derived" = "$said" ]; then
    printf '  [ok]   %s (%s): %s rows from derive, both say %s\n' "$1" "$2" "$rows" "$said"
  else
    printf '  [FAIL] %s (%s): %s rows ⇒ derive says %s, check says %s\n' \
      "$1" "$2" "$rows" "$derived" "$said"
    bad=1
  fi
}

cross expropriation-succeeds possible
cross no-exploitation        never
cross exploitation-endable   live

[ "$bad" -eq 0 ] || echo "a DISAGREEMENT — a finding to report, not a number to adjust"
exit "$bad"
