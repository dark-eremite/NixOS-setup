import QtQuick
import Quickshell
import Quickshell.DBusMenu

// Context menu for a system tray item. It is rendered inside the power panel
// (under the tray grid), not as a separate native popup window. Submenus
// replace the current list in place, with a "back" row, so the whole menu
// always stays inside the same rectangle.
Item {
    id: menu

    property bool open: false
    property var rootHandle: null
    property var currentHandle: null
    property var stack: []

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    readonly property color subduedColor: Qt.rgba(
        menu.fgColor.r, menu.fgColor.g, menu.fgColor.b, 0.55
    )

    signal dismissRequested()

    function reset(): void {
        menu.stack = [];
        menu.currentHandle = menu.rootHandle;
    }

    onRootHandleChanged: menu.reset()
    onOpenChanged: { if (menu.open) menu.reset(); }

    function drill(handle): void {
        if (!handle) return;
        menu.stack = menu.stack.concat([ menu.currentHandle ]);
        menu.currentHandle = handle;
    }

    function back(): void {
        if (menu.stack.length === 0) return;
        var next = menu.stack.slice();
        var handle = next.pop();
        menu.stack = next;
        menu.currentHandle = handle;
    }

    QsMenuOpener {
        id: opener
        menu: menu.currentHandle
    }

    implicitWidth: 240
    implicitHeight: Math.min(
        264,
        (entryRepeater.count + (menu.stack.length > 0 ? 1 : 0)) * 28 + 12
    )

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(menu.bgColor.r, menu.bgColor.g, menu.bgColor.b, 0.98)
        border.width: 2
        border.color: menu.borderColor
    }

    Flickable {
        anchors {
            fill: parent
            margins: 4
        }
        clip: true
        contentWidth: width
        contentHeight: list.implicitHeight

        Column {
            id: list
            width: parent.width

            Item {
                width: list.width
                height: 28
                visible: menu.stack.length > 0

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(menu.accentColor.r, menu.accentColor.g,
                                   menu.accentColor.b, 0.12)
                }

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 8

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uf053"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: menu.accentColor
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Назад"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: menu.fgColor
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.back()
                }
            }

            Repeater {
                id: entryRepeater
                model: opener.children

                delegate: Item {
                    width: list.width
                    height: modelData.isSeparator ? 9 : 28

                    property bool activated: false

                    Rectangle {
                        anchors.fill: parent
                        color: parent.activated
                            ? Qt.rgba(menu.accentColor.r, menu.accentColor.g,
                                      menu.accentColor.b, 0.12)
                            : "transparent"
                    }

                    Rectangle {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        height: 1
                        color: menu.borderColor
                        visible: modelData.isSeparator
                    }

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 8
                        visible: !modelData.isSeparator

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: visible ? 16 : 0
                            height: 16
                            source: modelData.icon || ""
                            sourceSize.width: 16
                            sourceSize.height: 16
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            text: modelData.buttonType !== QsMenuButtonType.None
                                && modelData.checkState === Qt.Checked
                                ? "\u{f012c}" : ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: menu.accentColor
                            visible: text.length > 0
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            // Иконка, чекбокс и стрелка + их spacing.
                            width: Math.max(0, parent.width - 72)
                            text: modelData.text || ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: modelData.enabled ? menu.fgColor : menu.subduedColor
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.hasChildren ? "\uf054" : ""
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: menu.subduedColor
                            visible: text.length > 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !modelData.isSeparator && modelData.enabled
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: parent.activated = true
                        onExited: parent.activated = false
                        onClicked: {
                            if (modelData.hasChildren) {
                                menu.drill(modelData);
                            } else {
                                // DBusMenuItem::sendTriggered() — приватный слот,
                                // в QML он не виден. Публичный API — сигнал
                                // triggered(), к которому он подключён в C++.
                                if (typeof modelData.triggered === "function")
                                    modelData.triggered();
                                menu.dismissRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
