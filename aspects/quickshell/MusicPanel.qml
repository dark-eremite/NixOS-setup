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
        top: panel.slide
        left: panel.widgetCenter - panel.implicitWidth / 2
    }
    implicitWidth: 422
    implicitHeight: 152
    color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0
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
    readonly property real hiddenTop: -(implicitHeight + 8 + topInset)
    readonly property real shownTop: 8 + topInset
    property real slide: hiddenTop

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
            slide = hiddenTop;
            slide = shownTop;
        } else {
            slidingOut = true;
            slide = hiddenTop;
            hideTimer.restart();
        }
    }

    IpcHandler {
        target: "music"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
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
