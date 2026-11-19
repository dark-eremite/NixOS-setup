import QtQuick
import Quickshell
import Quickshell.Io

// Listening ports and the processes holding them. Like the other panel
// sections this is a plain Item embedded into PowerPanel, not a window.
Item {
    id: ports

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    readonly property string refreshGlyph: "\uf021"

    function reloadPorts(): void {
        portProc.running = false;
        portProc.running = true;
    }

    Process {
        id: portProc
        command: [ "ss", "-H", "-lntup" ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = ("" + this.text).split(/\r?\n/);
                var entries = [];

                for (var i = 0; i < lines.length; i++) {
                    var fields = lines[i].trim().split(/\s+/);
                    if (fields.length < 5 || (fields[0] !== "tcp" && fields[0] !== "udp"))
                        continue;

                    var local = fields[4];
                    var colon = local.lastIndexOf(":");
                    if (colon < 0)
                        continue;
                    var port = local.slice(colon + 1);
                    if (!/^\d+$/.test(port))
                        continue;

                    var names = [];
                    var pids = [];
                    var re = /"([^"]+)",pid=(\d+)/g;
                    var match;
                    while ((match = re.exec(lines[i])) !== null) {
                        if (names.indexOf(match[1]) < 0)
                            names.push(match[1]);
                        if (pids.indexOf(match[2]) < 0)
                            pids.push(match[2]);
                    }

                    entries.push({
                        port: port,
                        proto: fields[0].toUpperCase(),
                        address: local.slice(0, colon),
                        process: names.join(", "),
                        pid: pids.join(", "),
                        hasProcess: names.length > 0
                    });
                }

                entries.sort(function (a, b) {
                    return Number(a.port) - Number(b.port)
                        || a.proto.localeCompare(b.proto);
                });

                portsModel.clear();
                for (var j = 0; j < entries.length; j++)
                    portsModel.append(entries[j]);
            }
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: ports.visible
        onTriggered: ports.reloadPorts()
    }

    ListModel {
        id: portsModel
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(ports.bgColor.r, ports.bgColor.g,
                       ports.bgColor.b, 0.92)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: ports.borderColor
    }

    Column {
        id: content
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8

        Row {
            id: header
            width: parent.width
            height: 26
            spacing: 8

            Text {
                width: parent.width - parent.spacing - refreshButton.width
                height: parent.height
                text: "Порты"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: ports.fgColor
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: refreshButton
                width: 26
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: ports.borderColor

                Text {
                    anchors.centerIn: parent
                    text: ports.refreshGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: ports.fgColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ports.reloadPorts()
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: ports.borderColor
        }

        Item {
            id: listArea
            width: parent.width
            height: Math.max(0, content.height - header.height
                - 1 - 2 * content.spacing)

            ListView {
                id: list
                anchors.fill: parent
                model: portsModel
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: entry
                    width: list.width
                    height: 42

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(ports.fgColor.r, ports.fgColor.g,
                                       ports.fgColor.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(ports.borderColor.r,
                                              ports.borderColor.g,
                                              ports.borderColor.b, 0.5)
                    }

                    Column {
                        anchors {
                            fill: parent
                            margins: 6
                        }
                        spacing: 2

                        Row {
                            width: parent.width
                            spacing: 8

                            Text {
                                id: portText
                                text: model.port
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: ports.accentColor
                            }

                            Text {
                                id: protoText
                                text: model.proto
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: ports.fgColor
                                opacity: 0.6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: parent.width - parent.spacing * 2
                                    - portText.width - protoText.width
                                text: model.address
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: ports.fgColor
                                opacity: 0.6
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            width: parent.width
                            text: model.hasProcess
                                ? model.process
                                    + (model.pid.length > 0 ? " (" + model.pid + ")" : "")
                                : "процесс неизвестен"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: ports.fgColor
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: list
                visible: portsModel.count === 0
                text: "Нет слушающих портов"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: ports.fgColor
                opacity: 0.55
            }
        }
    }
}
