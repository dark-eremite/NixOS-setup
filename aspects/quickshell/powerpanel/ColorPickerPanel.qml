import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: picker

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    property real hue: 0
    property real saturation: 1
    property real value: 1

    function clamp01(x: real): real {
        return Math.max(0, Math.min(1, x));
    }

    function hsvToRgb(h: real, s: real, v: real): color {
        var hh = ((h % 360) + 360) % 360;
        var c = v * s;
        var x = c * (1 - Math.abs((hh / 60) % 2 - 1));
        var m = v - c;
        var r1 = 0, g1 = 0, b1 = 0;
        if (hh < 60) { r1 = c; g1 = x; b1 = 0; }
        else if (hh < 120) { r1 = x; g1 = c; b1 = 0; }
        else if (hh < 180) { r1 = 0; g1 = c; b1 = x; }
        else if (hh < 240) { r1 = 0; g1 = x; b1 = c; }
        else if (hh < 300) { r1 = x; g1 = 0; b1 = c; }
        else { r1 = c; g1 = 0; b1 = x; }
        return Qt.rgba(r1 + m, g1 + m, b1 + m, 1);
    }

    function toHex(n: int): string {
        var s = Math.max(0, Math.min(255, Math.round(n))).toString(16).toUpperCase();
        return s.length < 2 ? "0" + s : s;
    }

    readonly property color currentColor: hsvToRgb(hue, saturation, value)
    readonly property int red255: Math.round(currentColor.r * 255)
    readonly property int green255: Math.round(currentColor.g * 255)
    readonly property int blue255: Math.round(currentColor.b * 255)
    readonly property string hexString: "#" + toHex(red255) + toHex(green255) + toHex(blue255)
    readonly property string rgbString: "RGB(" + red255 + ", " + green255 + ", " + blue255 + ")"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(picker.bgColor.r, picker.bgColor.g,
                       picker.bgColor.b, 0.92)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: picker.borderColor
    }

    function copyText(text: string): void {
        copyProc.command = [
            "sh", "-c", "printf '%s' \"$1\" | wl-copy", "--", text
        ];
        copyProc.running = false;
        copyProc.running = true;
    }

    Process {
        id: copyProc
    }

    Column {
        id: content
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 10

        Row {
            id: pickerRow
            spacing: 10

            Item {
                id: svSquare
                width: 120
                height: 120

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: picker.hsvToRgb(picker.hue, 1, 1) }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#ff000000" }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: picker.borderColor
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: "transparent"
                    border.width: 2
                    border.color: picker.value > 0.5 ? "#000000" : "#ffffff"
                    x: picker.saturation * svSquare.width - width / 2
                    y: (1 - picker.value) * svSquare.height - height / 2
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: function(mouse) { updateSv(mouse.x, mouse.y); }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            updateSv(mouse.x, mouse.y);
                    }
                    function updateSv(x: real, y: real): void {
                        picker.saturation = picker.clamp01(x / svSquare.width);
                        picker.value = picker.clamp01(1 - y / svSquare.height);
                    }
                }
            }

            Item {
                id: hueRing
                width: 120
                height: 120

                readonly property real cx: width / 2
                readonly property real cy: height / 2
                readonly property real outerRadius: Math.min(width, height) / 2 - 2
                readonly property real innerRadius: outerRadius - 14

                Canvas {
                    id: hueCanvas
                    anchors.fill: parent
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var cx = hueRing.cx;
                        var cy = hueRing.cy;
                        var rOuter = hueRing.outerRadius;
                        var rInner = hueRing.innerRadius;
                        var rMid = (rOuter + rInner) / 2;
                        var thickness = rOuter - rInner;
                        for (var i = 0; i < 360; i++) {
                            var a1 = (i - 90 - 1) * Math.PI / 180;
                            var a2 = (i - 90 + 1) * Math.PI / 180;
                            ctx.beginPath();
                            ctx.strokeStyle = picker.hsvToRgb(i, 1, 1).toString();
                            ctx.lineWidth = thickness + 1;
                            ctx.arc(cx, cy, rMid, a1, a2, false);
                            ctx.stroke();
                        }
                        ctx.globalCompositeOperation = "destination-in";
                        ctx.beginPath();
                        ctx.arc(cx, cy, rOuter, 0, Math.PI * 2, false);
                        ctx.arc(cx, cy, rInner, 0, Math.PI * 2, true);
                        ctx.closePath();
                        ctx.fillStyle = "#ffffff";
                        ctx.fill();
                        ctx.globalCompositeOperation = "source-over";
                    }

                    Component.onCompleted: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    color: picker.hsvToRgb(picker.hue, 1, 1)
                    border.width: 2
                    border.color: "#ffffff"
                    property real a: (picker.hue - 90) * Math.PI / 180
                    property real r: (hueRing.outerRadius + hueRing.innerRadius) / 2
                    x: hueRing.cx + Math.cos(a) * r - width / 2
                    y: hueRing.cy + Math.sin(a) * r - height / 2
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: function(mouse) { updateHue(mouse.x, mouse.y); }
                    onPositionChanged: function(mouse) {
                        if (pressed)
                            updateHue(mouse.x, mouse.y);
                    }
                    function updateHue(x: real, y: real): void {
                        var dx = x - hueRing.cx;
                        var dy = y - hueRing.cy;
                        var angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
                        if (angle < 0) angle += 360;
                        picker.hue = angle % 360;
                    }
                }
            }
        }

        Rectangle {
            id: preview
            width: content.width
            height: 20
            color: picker.currentColor
            border.width: 1
            border.color: picker.borderColor
        }

        Item {
            id: hexRow
            width: content.width
            height: hexText.implicitHeight + 16

            property bool hovered: false

            Rectangle {
                anchors.fill: parent
                color: hexRow.hovered
                    ? Qt.rgba(picker.accentColor.r, picker.accentColor.g,
                              picker.accentColor.b, 0.12)
                    : Qt.rgba(picker.fgColor.r, picker.fgColor.g,
                              picker.fgColor.b, 0.04)
                border.width: 1
                border.color: hexRow.hovered
                    ? picker.accentColor
                    : Qt.rgba(picker.borderColor.r, picker.borderColor.g,
                              picker.borderColor.b, 0.5)
            }

            Text {
                id: hexText
                anchors {
                    fill: parent
                    margins: 8
                }
                text: picker.hexString
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: picker.fgColor
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: hexRow.hovered = true
                onExited: hexRow.hovered = false
                onClicked: picker.copyText(picker.hexString)
            }
        }

        Item {
            id: rgbRow
            width: content.width
            height: rgbText.implicitHeight + 16

            property bool hovered: false

            Rectangle {
                anchors.fill: parent
                color: rgbRow.hovered
                    ? Qt.rgba(picker.accentColor.r, picker.accentColor.g,
                              picker.accentColor.b, 0.12)
                    : Qt.rgba(picker.fgColor.r, picker.fgColor.g,
                              picker.fgColor.b, 0.04)
                border.width: 1
                border.color: rgbRow.hovered
                    ? picker.accentColor
                    : Qt.rgba(picker.borderColor.r, picker.borderColor.g,
                              picker.borderColor.b, 0.5)
            }

            Text {
                id: rgbText
                anchors {
                    fill: parent
                    margins: 8
                }
                text: picker.rgbString
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: picker.fgColor
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: rgbRow.hovered = true
                onExited: rgbRow.hovered = false
                onClicked: picker.copyText(picker.rgbString)
            }
        }
    }
}
