// SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import Qt.labs.platform as Platform
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Status JSON written by the Python poller. We use a string path
    // (not file://) because Plasma5Support.executable shells the command.
    readonly property string statusPath: {
        const base = Platform.StandardPaths.writableLocation(Platform.StandardPaths.GenericCacheLocation)
        const s = base.toString()
        const local = s.indexOf("file://") === 0 ? s.substring(7) : s
        return local + "/claude-widget/status.json"
    }

    // Re-read the cache file frequently so countdown timers feel live.
    // The poller (systemd timer) writes every ~5 minutes.
    readonly property int reloadIntervalMs: 30 * 1000

    property var status: null
    property string lastError: ""
    // True while a manual refresh poll is in flight (disables the button).
    property bool refreshing: false

    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactRepresentation { rootItem: root }
    fullRepresentation: FullRepresentation { rootItem: root }

    // Periodic reader: interval makes the executable engine re-run on its own.
    // Disconnect/reconnect from inside onNewData crashes plasmashell.
    Plasma5Support.DataSource {
        id: reader
        engine: "executable"
        connectedSources: [readCommand]
        interval: root.reloadIntervalMs

        readonly property string readCommand:
            "cat '" + root.statusPath.replace(/'/g, "'\\''") + "'"

        onNewData: function (sourceName, data) {
            root.applyStatus(data["exit code"], data.stdout || "", data.stderr || "")
        }
    }

    // Parse a `cat status.json` result into root.status / root.lastError.
    // Shared by the periodic reader and the manual-refresh poller.
    function applyStatus(exitCode, stdout, stderr) {
        if (exitCode !== 0) {
            root.lastError = stderr.trim() || ("cat exit " + exitCode)
            return
        }
        if (!stdout) {
            root.lastError = "empty status file"
            return
        }
        try {
            root.status = JSON.parse(stdout)
            root.lastError = root.status.ok === false
                ? (root.status.error || "poller error")
                : ""
        } catch (e) {
            root.lastError = "parse error: " + e
        }
    }

    // Manual refresh: actually trigger a fresh poll (the systemd timer only
    // fires every 10 min, so re-reading the cache alone shows no change),
    // then re-read the status file. The oneshot service blocks until done,
    // so the cat after it sees the freshly written JSON. `;` (not `&&`)
    // ensures we still read the file when the poll exits non-zero — the
    // poller writes an ok:false status with an error message in that case.
    Plasma5Support.DataSource {
        id: poller
        engine: "executable"
        // No interval: connectSource runs the command exactly once.
        connectedSources: []

        readonly property string pollCommand:
            "systemctl --user start claude-widget-poll.service; cat '"
            + root.statusPath.replace(/'/g, "'\\''") + "'"

        onNewData: function (sourceName, data) {
            disconnectSource(sourceName)
            refreshGuard.stop()
            root.refreshing = false
            root.applyStatus(data["exit code"], data.stdout || "", data.stderr || "")
        }
    }

    // Safety net: if the poll command never reports back (hung start, stuck
    // network), re-enable the button instead of leaving it disabled forever.
    Timer {
        id: refreshGuard
        interval: 45 * 1000
        onTriggered: {
            poller.connectedSources = []
            root.refreshing = false
        }
    }

    function reload() {
        if (root.refreshing)
            return
        root.refreshing = true
        refreshGuard.restart()
        poller.connectSource(poller.pollCommand)
    }

    function colorForState(state) {
        switch (state) {
        case "blue":   return "#3daee9"
        case "green":  return "#27ae60"
        case "yellow": return "#f39c12"
        case "red":    return "#e74c3c"
        }
        return Kirigami.Theme.disabledTextColor
    }

    function formatDuration(seconds) {
        if (seconds === undefined || seconds === null || seconds < 0) return "—"
        const s = Math.floor(seconds)
        const h = Math.floor(s / 3600)
        const m = Math.floor((s % 3600) / 60)
        if (h > 0) return h + "h " + m + "m"
        return m + "m"
    }

    // Display projection capped at the poller's PROJECTION_CAP (200%).
    // Values at or above the cap are shown as "≥200 %" so unrealistic
    // single-burst extrapolations don't look like real numbers.
    function formatProjection(projected) {
        if (projected === undefined || projected === null) return "—"
        if (projected >= 200) return "≥200 %"
        return projected + " %"
    }

    function stateLabel(state) {
        switch (state) {
        case "blue":   return i18n("under-utilized — tokens may be wasted")
        case "green":  return i18n("on track")
        case "yellow": return i18n("approaching limit")
        case "red":    return i18n("projected to exceed limit")
        }
        return i18n("unknown")
    }
}
