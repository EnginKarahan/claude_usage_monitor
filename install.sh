#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
# SPDX-License-Identifier: MIT
# Install the Claude Usage Monitor plasmoid + backend poller.
#
# Idempotent: re-run after edits to update everything in place.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_ID="com.karahan.claudewidget"
PLASMOID_SRC="$HERE/plasmoid"
PLASMOID_DST="$HOME/.local/share/plasma/plasmoids/$PLASMOID_ID"

BIN_SRC="$HERE/backend/claude_widget_poll.py"
BIN_DST="$HOME/.local/bin/claude-widget-poll"

SYSTEMD_SRC="$HERE/backend/systemd"
SYSTEMD_DST="$HOME/.config/systemd/user"

step() { printf "\n\033[1;34m▶ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "  \033[1;33m!\033[0m %s\n" "$*"; }

# ---------- preflight ----------
step "Preflight"
if ! command -v kpackagetool6 >/dev/null; then
    echo "kpackagetool6 not found — install kf6-kpackage / plasma-workspace." >&2
    exit 1
fi
if [[ ! -f "$HOME/.claude/.credentials.json" ]]; then
    warn "~/.claude/.credentials.json missing — log in via 'claude' first."
fi
ok "kpackagetool6 found"

# ---------- backend ----------
step "Installing poller -> $BIN_DST"
install -d "$(dirname "$BIN_DST")"
install -m 0755 "$BIN_SRC" "$BIN_DST"
ok "Poller installed"

step "Installing systemd user units -> $SYSTEMD_DST"
install -d "$SYSTEMD_DST"
install -m 0644 "$SYSTEMD_SRC/claude-widget-poll.service" "$SYSTEMD_DST/"
install -m 0644 "$SYSTEMD_SRC/claude-widget-poll.timer"   "$SYSTEMD_DST/"
systemctl --user daemon-reload
systemctl --user enable --now claude-widget-poll.timer
ok "Timer enabled and started"

# Fire once immediately so the widget has data on first launch.
if systemctl --user start claude-widget-poll.service; then
    ok "Initial poll triggered"
else
    warn "Initial poll failed — check 'journalctl --user -u claude-widget-poll'"
fi

# ---------- plasmoid ----------
step "Installing plasmoid -> $PLASMOID_DST"
if [[ -d "$PLASMOID_DST" ]]; then
    if ! kpackagetool6 --type=Plasma/Applet --upgrade "$PLASMOID_SRC"; then
        kpackagetool6 --type=Plasma/Applet --remove "$PLASMOID_ID" || true
        kpackagetool6 --type=Plasma/Applet --install "$PLASMOID_SRC"
    fi
else
    kpackagetool6 --type=Plasma/Applet --install "$PLASMOID_SRC"
fi
ok "Plasmoid installed"

cat <<EOF

────────────────────────────────────────────────────────────────
Installation complete.

Next steps:
  1. Right-click your top panel → "Add or manage widgets…"
  2. Search for "Claude Token Monitor" and drag it to the center.
  3. The widget reads $HOME/.cache/claude-widget/status.json,
     refreshed by the systemd timer every 10 minutes.

Useful commands:
  systemctl --user status claude-widget-poll.timer
  systemctl --user start  claude-widget-poll.service   # poll now
  journalctl --user -u claude-widget-poll -f           # follow logs

If the plasmoid does not appear, restart plasmashell:
  systemctl --user restart plasma-plasmashell
────────────────────────────────────────────────────────────────
EOF
