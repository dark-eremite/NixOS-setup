import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    id: panel

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 8 + panel.topInset
        right: panel.slide
        bottom: 8
    }
    implicitWidth: 320
    color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    onClosed: shown = false

    property bool shown: false
    property bool slidingOut: false
    readonly property real hiddenRight: -(implicitWidth + 12)
    readonly property real shownRight: 12
    property real slide: hiddenRight

    visible: shown || slidingOut

    property string avatarPath: ""
    readonly property string userName: Quickshell.env("USER")

    readonly property string powerGlyph: "\u{f0425}"
    readonly property string rebootGlyph: "\u{f0709}"
    readonly property string suspendGlyph: "\u{f0904}"
    readonly property string logoutGlyph: "\u{f0343}"
    readonly property string userGlyph: "\uf007"

    readonly property var actions: [
        { glyph: powerGlyph, command: [ "systemctl", "poweroff" ] },
        { glyph: rebootGlyph, command: [ "systemctl", "reboot" ] },
        { glyph: suspendGlyph, command: [ "systemctl", "suspend" ] },
        { glyph: logoutGlyph, command: [ "niri", "msg", "action", "quit" ] }
    ]

    function toggle(): void { shown = !shown; }

    IpcHandler {
        target: "power"

        function toggle(): void { panel.toggle(); }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    Process {
        running: true
        command: [
            "sh", "-c",
            "for f in \"$HOME\"/.face/*; do "
            + "case \"$f\" in *.jpg|*.jpeg|*.png|*.webp|*.bmp) printf '%s' \"$f\"; break;; esac; "
            + "done"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: panel.avatarPath = this.text.trim()
        }
    }

    Behavior on slide {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: hideTimer
        interval: 270
        running: false
        repeat: false
        onTriggered: {
            if (!panel.shown)
                panel.slidingOut = false;
        }
    }

    onShownChanged: {
        if (shown) {
            hideTimer.stop();
            slidingOut = false;
            slide = hiddenRight;
            slide = shownRight;
        } else {
            slidingOut = true;
            slide = hiddenRight;
            hideTimer.restart();
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: panel.borderColor
    }

    Item {
        id: topBlock
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        height: width

        Item {
            id: avatarBox
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: 210

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(panel.fgColor.r, panel.fgColor.g, panel.fgColor.b, 0.08)
            }

            Image {
                id: avatar
                anchors.fill: parent
                source: panel.avatarPath.length > 0 ? "file://" + panel.avatarPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !avatar.visible
                text: panel.userGlyph
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 64
                color: panel.fgColor
                opacity: 0.55
            }
        }

        Rectangle {
            id: userBand
            anchors {
                top: avatarBox.bottom
                left: parent.left
                right: parent.right
            }
            height: 30
            color: Qt.rgba(panel.fgColor.r, panel.fgColor.g, panel.fgColor.b, 0.06)

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: 1
                color: panel.borderColor
            }

            Text {
                id: userNameText
                anchors.centerIn: parent
                text: panel.userName
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: panel.fgColor
            }
        }

        Row {
            id: buttons
            anchors {
                top: userBand.bottom
                left: parent.left
                right: parent.right
            }
            height: parent.height - avatarBox.height - userBand.height
            spacing: 0

            Repeater {
                model: panel.actions

                delegate: Item {
                    width: buttons.width / panel.actions.length
                    height: buttons.height

                    property bool hovered: false

                    Rectangle {
                        anchors.fill: parent
                        color: parent.hovered
                            ? Qt.rgba(panel.accentColor.r, panel.accentColor.g,
                                      panel.accentColor.b, 0.12)
                            : "transparent"
                    }

                    Rectangle {
                        anchors {
                            top: parent.top
                            right: parent.right
                            bottom: parent.bottom
                        }
                        width: 1
                        color: panel.borderColor
                        visible: index > 0
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 26
                        color: parent.hovered ? panel.accentColor : panel.fgColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: Quickshell.execDetached(modelData.command)
                    }
                }
            }
        }
    }

    Rectangle {
        anchors {
            top: topBlock.bottom
            left: parent.left
            right: parent.right
        }
        height: 2
        color: panel.borderColor
    }
}
