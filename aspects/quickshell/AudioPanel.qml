import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

PanelWindow {
    id: panel

    anchors {
        top: true
        right: true
    }
    margins {
        // The window is taller than the panel and reaches above the screen top,
        // so the body can slide in from the very top edge of the screen.
        top: -panel.bodyHeight
        right: 12
    }
    implicitWidth: 340
    implicitHeight: panel.travel + panel.bodyHeight
    color: "transparent"
    surfaceFormat.opaque: false

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0

    // Height of the visible panel body (without the sliding space above it).
    property int bodyHeight: 420
    // Distance the body travels: fully off-screen (above) -> resting position.
    readonly property int travel: bodyHeight + 8 + topInset

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

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
            panel.rebuild();
        } else {
            slidingOut = true;
            slide = -travel;
            hideTimer.restart();
        }
    }

    IpcHandler {
        target: "audio"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    property var sinks: []
    property var streams: []
    property var audioNodes: []

    property var defaultSink: Pipewire.defaultAudioSink
    property var activeSink: Pipewire.preferredDefaultAudioSink
        || Pipewire.defaultAudioSink

    property var master: defaultSink
    property real masterVolume: master && master.audio ? master.audio.volume : 0
    property bool masterMuted: master && master.audio ? master.audio.muted : false

    property string volumeGlyph: "\u{f057e}"
    property string muteGlyph: "\u{f0581}"

    readonly property string masterLabel: master
        ? (master.description || master.nickname || master.name) : ""

    function rebuild(): void {
        var a = [];
        var s = [];
        var st = [];
        var vals = Pipewire.nodes.values;
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i];
            if (!n || !n.audio) continue;
            a.push(n);
            if (n.isSink && !n.isStream)
                s.push(n);
            else if (n.isSink && n.isStream)
                st.push(n);
        }
        panel.audioNodes = a;
        panel.sinks = s;
        panel.streams = st;
    }

    Component.onCompleted: rebuild()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void { panel.rebuild(); }
    }

    PwObjectTracker { objects: panel.audioNodes }

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

        Column {
            id: content
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Row {
                width: parent.width
                height: 26
                spacing: 8

                Text {
                    width: parent.width - parent.spacing - iconText.width
                    height: parent.height
                    text: "Звук"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: fgColor
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: iconText
                    width: implicitWidth
                    height: parent.height
                    text: panel.masterMuted ? panel.muteGlyph : panel.volumeGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: panel.masterMuted ? fgColor : accentColor
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Rectangle { width: parent.width; height: 1; color: borderColor }

            Column {
                width: parent.width
                spacing: 4

                Row {
                    width: parent.width
                    height: 16
                    spacing: 6

                    Text {
                        width: parent.width - parent.spacing - masterPercent.width
                        height: parent.height
                        text: panel.masterLabel.length > 0
                            ? panel.masterLabel : "Нет устройства вывода"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: fgColor
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        id: masterPercent
                        width: 36
                        height: parent.height
                        text: Math.round(panel.masterVolume * 100) + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color: fgColor
                        opacity: 0.6
                        horizontalAlignment: Text.AlignRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Row {
                    width: parent.width
                    height: 16
                    spacing: 6

                    Rectangle {
                        width: 20
                        height: 16
                        color: "transparent"
                        border.width: 1
                        border.color: panel.masterMuted ? accentColor : borderColor

                        Text {
                            anchors.centerIn: parent
                            width: implicitWidth
                            height: implicitHeight
                            text: panel.masterMuted
                                ? panel.muteGlyph : panel.volumeGlyph
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: panel.masterMuted ? accentColor : fgColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (panel.master && panel.master.audio)
                                    panel.master.audio.muted = !panel.master.audio.muted;
                            }
                        }
                    }

                    VolumeSlider {
                        width: parent.width - 20 - parent.spacing
                        height: 16
                        value: panel.masterVolume
                        muted: panel.masterMuted
                        accentColor: panel.accentColor
                        borderColor: panel.borderColor
                        fgColor: panel.fgColor
                        onMoved: function (v) {
                            if (panel.master && panel.master.audio)
                                panel.master.audio.volume = v;
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: borderColor }

            Flickable {
                id: flick
                width: parent.width
                height: content.height - flick.y
                contentHeight: listColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listColumn
                    width: parent.width
                    spacing: 8

                    OutputSection {
                        width: parent.width
                        heading: "Устройства вывода"
                        nodes: panel.sinks
                        activeNode: panel.activeSink
                        emptyText: "Нет устройств вывода"
                        fgColor: panel.fgColor
                        accentColor: panel.accentColor
                        borderColor: panel.borderColor
                        onNodeSelected: function (node) {
                            Pipewire.preferredDefaultAudioSink = node;
                        }
                    }

                    StreamSection {
                        width: parent.width
                        heading: "Приложения"
                        streams: panel.streams
                        emptyText: "Нет активных приложений"
                        fgColor: panel.fgColor
                        accentColor: panel.accentColor
                        borderColor: panel.borderColor
                    }
                }
            }
        }
    }
}
