#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# ssg-bootstrap.sh — Universal SSG Initialisation Helper
#
# Provides a starting hand for creating a documentation site or blog
# using hyperpolymath-approved formal or pretty-formal SSGs.

set -euo pipefail

echo "═══════════════════════════════════════════════════"
echo "  SSG BOOTSTRAP HELPER"
echo "═══════════════════════════════════════════════════"
echo ""
echo "Select an SSG to initialize in this project:"
echo "  [1] Casket-SSG (Haskell) — Pretty-formal, high-rigor default"
echo "  [2] Ddraig-SSG (Idris2) — Super-formal, dependent-type proofed"
echo "  [3] Serum-SSG (Elixir) — Concurrent, robust, BEAM-based"
echo "  [4] Zola (Rust) — Fast, standalone, standard"
echo ""

read -rp "Enter choice [1-4]: " choice

case "$choice" in
    1)
        echo "Selected: Casket-SSG"
        echo "Integration: git clone https://github.com/hyperpolymath/casket-ssg docs/site"
        ;;
    2)
        echo "Selected: Ddraig-SSG"
        echo "Integration: git clone https://github.com/hyperpolymath/ddraig-ssg docs/site"
        ;;
    3)
        echo "Selected: Serum-SSG"
        echo "Integration: mix serum.new docs/site"
        ;;
    4)
        echo "Selected: Zola"
        echo "Integration: zola init docs/site"
        ;;
    *)
        echo "Invalid selection. Aborting."
        exit 1
        ;;
esac

echo ""
echo "Note: For more advanced polystack options, visit: https://github.com/hyperpolymath/polystack"
