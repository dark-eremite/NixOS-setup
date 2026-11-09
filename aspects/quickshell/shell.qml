// Quickshell bar — static structure, in the /nix/store.
// Dynamic colors are loaded at runtime from
//   file:///home/dark_eremite/.config/quickshell/colors.qml
// which matugen renders from aspects/quickshell/colors.qml.j2.
//
// Workspace state comes from niri's IPC (`niri msg --json workspaces`).
// Clicks are sent back through niri IPC (`focus-workspace N`).
// Theme reloads come through the Quickshell IPC handler `theme.reload`.

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    // Exposes `function reload(): void` to `quickshell ipc call theme reload`.
    IpcHandler {
        target: "theme"

        function reload(): void {
            // Re-create the dynamic palette loader so a freshly generated
            // colors.qml is picked up without restarting the whole shell.
            paletteLoader.active = false;
            paletteLoader.active = true;
            wsProc.running = true;
        }
    }

    // The dynamic palette object (colors.qml defines a QtObject).
    Loader {
        id: paletteLoader
        active: true
        asynchronous: false
        source: "file:///home/dark_eremite/.config/quickshell/colors.qml"
    }

    // Fallback palette used when colors.qml has not been generated yet.
    QtObject {
        id: fallbackPalette
        readonly property color bg: "#111318"
        readonly property color fg: "#e1e2e9"
        readonly property color accent: "#a7c8ff"
        readonly property color border: "#59FFFFFF"
    }

    // Poll niri for the focused workspace. A Timer (rather than an endless
    // Process restart loop) keeps the indicator in sync without spawning
    // `niri msg` continuously.
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: wsProc.running = true
    }

    Process {
        id: wsProc
        command: [ "niri", "msg", "--json", "workspaces" ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var list = JSON.parse(this.text);
                    var idx = 1;
                    for (var i = 0; i < list.length; i++) {
                        if (list[i].is_focused) {
                            idx = list[i].idx;
                            break;
                        }
                    }
                    bar.currentIndex = idx;
                } catch (e) {
                    // niri not running yet — keep the last known index.
                }
            }
        }
    }

    PanelWindow {
        id: bar

        // Resolved palette: dynamic when colors.qml loaded, neutral otherwise.
        property QtObject pal: (paletteLoader.status === Loader.Ready && paletteLoader.item)
            ? paletteLoader.item
            : fallbackPalette

        property int currentIndex: 1
        readonly property int workspaceCount: 7
        readonly property real cell: 32
        readonly property real gap: 8

        anchors {
            top: true
            left: true
            right: true
        }
        margins {
            left: 12
            right: 12
            top: 8
        }
        implicitHeight: 40
        color: Qt.rgba(bar.pal.bg.r, bar.pal.bg.g, bar.pal.bg.b, 0.75)

        // Inverted semi-transparent border, same tone as niri's window border.
        // No radius anywhere (no rounded corners).
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: bar.pal.border
        }

        // Animated accent indicator behind the 32x32 squares.
        Rectangle {
            id: indicator
            width: bar.cell
            height: bar.cell
            color: bar.pal.accent
            x: wsRow.x + (bar.currentIndex - 1) * (bar.cell + bar.gap)
            y: wsRow.y

            Behavior on x {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        // Exactly 7 workspaces, numbered 1..7, clickable.
        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: bar.gap

            Repeater {
                model: bar.workspaceCount

                delegate: Item {
                    width: bar.cell
                    height: bar.cell

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 2
                        border.color: bar.pal.border
                    }

                    Text {
                        anchors.centerIn: parent
                        text: index + 1
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: bar.pal.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.focusWorkspace(index + 1)
                    }
                }
            }
        }

        // Invisible 32px-tall strip behind the squares so clicks that land in
        // the gaps / empty area still switch to the corresponding workspace.
        // z: -1 keeps the squares' own MouseAreas as the topmost click targets.
        MouseArea {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: wsRow.width
            height: bar.cell
            z: -1

            onClicked: {
                var idx = Math.floor(mouseX / (bar.cell + bar.gap)) + 1;
                if (idx >= 1 && idx <= bar.workspaceCount)
                    bar.focusWorkspace(idx);
            }
        }

        function focusWorkspace(idx: int): void {
            currentIndex = idx;
            Quickshell.execDetached([
                "niri", "msg", "action", "focus-workspace", "" + idx
            ]);
        }
    }
}
