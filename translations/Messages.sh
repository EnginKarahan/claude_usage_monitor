#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
#
# KDE-style string extraction script. Run from the repo root:
#   ./translations/Messages.sh
#
# Produces translations/template.pot from all i18n() calls in QML files.
# Requires gettext (xgettext) installed. After running, merge the changes
# into existing .po files with:
#   msgmerge --update <lang>.po template.pot

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xgettext >/dev/null; then
    echo "xgettext not found. Install with:"
    echo "  Fedora: sudo dnf install gettext"
    exit 1
fi

xgettext \
    --from-code=UTF-8 \
    --language=JavaScript \
    --keyword=i18n \
    --keyword=i18nc:1c,2 \
    --keyword=i18np:1,2 \
    --keyword=i18ncp:1c,2,3 \
    --package-name="claude-usage-monitor" \
    --package-version="0.1.0" \
    --msgid-bugs-address="https://github.com/EnginKarahan/claude_usage_monitor/issues" \
    --output=translations/template.pot \
    plasmoid/contents/ui/*.qml

echo "→ translations/template.pot updated"
