#!/usr/bin/env bash
# SPDX-License-Identifier: PMPL-1.0-or-later
#
# forge-sync.sh — Multi-forge mirroring script
#
# Synchronises the local repository with GitHub, GitLab, and Codeberg.
# Usage: ./forge-sync.sh

set -euo pipefail

REMOTES=("origin" "gitlab" "codeberg")

echo "=== RSR Forge Synchronisation ==="

for remote in "${REMOTES[@]}"; do
    if git remote | grep -q "^$remote$"; then
        echo "Pushing to $remote..."
        git push "$remote" --all
        git push "$remote" --tags
    else
        echo "Skip: Remote '$remote' not configured."
    fi
done

echo "Sync complete."
