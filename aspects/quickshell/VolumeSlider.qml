import QtQuick

Rectangle {
    id: slider

    property real value: 0
    property real maxValue: 1.0
    property bool muted: false
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"
    property color fgColor: "#e1e2e9"

    signal moved(real newValue)

    readonly property real fraction: maxValue > 0
        ? Math.max(0, Math.min(1, value / maxValue)) : 0
    readonly property real knobX: 2 + fraction * Math.max(0, width - 4)

    color: "transparent"
    border.width: 1
    border.color: borderColor

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: slider.knobX
        color: slider.muted
            ? Qt.rgba(slider.fgColor.r, slider.fgColor.g, slider.fgColor.b, 0.18)
            : Qt.rgba(slider.accentColor.r, slider.accentColor.g,
                      slider.accentColor.b, 0.38)
    }

    Rectangle {
        width: 4
        height: parent.height
        x: slider.knobX - width / 2
        y: 0
        color: slider.muted ? slider.fgColor : slider.accentColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        property bool dragging: false

        function apply(): void {
            var f = Math.max(0, Math.min(1, (mouseX - 2) / Math.max(1, width - 4)));
            slider.moved(f * slider.maxValue);
        }

        onPressed: {
            dragging = true;
            apply();
        }
        onReleased: dragging = false
        onCanceled: dragging = false
        onPositionChanged: if (dragging) apply()
        onClicked: apply()
    }
}
