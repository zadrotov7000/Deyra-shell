// Port of Dux Modular Shell: quickshell/PLUGINS/ExampleDesktopClock/DesktopClock.qml; original blob 036b92d5b9221d49ace8f80fc72177b3cedefadc
// MIT; see LICENSE. Replaces plugin host/theme globals with Deyra-provided properties.
import QtQuick
import Quickshell

Item {
    id: root

    implicitWidth: 240
    implicitHeight: 240
    property var pluginData: ({})
    property color accent: "#a9c7ff"
    property color surface: "#1a202c"
    property color foreground: "#eef2ff"
    property int corner: 24

    property bool showSeconds: pluginData.showSeconds ?? true
    property bool showDate: pluginData.showDate ?? true
    property string clockStyle: pluginData.clockStyle ?? "analog"
    property real backgroundOpacity: (pluginData.backgroundOpacity ?? 50) / 100

    SystemClock {
        id: systemClock
        enabled: root.visible
        precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Rectangle {
        id: background
        anchors.fill: parent
        radius: root.corner
        color: root.surface
        opacity: root.backgroundOpacity
    }

    Loader {
        anchors.fill: parent
        anchors.margins: 12
        sourceComponent: root.clockStyle === "digital" ? digitalClock : analogClock
    }

    Component {
        id: analogClock

        Item {
            id: analogClockRoot

            property real clockSize: Math.min(width, height) - (root.showDate ? 30 : 0)

            Item {
                id: clockFace
                width: analogClockRoot.clockSize
                height: analogClockRoot.clockSize
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 8

                Repeater {
                    model: 12

                    Rectangle {
                        required property int index
                        property real markAngle: index * 30
                        property real markRadius: clockFace.width / 2 - 8

                        x: clockFace.width / 2 + markRadius * Math.sin(markAngle * Math.PI / 180) - width / 2
                        y: clockFace.height / 2 - markRadius * Math.cos(markAngle * Math.PI / 180) - height / 2
                        width: index % 3 === 0 ? 8 : 4
                        height: width
                        radius: width / 2
                        color: index % 3 === 0 ? root.accent : Qt.alpha(root.foreground, .35)
                    }
                }

                Rectangle {
                    id: hourHand
                    property int hours: systemClock.date?.getHours() % 12 ?? 0
                    property int minutes: systemClock.date?.getMinutes() ?? 0

                    x: clockFace.width / 2 - width / 2
                    y: clockFace.height / 2 - height + 4
                    width: 6
                    height: clockFace.height * 0.25
                    radius: 3
                    color: root.accent
                    antialiasing: true
                    transformOrigin: Item.Bottom
                    rotation: (hours + minutes / 60) * 30
                }

                Rectangle {
                    id: minuteHand
                    property int minutes: systemClock.date?.getMinutes() ?? 0
                    property int seconds: systemClock.date?.getSeconds() ?? 0

                    x: clockFace.width / 2 - width / 2
                    y: clockFace.height / 2 - height + 4
                    width: 4
                    height: clockFace.height * 0.35
                    radius: 2
                    color: root.foreground
                    antialiasing: true
                    transformOrigin: Item.Bottom
                    rotation: (minutes + seconds / 60) * 6
                }

                Rectangle {
                    id: secondHand
                    visible: root.showSeconds
                    property int seconds: systemClock.date?.getSeconds() ?? 0

                    x: clockFace.width / 2 - width / 2
                    y: clockFace.height / 2 - height + 4
                    width: 2
                    height: clockFace.height * 0.4
                    radius: 1
                    color: "#ef7777"
                    antialiasing: true
                    transformOrigin: Item.Bottom
                    rotation: seconds * 6
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: root.accent
                }
            }

            Text {
                visible: root.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                text: systemClock.date?.toLocaleDateString(Qt.locale(), "ddd, MMM d") ?? ""
                font.pixelSize: 12
                font.weight: Font.Medium
                color: root.foreground
            }
        }
    }

    Component {
        id: digitalClock

        Item {
            id: digitalRoot

            property real timeFontSize: Math.min(width * 0.16, height * (root.showDate ? 0.4 : 0.5))
            property real dateFontSize: Math.max(12, timeFontSize * 0.35)

            Text {
                id: timeText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: root.showDate ? -digitalRoot.dateFontSize * 0.8 : 0
                text: systemClock.date?.toLocaleTimeString(Qt.locale(), root.showSeconds ? "hh:mm:ss" : "hh:mm") ?? ""
                font.pixelSize: digitalRoot.timeFontSize
                font.weight: Font.Medium
                font.family: "monospace"
                color: root.accent
            }

            Text {
                id: dateText
                visible: root.showDate
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: timeText.bottom
                anchors.topMargin: 6
                text: systemClock.date?.toLocaleDateString(Qt.locale(), "ddd, MMM d") ?? ""
                font.pixelSize: digitalRoot.dateFontSize
                color: root.foreground
            }
        }
    }
}
