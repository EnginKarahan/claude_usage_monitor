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
            const exitCode = data["exit code"]
            const stdout = data.stdout || ""
            const stderr = data.stderr || ""
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
    }

    // Manual refresh: bump readerKick to force the periodic source to refire
    // immediately (changing connectedSources from outside the handler is safe).
    property int refreshNonce: 0
    function reload() {
        refreshNonce += 1
        // Rebuild the connectedSources list to force an immediate refetch.
        reader.connectedSources = []
        reader.connectedSources = [reader.readCommand]
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
