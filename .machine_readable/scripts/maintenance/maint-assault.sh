#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# maint-assault.sh — High-rigor stress testing using panic-attacker
#
# This script runs a full assault (static + dynamic) on the project binary
# to detect logic-based bug signatures and environmental vulnerabilities.

set -euo pipefail

BINARY_NAME="{{project}}"
REPORT_PATH="docs/reports/security/assault-latest.json"
PA_BIN="${PANIC_ATTACK_BIN:-panic-attack}"

echo "=== High-Rigor Security Assault ==="

# 1. Verify environment
if ! command -v "$PA_BIN" &>/dev/null; then
    echo "Error: panic-attack tool not found."
    echo "Please install it or set PANIC_ATTACK_BIN environment variable."
    exit 1
fi

if [ ! -f "target/release/$BINARY_NAME" ]; then
    echo "Warning: Release binary not found at target/release/$BINARY_NAME"
    echo "Running build first..."
    just build --release
fi

# 2. Run Assault
echo "Initiating full assault on $BINARY_NAME..."
mkdir -p "$(dirname "$REPORT_PATH")"

"$PA_BIN" assault "target/release/$BINARY_NAME" 
    --source . 
    --intensity medium 
    --duration 10 
    --output "$REPORT_PATH"

echo ""
echo "=== Assault Complete ==="
echo "Report generated: $REPORT_PATH"
echo "To review interactively, run:"
echo "  $PA_BIN tui $REPORT_PATH"
