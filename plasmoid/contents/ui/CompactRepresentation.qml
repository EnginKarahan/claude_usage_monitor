// SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

MouseArea {
    id: compact

    required property var rootItem

    readonly property var sessionData: rootItem.status ? rootItem.status.session : null
    readonly property var weeklyData:  rootItem.status ? rootItem.status.weekly  : null

    // Two pills, 64 px each, 4 px gap, 4 px outer margins = 140 px wide.
    implicitWidth: 140
    implicitHeight: 22

    Layout.preferredWidth: 140
    Layout.minimumWidth: 140
    Layout.fillHeight: true

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onClicked: function (mouse) {
        if (mouse.button === Qt.MiddleButton) {
            rootItem.reload()
            return
        }
        rootItem.expanded = !rootItem.expanded
    }

    // Subtle dark base so the pills stand out against any panel color.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.0
    }

    // === Session pill (left) ===
    Rectangle {
        id: sPill
        x: 4
        y: (parent.height - height) / 2
        width: 64
        height: 22
        radius: 11
        color: compact.sessionData ? compact.rootItem.colorForState(compact.sessionData.state) : "#888888"
        opacity: 0.9

        Text {
            anchors.centerIn: parent
            text: compact.sessionData ? "S " + Math.round(compact.sessionData.utilization) + "%" : "S —"
            color: "white"
            font.pixelSize: 11
            font.bold: true
        }

    }

    // === Weekly pill (right) ===
    Rectangle {
        id: wPill
        x: 72
        y: (parent.height - height) / 2
        width: 64
        height: 22
        radius: 11
        color: compact.weeklyData ? compact.rootItem.colorForState(compact.weeklyData.state) : "#888888"
        opacity: 0.9

        Text {
            anchors.centerIn: parent
            text: compact.weeklyData ? "W " + Math.round(compact.weeklyData.utilization) + "%" : "W —"
            color: "white"
            font.pixelSize: 11
            font.bold: true
        }

    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: i18n("Claude Usage Monitor")
        subText: {
            if (compact.rootItem.lastError) return i18n("Error: %1", compact.rootItem.lastError)
            if (!compact.rootItem.status || !compact.rootItem.status.ok) return i18n("Waiting for first poll…")
            const s = compact.sessionData
            const w = compact.weeklyData
            const lines = []
            if (s) {
                lines.push(i18n(
                    "<b>Session (5h)</b>: %1% used, projected %2 at reset in %3<br/><i>%4</i>",
                    s.utilization, compact.rootItem.formatProjection(s.projected),
                    compact.rootItem.formatDuration(s.resets_in_s),
                    compact.rootItem.stateLabel(s.state)))
            }
            if (w) {
                lines.push(i18n(
                    "<b>Weekly (7d)</b>: %1% used, projected %2 at reset in %3<br/><i>%4</i>",
                    w.utilization, compact.rootItem.formatProjection(w.projected),
                    compact.rootItem.formatDuration(w.resets_in_s),
                    compact.rootItem.stateLabel(w.state)))
            }
            lines.push(i18n("<small>Click to expand · Middle-click to refresh</small>"))
            return lines.join("<br/>")
        }
        textFormat: Text.RichText
    }
}
