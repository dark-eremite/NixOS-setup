import QtQuick

Column {
    id: section

    property string heading: ""
    property var nodes: []
    property string emptyText: ""
    property var activeNode: null
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    signal nodeSelected(var node)

    width: 300
    spacing: 4

    function label(node): string {
        return node.description || node.nickname || node.name;
    }

    Text {
        width: parent.width
        height: 18
        text: section.heading + "  " + section.nodes.length
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: section.accentColor
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        width: parent.width
        height: 22
        visible: section.nodes.length === 0
        text: section.emptyText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        color: section.fgColor
        opacity: 0.6
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: section.nodes

        delegate: Rectangle {
            width: section.width
            height: 34
            required property var modelData
            readonly property bool active: section.activeNode === modelData

            color: active
                ? Qt.rgba(section.accentColor.r, section.accentColor.g,
                          section.accentColor.b, 0.18)
                : "transparent"
            border.width: 1
            border.color: active ? section.accentColor : section.borderColor

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Text {
                    width: 20
                    height: parent.height
                    text: "\u{f04c3}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: active ? section.accentColor : section.fgColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    width: parent.width - 28
                    height: parent.height
                    text: section.label(modelData)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: section.fgColor
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: section.nodeSelected(modelData)
            }
        }
    }
}
