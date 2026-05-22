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

        BucketView {
            rootItem: full.rootItem
            title: i18n("Session (5-hour window)")
            data: full.rootItem.status ? full.rootItem.status.session : null
            Layout.fillWidth: true
        }

        BucketView {
            rootItem: full.rootItem
            title: i18n("Weekly (7-day window)")
            data: full.rootItem.status ? full.rootItem.status.weekly : null
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                text: {
                    if (!full.rootItem.status || !full.rootItem.status.fetched_at) return ""
                    return i18n("Last poll: %1 · Plan: %2",
                        full.rootItem.status.fetched_at.replace("T", " ").substring(0, 19),
                        full.rootItem.status.subscription || "?")
                }
            }
            QQC2.Button {
                icon.name: "view-refresh"
                text: i18n("Refresh")
                onClicked: full.rootItem.reload()
            }
        }
    }
}
