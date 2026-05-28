#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
# Pull the latest changes from GitHub and reinstall everything in place.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

step() { printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*"; }

# ---------- git pull ----------
step "Pulling latest changes from GitHub"

if ! git -C "$HERE" diff --quiet || ! git -C "$HERE" diff --cached --quiet; then
    warn "Uncommitted local changes detected — aborting to avoid overwriting your work."
    warn "Commit or stash them first, then re-run update.sh."
    exit 1
fi

BEFORE="$(git -C "$HERE" rev-parse HEAD)"
git -C "$HERE" pull --ff-only origin main
AFTER="$(git -C "$HERE" rev-parse HEAD)"

if [[ "$BEFORE" == "$AFTER" ]]; then
    ok "Already up to date ($(git -C "$HERE" describe --tags --always))"
else
    ok "Updated: ${BEFORE:0:7} → ${AFTER:0:7}"
    git -C "$HERE" log --oneline "${BEFORE}..${AFTER}"
fi

# ---------- reinstall ----------
step "Reinstalling"
bash "$HERE/install.sh"
