// SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Item {
    id: full

    required property var rootItem

    // null when Codex isn't installed; the panel then shows Claude only.
    readonly property var codexData: rootItem.status && rootItem.status.codex
        && rootItem.status.codex.available ? rootItem.status.codex : null

    // With Codex shown this sits under the Claude section, otherwise in the footer.
    readonly property string claudePollText: {
        const st = rootItem.status
        if (!st || !st.fetched_at) return ""
        return i18n("Last poll: %1 · Plan: %2",
            st.fetched_at.replace("T", " ").substring(0, 19), st.subscription || "?")
    }

    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: contentLayout.implicitHeight + Kirigami.Units.largeSpacing * 2

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            text: i18n("Claude Usage Monitor")
            level: 2
            Layout.fillWidth: true
        }

        Text {
            visible: full.rootItem.lastError !== ""
            text: i18n("⚠ %1", full.rootItem.lastError)
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Kirigami.Heading {
            visible: full.codexData !== null
            text: "Claude"
            level: 3
            Layout.fillWidth: true
        }

        BucketView {
            rootItem: full.rootItem
            title: i18n("Session (5-hour window)")
            bucketData: full.rootItem.status ? full.rootItem.status.session : null
            Layout.fillWidth: true
        }

        BucketView {
            rootItem: full.rootItem
            title: i18n("Weekly (7-day window)")
            bucketData: full.rootItem.status ? full.rootItem.status.weekly : null
            Layout.fillWidth: true
        }

        Text {
            visible: full.codexData !== null
            Layout.fillWidth: true
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: Kirigami.Units.gridUnit * 0.75
            text: full.claudePollText
        }

        // === Codex (only when installed) ===
        Kirigami.Heading {
            visible: full.codexData !== null
            text: "Codex"
            level: 3
            Layout.fillWidth: true
        }

        Text {
            visible: full.codexData !== null && !full.codexData.ok
            text: full.codexData ? i18n("⚠ %1", full.codexData.error || "") : ""
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        BucketView {
            visible: full.codexData !== null
            rootItem: full.rootItem
            title: i18n("Session (5-hour window)")
            bucketData: full.codexData ? full.codexData.session || null : null
            Layout.fillWidth: true
        }

        BucketView {
            visible: full.codexData !== null
            rootItem: full.rootItem
            title: i18n("Weekly (7-day window)")
            bucketData: full.codexData ? full.codexData.weekly || null : null
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                wrapMode: Text.WordWrap
                text: {
                    const c = full.codexData
                    if (c && c.ok) {
                        const when = full.rootItem.formatTimestamp(c.updated_at)
                        return c.source === "live"
                            ? i18n("Last poll: %1 · Plan: %2", when, c.plan || "?")
                            : i18n("Last Codex request: %1 · Plan: %2", when, c.plan || "?")
                    }
                    return c ? "" : full.claudePollText
                }
            }
            QQC2.Button {
                icon.name: "view-refresh"
                text: full.rootItem.refreshing ? i18n("Refreshing…") : i18n("Refresh")
                enabled: !full.rootItem.refreshing
                onClicked: full.rootItem.reload()
            }
        }
    }
}
