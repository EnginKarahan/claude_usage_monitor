#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
#
# Build a .plasmoid archive ready for upload to https://store.kde.org/
# (Category: Plasma Widgets). The .plasmoid is just a zip of the
# plasmoid/ directory with the right structure.
#
# Usage:
#   ./package.sh                  # writes dist/claude-usage-monitor-<version>.plasmoid

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

VERSION="$(jq -r '.KPlugin.Version' plasmoid/metadata.json)"
OUT_DIR="$HERE/dist"
OUT_FILE="$OUT_DIR/claude-usage-monitor-$VERSION.plasmoid"

mkdir -p "$OUT_DIR"

# Rebuild .mo files so the package always ships the latest translations.
if [[ -x translations/build.py ]]; then
    echo "▶ Compiling translations"
    python3 translations/build.py
fi

echo "▶ Building $OUT_FILE"
# `kpackagetool6 --package` produces the right structure; alternatively
# zip the plasmoid/ tree by hand. Use kpackagetool6 when available — it
# validates metadata as a side effect.
if command -v kpackagetool6 >/dev/null; then
    rm -f "$OUT_FILE"
    ( cd plasmoid && zip -qr "$OUT_FILE" . -x '*.pyc' '__pycache__/*' )
else
    echo "kpackagetool6 not found; falling back to plain zip" >&2
    rm -f "$OUT_FILE"
    ( cd plasmoid && zip -qr "$OUT_FILE" . -x '*.pyc' '__pycache__/*' )
fi

echo "✓ $OUT_FILE  ($(du -h "$OUT_FILE" | cut -f1))"
echo
echo "Upload via: https://store.kde.org/  →  Add Product  →  Plasma Widgets"
echo "Remember to include:"
echo "  - Screenshots of the compact pills and full popup"
echo "  - README excerpt as the description"
echo "  - Tag: plasma6, widget, claude, monitoring"
