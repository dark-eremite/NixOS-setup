import QtQuick
import Quickshell.Services.Pipewire

Column {
    id: section

    property string heading: ""
    property var streams: []
    property string emptyText: ""
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    width: 300
    spacing: 4

    function label(node): string {
        var props = node.properties || {};
        return props["application.name"] || node.description
            || node.nickname || node.name;
    }

    Text {
        width: parent.width
        height: 18
        text: section.heading + "  " + section.streams.length
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: section.accentColor
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        width: parent.width
        height: 22
        visible: section.streams.length === 0
        text: section.emptyText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        color: section.fgColor
        opacity: 0.6
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: section.streams

        delegate: Rectangle {
            width: section.width
            height: 44
            required property var modelData

            readonly property var audio: modelData.audio
            readonly property string muteGlyph: "\u{f0581}"
            readonly property string volumeGlyph: "\u{f057e}"

            color: "transparent"
            border.width: 1
            border.color: section.borderColor

            Column {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Row {
                    width: parent.width
                    height: 14
                    spacing: 6

                    Text {
                        width: 16
                        height: parent.height
                        text: "\u{f08c6}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: section.fgColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: nameText
                        width: parent.width - 16 - 6 - 6 - percentText.width
                        height: parent.height
                        text: section.label(modelData)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: section.fgColor
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: percentText
                        width: 32
                        height: parent.height
                        text: Math.round((audio ? audio.volume : 0) * 100) + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: section.fgColor
                        opacity: 0.6
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Row {
                    width: parent.width
                    height: 14
                    spacing: 6

                    Rectangle {
                        id: muteButton
                        width: 16
                        height: 14
                        color: "transparent"
                        border.width: 1
                        border.color: (audio && audio.muted)
                            ? section.accentColor : section.borderColor

                        Text {
                            anchors.centerIn: parent
                            width: implicitWidth
                            height: implicitHeight
                            text: (audio && audio.muted)
                                ? muteGlyph : volumeGlyph
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: (audio && audio.muted)
                                ? section.accentColor : section.fgColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (audio) audio.muted = !audio.muted
                        }
                    }

                    VolumeSlider {
                        width: parent.width - 16 - parent.spacing
                        height: 14
                        value: audio ? audio.volume : 0
                        muted: audio ? audio.muted : false
                        accentColor: section.accentColor
                        borderColor: section.borderColor
                        fgColor: section.fgColor
                        onMoved: function (v) {
                            if (audio) audio.volume = v;
                        }
                    }
                }
            }
        }
    }
}
