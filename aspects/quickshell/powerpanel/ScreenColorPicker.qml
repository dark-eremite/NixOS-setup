import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: picker

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    surfaceFormat.opaque: false
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay

    visible: false

    property bool active: false
    property real cursorX: 0
    property real cursorY: 0
    property string sampledHex: "#000000"
    property color sampledColor: "#000000"
    property bool samplePending: false
    property bool sampleQueued: false

    signal picked(string hex)

    function start(): void {
        sampledHex = "#000000";
        sampledColor = "#000000";
        active = true;
        visible = true;
    }

    function stop(): void {
        active = false;
        visible = false;
        samplePending = false;
        sampleQueued = false;
        sampleTimer.stop();
    }

    function sampleAt(x: real, y: real): void {
        var sx = Math.max(0, Math.round(x));
        var sy = Math.max(0, Math.round(y));
        if (samplePending) {
            sampleQueued = true;
            picker.cursorX = sx;
            picker.cursorY = sy;
            return;
        }
        samplePending = true;
        sampleProc.command = [
            "sh", "-c",
            "grim -g \"$1,$2 1x1\" -t ppm - 2>/dev/null | tail -c 3 | od -An -tx1 | tr -d ' \\n'",
            "--", String(sx), String(sy)
        ];
        sampleProc.running = false;
        sampleProc.running = true;
    }

    function finishPick(): void {
        if (!active)
            return;
        var hex = sampledHex;
        stop();
        if (hex && hex.length === 7)
            picked(hex);
    }

    Timer {
        id: sampleTimer
        interval: 60
        repeat: false
        onTriggered: picker.sampleAt(picker.cursorX, picker.cursorY)
    }

    Process {
        id: sampleProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var hex = ("" + this.text).trim().toLowerCase();
                if (/^[0-9a-f]{6}$/.test(hex)) {
                    picker.sampledHex = "#" + hex.toUpperCase();
                    picker.sampledColor = picker.sampledHex;
                }
                picker.samplePending = false;
                if (picker.sampleQueued && picker.active) {
                    picker.sampleQueued = false;
                    picker.sampleTimer.restart();
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                picker.samplePending = false;
                if (picker.sampleQueued && picker.active) {
                    picker.sampleQueued = false;
                    picker.sampleTimer.restart();
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        cursorShape: Qt.CrossCursor
        onPositionChanged: function(mouse) {
            picker.cursorX = mouse.x;
            picker.cursorY = mouse.y;
            if (!sampleTimer.running && !picker.samplePending)
                sampleTimer.start();
            else
                picker.sampleQueued = true;
        }
        onPressed: function(mouse) {
            picker.cursorX = mouse.x;
            picker.cursorY = mouse.y;
            picker.finishPick();
        }
    }

    Rectangle {
        id: preview
        width: previewRow.implicitWidth + 12
        height: previewRow.implicitHeight + 12
        color: Qt.rgba(0.1, 0.1, 0.1, 0.9)
        border.width: 1
        border.color: "#59FFFFFF"
        radius: 0
        visible: picker.active

        x: Math.min(picker.width - width - 8, picker.cursorX + 18)
        y: Math.max(8, picker.cursorY - height - 18)

        Row {
            id: previewRow
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 24
                height: 24
                color: picker.sampledColor
                border.width: 1
                border.color: "#ffffff"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: picker.sampledHex
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: "#ffffff"
            }
        }
    }
}
