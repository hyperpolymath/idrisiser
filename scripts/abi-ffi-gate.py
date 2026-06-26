#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# abi-ffi-gate.py — fail (exit 1) if the Zig FFI does not conform to the Idris2
# ABI. The Idris2 ABI is the source of truth. Checks, with no toolchain needed:
#
#   1. the Zig FFI carries no unrendered `{{...}}` template tokens;
#   2. every `%foreign "C:<name>"` symbol declared anywhere in the ABI .idr
#      sources is exported by the Zig FFI (`export fn <name>`);
#   3. the Zig `Result = enum(c_int)` and the Idris `resultToInt` agree on BOTH
#      names and integer values (the `Error`/`err` spelling is treated as one).
#
# Usage: python3 scripts/abi-ffi-gate.py [repo_root]   (defaults to cwd)

import os
import re
import sys
import glob


def camel_to_snake(s):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", s).lower()


def canon_rc(name):
    n = name.lower()
    return "error" if n in ("err", "error") else n


def find_result_enum(zig):
    """Return {variant: value} for the C-ABI Result enum, or {}."""
    best = {}
    for m in re.finditer(r"enum\s*\(\s*c_int\s*\)\s*\{(.*?)\}", zig, re.S):
        body = m.group(1)
        variants = {}
        for vm in re.finditer(r'@?"?([A-Za-z_][A-Za-z0-9_]*)"?\s*=\s*(\d+)', body):
            variants[canon_rc(vm.group(1))] = int(vm.group(2))
        # The Result enum is the one starting at ok = 0.
        if variants.get("ok") == 0 and len(variants) > len(best):
            best = variants
    return best


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    name = os.path.basename(os.path.abspath(root))
    abi_dir = os.path.join(root, "src/interface/abi")
    zig_path = os.path.join(root, "src/interface/ffi/src/main.zig")
    errs = []

    idr_files = [
        p for p in glob.glob(os.path.join(abi_dir, "**", "*.idr"), recursive=True)
        if os.sep + "build" + os.sep not in p
    ]
    if not idr_files:
        print(f"ABI-FFI GATE: SKIP ({name}) — no Idris2 ABI .idr files under {abi_dir}")
        return 0
    if not os.path.exists(zig_path):
        print(f"ABI-FFI GATE: FAIL ({name}) — no Zig FFI at {zig_path}")
        return 1

    idr = "\n".join(open(p, encoding="utf-8").read() for p in idr_files)
    zig = open(zig_path, encoding="utf-8").read()

    # 1. unrendered template tokens
    toks = sorted(set(re.findall(r"\{\{[A-Za-z0-9_]+\}\}", zig)))
    if toks:
        errs.append(f"Zig FFI has unrendered template tokens: {toks}")

    # 2. foreign C symbols must be exported
    csyms = sorted(set(re.findall(r"C:([A-Za-z0-9_]+)", idr)))
    exports = set(re.findall(r"export fn ([A-Za-z0-9_]+)", zig))
    missing = [s for s in csyms if s not in exports]
    if missing:
        errs.append(f"{len(missing)} ABI function(s) not exported by the Zig FFI: {missing}")

    # 3. result-code map (names + values) must agree
    idr_rc = {}
    for m in re.finditer(r"resultToInt\s+([A-Za-z0-9]+)\s*=\s*(\d+)", idr):
        idr_rc[canon_rc(camel_to_snake(m.group(1)))] = int(m.group(2))
    zig_rc = find_result_enum(zig)
    if idr_rc and not zig_rc:
        errs.append("no Zig `enum(c_int)` Result block (with `ok = 0`) found to compare result codes")
    elif idr_rc and zig_rc and idr_rc != zig_rc:
        errs.append(
            "Result-code map differs (name or value):\n"
            f"      Idris resultToInt: {dict(sorted(idr_rc.items()))}\n"
            f"      Zig   Result enum: {dict(sorted(zig_rc.items()))}"
        )

    if errs:
        print(f"ABI-FFI GATE: FAIL ({name})")
        for e in errs:
            print("  - " + e)
        return 1
    print(f"ABI-FFI GATE: OK ({name}) — {len(csyms)} ABI functions exported, "
          f"{len(idr_rc)} result codes match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
