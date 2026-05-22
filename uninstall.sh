#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
set -euo pipefail

PLASMOID_ID="com.karahan.claudewidget"

systemctl --user disable --now claude-widget-poll.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/claude-widget-poll."{service,timer}
systemctl --user daemon-reload

rm -f "$HOME/.local/bin/claude-widget-poll"
kpackagetool6 --type=Plasma/Applet --remove "$PLASMOID_ID" 2>/dev/null || true

# Keep ~/.cache/claude-widget by default — has poll history.
echo "Done. Cache at ~/.cache/claude-widget left in place (delete manually if desired)."
