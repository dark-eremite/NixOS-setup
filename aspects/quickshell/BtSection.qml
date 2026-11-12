import QtQuick
import Quickshell.Bluetooth

Column {
    id: section

    property string heading: ""
    property var devices: []
    property string emptyText: ""
    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    signal deviceSelected()

    width: 300
    spacing: 4

    Text {
        width: parent.width
        height: 18
        text: section.heading + "  " + section.devices.length
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: section.accentColor
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        width: parent.width
        height: 22
        visible: section.devices.length === 0
        text: section.emptyText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        color: section.fgColor
        opacity: 0.6
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: section.devices

        delegate: Rectangle {
            width: section.width
            height: 34
            color: modelData.connected
                ? Qt.rgba(section.accentColor.r, section.accentColor.g,
                          section.accentColor.b, 0.18)
                : "transparent"
            border.width: 1
            border.color: section.borderColor

            required property var modelData

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Text {
                    width: 20
                    height: parent.height
                    text: {
                        var icon = ("" + modelData.icon).toLowerCase();
                        if (icon.indexOf("audio") >= 0 || icon.indexOf("head") >= 0) return "";
                        if (icon.indexOf("input") >= 0 || icon.indexOf("keyboard") >= 0) return "";
                        return "";
                    }
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: modelData.connected ? section.accentColor : section.fgColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Column {
                    width: parent.width - 20 - 8 - 8 - actionIcon.width
                    height: parent.height
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.name || modelData.deviceName || modelData.address
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: section.fgColor
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: modelData.address
                            + (modelData.batteryAvailable
                               ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: section.fgColor
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: actionIcon
                    width: 20
                    height: parent.height
                    text: modelData.connected ? "\u{f0319}" : "\u{f00b1}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: modelData.connected ? section.accentColor : section.fgColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.deviceSelected();
                    if (modelData.connected)
                        modelData.disconnect();
                    else
                        modelData.connect();
                }
            }
        }
    }
}
