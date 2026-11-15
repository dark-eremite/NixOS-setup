import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
    id: panel

    anchors {
        top: true
        left: true
    }
    margins {
        // The window is taller than the panel and reaches above the screen top,
        // so the body can slide in from the very top edge of the screen.
        top: -panel.bodyHeight
        left: panel.widgetCenter - panel.implicitWidth / 2
    }
    implicitWidth: 422
    implicitHeight: panel.travel + panel.bodyHeight
    color: "transparent"
    surfaceFormat.opaque: false

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0

    // Height of the visible panel body (without the sliding space above it).
    property int bodyHeight: 152
    // Distance the body travels: fully off-screen (above) -> resting position.
    readonly property int travel: bodyHeight + 8 + topInset
    property real widgetCenter: 0

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"
    property color subduedColor: "#808080"

    property string trackTitle: ""
    property string trackArtist: ""
    property string artUrl: ""
    property string elapsedLabel: "0:00"
    property string totalLabel: "0:00"
    property real progress: 0
    property bool playing: false
    property bool canPrevious: false
    property bool canNext: false
    property bool canToggle: false
    property bool canSeek: false
    property bool hasTrack: false

    signal previousRequested()
    signal toggleRequested()
    signal nextRequested()
    signal seekRequested(real fraction)

    readonly property string albumGlyph: "\u{f0025}"
    readonly property string previousGlyph: "\u{f04ae}"
    readonly property string playGlyph: "\u{f040a}"
    readonly property string pauseGlyph: "\u{f03e4}"
    readonly property string nextGlyph: "\u{f04ad}"

    onClosed: shown = false

    property bool shown: false
    property bool slidingOut: false
    // Offset of the body inside the window: -travel = hidden above the screen,
    // 0 = resting position. The window itself never moves, only the body does,
    // because layer-shell margins are only applied on surface commit.
    property real slide: -travel

    visible: shown || slidingOut

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
            slide = -travel;
            slide = 0;
        } else {
            slidingOut = true;
            slide = -travel;
            hideTimer.restart();
        }
    }

    IpcHandler {
        target: "music"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    // The body is the only thing that moves: the window keeps a fixed
    // position, the body slides inside it (see AGENT.md, 'Анимация панелей').
    Item {
        id: body
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: panel.bodyHeight
        transform: Translate { y: panel.slide }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: borderColor
        }

        Row {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Item {
                id: coverBox
                width: 104
                height: 104
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.08)
                    border.width: 1
                    border.color: borderColor
                }

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: panel.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !coverImage.visible
                    text: panel.albumGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 48
                    color: fgColor
                    opacity: 0.55
                }
            }

            Item {
                id: info
                width: parent.width - coverBox.width - parent.spacing
                height: 104
                anchors.verticalCenter: coverBox.verticalCenter

                Column {
                    id: infoColumn
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                    spacing: 6

                    Text {
                        id: titleText
                        width: parent.width
                        height: 20
                        text: panel.hasTrack ? panel.trackTitle : "Нет воспроизведения"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: fgColor
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: artistText
                        width: parent.width
                        height: 16
                        text: panel.trackArtist
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: subduedColor
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Row {
                        id: progressRow
                        width: parent.width
                        height: 14
                        spacing: 8

                        Rectangle {
                            id: progressTrack
                            width: parent.width - timeText.width - parent.spacing
                            height: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.18)
                            border.width: 1
                            border.color: borderColor

                            Rectangle {
                                width: progressTrack.width * panel.progress
                                height: parent.height
                                color: accentColor
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: panel.canSeek && panel.hasTrack
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: panel.seekRequested(mouseX / width)
                            }
                        }

                        Text {
                            id: timeText
                            width: 76
                            height: parent.height
                            text: panel.elapsedLabel + "/" + panel.totalLabel
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: fgColor
                            opacity: 0.75
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Row {
                    id: buttonsRow
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                    }
                    spacing: 8

                    Repeater {
                        model: [
                            { glyph: panel.previousGlyph, action: "prev", active: panel.canPrevious },
                            { glyph: panel.playGlyph, action: "toggle", active: panel.canToggle },
                            { glyph: panel.nextGlyph, action: "next", active: panel.canNext }
                        ]

                        delegate: Item {
                            width: 28
                            height: 28

                            property string action: modelData.action
                            property bool active: modelData.active
                            property string glyph: action === "toggle"
                                ? (panel.playing ? panel.pauseGlyph : panel.playGlyph)
                                : modelData.glyph

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: borderColor
                            }

                            Text {
                                anchors.centerIn: parent
                                width: implicitWidth
                                height: implicitHeight
                                text: parent.glyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 14
                                color: parent.action === "toggle" && panel.playing
                                    ? accentColor : fgColor
                                opacity: parent.active ? 1 : 0.35
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: parent.active
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (parent.action === "prev") panel.previousRequested();
                                    else if (parent.action === "toggle") panel.toggleRequested();
                                    else panel.nextRequested();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
