// SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

MouseArea {
    id: compact

    required property var rootItem

    readonly property var sessionData: rootItem.status ? rootItem.status.session : null
    readonly property var weeklyData:  rootItem.status ? rootItem.status.weekly  : null
    // null when Codex isn't installed; the widget then shows Claude only.
    readonly property var codexData: rootItem.status && rootItem.status.codex
        && rootItem.status.codex.available ? rootItem.status.codex : null
    readonly property bool showCodex: codexData !== null

    // Fixed 140 px. Claude only: two 64 px pills, 4 px gaps. With Codex:
    // two rows, each a provider mark plus two narrower pills, sharing the
    // panel height.
    readonly property int margin: 4
    readonly property int markWidth: showCodex ? 13 : 0
    readonly property int spacing: showCodex ? 3 : 4
    readonly property int pillWidth: Math.floor(
        (width - 2 * margin - markWidth - (showCodex ? 2 : 1) * spacing) / 2)
    readonly property int pillHeight: showCodex
        ? Math.max(10, Math.min(22, Math.floor((height - 4) / 2)))
        : 22
    readonly property int fontSize: Math.max(7, Math.min(11, Math.round(pillHeight * 0.62)))

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

    component Pill: Rectangle {
        id: pill
        property var bucket: null
        property string letter: ""

        width: compact.pillWidth
        height: compact.pillHeight
        radius: height / 2
        color: bucket ? compact.rootItem.colorForState(bucket.state) : "#888888"
        opacity: 0.9

        Text {
            anchors.centerIn: parent
            text: pill.bucket ? pill.letter + " " + Math.round(pill.bucket.utilization) + "%" : pill.letter + " —"
            color: "white"
            font.pixelSize: compact.fontSize
            font.bold: true
        }
    }

    component ProviderMark: Text {
        visible: compact.showCodex
        width: compact.markWidth
        height: compact.pillHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: compact.fontSize
        font.bold: true
    }

    Column {
        x: compact.margin
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // === Claude ===
        Row {
            spacing: compact.spacing
            ProviderMark { text: "✻"; color: "#d97757"; font.pixelSize: Math.round(compact.fontSize * 1.4) }
            Pill { bucket: compact.sessionData; letter: "S" }
            Pill { bucket: compact.weeklyData;  letter: "W" }
        }

        // === Codex ===
        Row {
            visible: compact.showCodex
            spacing: compact.spacing
            ProviderMark { text: ">_"; color: Kirigami.Theme.textColor }
            Pill { bucket: compact.codexData ? compact.codexData.session : null; letter: "S" }
            Pill { bucket: compact.codexData ? compact.codexData.weekly  : null; letter: "W" }
        }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: i18n("Claude Usage Monitor")
        subText: {
            const r = compact.rootItem
            const lines = []
            function bucketLines(s, w) {
                if (s) {
                    lines.push(i18n(
                        "<b>Session (5h)</b>: %1% used, projected %2 at reset in %3<br/><i>%4</i>",
                        s.utilization, r.formatProjection(s.projected),
                        r.formatDuration(s.resets_in_s), r.stateLabel(s.state)))
                }
                if (w) {
                    lines.push(i18n(
                        "<b>Weekly (7d)</b>: %1% used, projected %2 at reset in %3<br/><i>%4</i>",
                        w.utilization, r.formatProjection(w.projected),
                        r.formatDuration(w.resets_in_s), r.stateLabel(w.state)))
                }
            }
            if (compact.showCodex)
                lines.push("<b><u>Claude</u></b>")
            if (r.lastError)
                lines.push(i18n("Error: %1", r.lastError))
            else if (!r.status || !r.status.ok)
                lines.push(i18n("Waiting for first poll…"))
            else
                bucketLines(compact.sessionData, compact.weeklyData)
            const c = compact.codexData
            if (c) {
                lines.push("<b><u>Codex</u></b>")
                if (c.ok) {
                    // Session-log fallback: numbers are only as fresh as the last request.
                    if (c.source !== "live")
                        lines.push(i18n("<small>As of the last Codex request: %1</small>",
                            r.formatTimestamp(c.updated_at)))
                    bucketLines(c.session, c.weekly)
                } else {
                    lines.push(i18n("Error: %1", c.error))
                }
            }
            lines.push(i18n("<small>Click to expand · Middle-click to refresh</small>"))
            return lines.join("<br/>")
        }
        textFormat: Text.RichText
    }
}
