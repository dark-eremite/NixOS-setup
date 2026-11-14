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
        top: panel.slide
        right: 12
    }
    implicitWidth: 340
    implicitHeight: 420
    color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)

    aboveWindows: true
    focusable: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

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
            panel.rebuild();
        } else {
            slidingOut = true;
            slide = hiddenTop;
            hideTimer.restart();
        }
    }

    IpcHandler {
        target: "microphone"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    property var sources: []
    property var captureStreams: []
    property var micNodes: []

    property var defaultSource: Pipewire.defaultAudioSource
    property var activeSource: Pipewire.preferredDefaultAudioSource
        || Pipewire.defaultAudioSource

    property var master: defaultSource
    property real masterVolume: master && master.audio ? master.audio.volume : 0
    property bool masterMuted: master && master.audio ? master.audio.muted : false

    property string micGlyph: "\u{f036c}"
    property string micOffGlyph: "\u{f036d}"

    readonly property string masterLabel: master
        ? (master.description || master.nickname || master.name) : ""

    function rebuild(): void {
        var a = [];
        var s = [];
        var st = [];
        var vals = Pipewire.nodes.values;
        for (var i = 0; i < vals.length; i++) {
            var n = vals[i];
            if (!n || !n.audio || n.isSink) continue;
            var category = n.properties ? n.properties["media.category"] : "";
            if (category === "Monitor" || category === "Manager") continue;
            a.push(n);
            if (!n.isStream)
                s.push(n);
            else
                st.push(n);
        }
        panel.micNodes = a;
        panel.sources = s;
        panel.captureStreams = st;
    }

    Component.onCompleted: rebuild()

    Connections {
        target: Pipewire.nodes
        function onValuesChanged(): void { panel.rebuild(); }
    }

    PwObjectTracker { objects: panel.micNodes }

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
                text: "Микрофон"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: fgColor
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: iconText
                width: implicitWidth
                height: parent.height
                text: panel.masterMuted ? panel.micOffGlyph : panel.micGlyph
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
                        ? panel.masterLabel : "Нет устройства ввода"
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
                            ? panel.micOffGlyph : panel.micGlyph
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
                    heading: "Устройства ввода"
                    nodes: panel.sources
                    activeNode: panel.activeSource
                    emptyText: "Нет устройств ввода"
                    glyph: panel.micGlyph
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                    onNodeSelected: function (node) {
                        Pipewire.preferredDefaultAudioSource = node;
                    }
                }

                StreamSection {
                    width: parent.width
                    heading: "Приложения"
                    streams: panel.captureStreams
                    emptyText: "Нет активных приложений"
                    glyph: panel.micGlyph
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                }
            }
        }
    }
}
