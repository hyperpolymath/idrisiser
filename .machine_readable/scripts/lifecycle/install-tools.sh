#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# install-tools.sh — Developer toolchain installer
#
# Detects and installs the required project toolchain (asdf, nix, or guix).

set -euo pipefail

echo "=== RSR Toolchain Installer ==="

if [ -f "flake.nix" ] && command -v nix &>/dev/null; then
    echo "Nix detected. Setting up development shell..."
    nix develop --command echo "Nix shell verified."
elif [ -f ".tool-versions" ] && command -v asdf &>/dev/null; then
    echo "asdf detected. Installing plugins and tools..."
    while read -r line; do
        plugin=$(echo "$line" | awk '{print $1}')
        asdf plugin add "$plugin" || true
    done < .tool-versions
    asdf install
else
    echo "No standard toolchain (Nix/asdf) detected or installed."
    echo "Please refer to README.adoc for manual setup instructions."
fi

echo "Installer complete."
