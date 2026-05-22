// SPDX-FileCopyrightText: 2026 Engin Karahan <engin.karahan@gmail.com>
// SPDX-License-Identifier: MIT

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: bucket

    required property var rootItem
    property string title: ""
    property var data: null

    readonly property bool hasData: data !== null && data !== undefined
    readonly property color stateColor: hasData
        ? rootItem.colorForState(data.state)
        : Kirigami.Theme.disabledTextColor

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            width: Kirigami.Units.gridUnit * 0.75
            height: width
            radius: width / 2
            color: bucket.stateColor
        }
        Text {
            text: bucket.title
            color: Kirigami.Theme.textColor
            font.bold: true
            Layout.fillWidth: true
        }
        Text {
            text: bucket.hasData ? bucket.rootItem.stateLabel(bucket.data.state) : i18n("no data")
            color: bucket.stateColor
        }
    }

    // Two-segment bar: current utilization (solid) + projected (ghost overlay).
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 0.5

        Rectangle {
            anchors.fill: parent
            radius: 3
            color: Kirigami.Theme.backgroundColor
            opacity: 0.5
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor
        }

        // Projected addition (ghost).
        Rectangle {
            visible: bucket.hasData && bucket.data.projected > bucket.data.utilization
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: bucket.hasData
                ? Math.min(parent.width - 2, (parent.width - 2) * Math.min(bucket.data.projected, 100) / 100)
                : 0
            radius: 2
            color: bucket.stateColor
            opacity: 0.35
        }

        // Current utilization (solid).
        Rectangle {
            visible: bucket.hasData
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: bucket.hasData
                ? Math.min(parent.width - 2, (parent.width - 2) * Math.min(bucket.data.utilization, 100) / 100)
                : 0
            radius: 2
            color: bucket.stateColor
        }

        // 100% marker.
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 1
            color: Kirigami.Theme.textColor
            opacity: 0.4
        }
    }

    GridLayout {
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing
        Layout.fillWidth: true

        Text { text: i18n("Used now");          color: Kirigami.Theme.disabledTextColor }
        Text { text: bucket.hasData ? bucket.data.utilization + " %" : "—"; color: Kirigami.Theme.textColor }

        Text { text: i18n("Projected at reset"); color: Kirigami.Theme.disabledTextColor }
        Text {
            text: bucket.hasData
                ? (bucket.data.forecast_available
                    ? bucket.rootItem.formatProjection(bucket.data.projected)
                    : i18n("%1 (no rate yet)", bucket.rootItem.formatProjection(bucket.data.projected)))
                : "—"
            color: Kirigami.Theme.textColor
        }

        Text { text: i18n("Burn rate");         color: Kirigami.Theme.disabledTextColor }
        Text {
            text: (bucket.hasData && bucket.data.burn_rate_per_hour !== null)
                ? bucket.data.burn_rate_per_hour + " %/h"
                : "—"
            color: Kirigami.Theme.textColor
        }

        Text { text: i18n("Reset in");          color: Kirigami.Theme.disabledTextColor }
        Text { text: bucket.hasData ? bucket.rootItem.formatDuration(bucket.data.resets_in_s) : "—"; color: Kirigami.Theme.textColor }
    }
}
