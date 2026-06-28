#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# abi-ffi-gate.sh — fail (exit 1) if the Zig FFI does not conform to the Idris2
# ABI. The Idris2 ABI is the source of truth. Bash port of the former
# abi-ffi-gate.py (Python is banned estate-wide). No toolchain needed — only
# coreutils + grep/awk/sed. Checks:
#
#   1. the Zig FFI carries no unrendered `{{...}}` template tokens;
#   2. every `%foreign "C:<name>"` symbol declared anywhere in the ABI .idr
#      sources is exported by the Zig FFI (`export fn <name>`);
#   3. the Zig `Result = enum(c_int)` and the Idris `resultToInt` agree on BOTH
#      names and integer values (the `Error`/`err` spelling is treated as one).
#
# Usage: bash scripts/abi-ffi-gate.sh [repo_root]   (defaults to cwd)
set -uo pipefail

root="${1:-.}"
name="$(basename "$(cd "$root" 2>/dev/null && pwd || echo "$root")")"
abi_dir="$root/src/interface/abi"
zig_path="$root/src/interface/ffi/src/main.zig"

# canon(name): camelCase -> snake_case, lowercase, err -> error
canon() {
  printf '%s' "$1" \
    | sed -E 's/([a-zA-Z0-9])([A-Z])/\1_\2/g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/^err$/error/'
}

idr_files="$(find "$abi_dir" -name '*.idr' -not -path '*/build/*' 2>/dev/null | sort)"
if [ -z "$idr_files" ]; then
  echo "ABI-FFI GATE: SKIP ($name) — no Idris2 ABI .idr files under $abi_dir"
  exit 0
fi
if [ ! -f "$zig_path" ]; then
  echo "ABI-FFI GATE: FAIL ($name) — no Zig FFI at $zig_path"
  exit 1
fi

idr="$(cat $idr_files)"
zig="$(cat "$zig_path")"
errs=""

# 1. unrendered template tokens
toks="$(printf '%s\n' "$zig" | grep -oE '\{\{[A-Za-z0-9_]+\}\}' | sort -u | tr '\n' ' ')"
if [ -n "${toks// /}" ]; then
  errs="${errs}  - Zig FFI has unrendered template tokens: ${toks}
"
fi

# 2. foreign C symbols must be exported
csyms="$(printf '%s\n' "$idr" | grep -oE 'C:[A-Za-z0-9_]+' | sed 's/^C://' | sort -u | grep -v '^$')"
exports="$(printf '%s\n' "$zig" | grep -oE 'export fn [A-Za-z0-9_]+' | awk '{print $3}' | sort -u | grep -v '^$')"
missing="$(comm -23 <(printf '%s\n' "$csyms") <(printf '%s\n' "$exports") | tr '\n' ' ')"
ncsyms="$(printf '%s\n' "$csyms" | grep -vc '^$' || true)"
if [ -n "${missing// /}" ]; then
  errs="${errs}  - ABI function(s) not exported by the Zig FFI: ${missing}
"
fi

# 3. result-code map (names + values) must agree
idr_rc="$(printf '%s\n' "$idr" \
  | grep -oE 'resultToInt +[A-Za-z0-9]+ *= *[0-9]+' \
  | sed -E 's/resultToInt +([A-Za-z0-9]+) *= *([0-9]+)/\1 \2/' \
  | while read -r nm val; do echo "$(canon "$nm") $val"; done | sort -u)"
nrc="$(printf '%s\n' "$idr_rc" | grep -vc '^$' || true)"

# Parse each `enum (c_int) { ... }` block separately (variants up to the first
# `}`), tagged by a block id. Then in shell, canonicalise each block and pick
# the one whose `ok == 0` with the most variants — mirrors Python find_result_enum.
zig_raw="$(printf '%s\n' "$zig" | awk '
  /enum[ \t]*\([ \t]*c_int[ \t]*\)/ { cap=1; bid++ }
  cap {
    s=$0
    while (match(s, /@?"?[A-Za-z_][A-Za-z0-9_]*"?[ \t]*=[ \t]*[0-9]+/)) {
      seg=substr(s, RSTART, RLENGTH); s=substr(s, RSTART+RLENGTH)
      gsub(/[@"\t ]/,"",seg)
      eq=index(seg,"="); k=substr(seg,1,eq-1); v=substr(seg,eq+1)
      print bid, k, v
    }
    if ($0 ~ /\}/) cap=0
  }
')"

zig_rc_final=""; best_n=-1
for bid in $(printf '%s\n' "$zig_raw" | awk 'NF{print $1}' | sort -un); do
  cb="$(printf '%s\n' "$zig_raw" | awk -v b="$bid" '$1==b{print $2" "$3}' \
        | while read -r nm val; do [ -n "$nm" ] && echo "$(canon "$nm") $val"; done | sort -u)"
  if printf '%s\n' "$cb" | grep -qx 'ok 0'; then
    cnt="$(printf '%s\n' "$cb" | grep -vc '^$')"
    if [ "$cnt" -gt "$best_n" ]; then best_n="$cnt"; zig_rc_final="$cb"; fi
  fi
done

if [ "$nrc" -gt 0 ] && [ -z "$zig_rc_final" ]; then
  errs="${errs}  - no Zig enum(c_int) Result block (with ok = 0) found to compare result codes
"
elif [ "$nrc" -gt 0 ] && [ -n "$zig_rc_final" ] && [ "$idr_rc" != "$zig_rc_final" ]; then
  errs="${errs}  - Result-code map differs (name or value):
      Idris resultToInt: $(printf '%s' "$idr_rc" | tr '\n' ',')
      Zig   Result enum: $(printf '%s' "$zig_rc_final" | tr '\n' ',')
"
fi

if [ -n "$errs" ]; then
  echo "ABI-FFI GATE: FAIL ($name)"
  printf '%s' "$errs"
  exit 1
fi
echo "ABI-FFI GATE: OK ($name) — ${ncsyms} ABI functions exported, ${nrc} result codes match"
exit 0
