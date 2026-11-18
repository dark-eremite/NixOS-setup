import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popup

    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: 12
        right: 12 - popup.travel
    }
    implicitWidth: popup.bodyWidth + popup.travel
    implicitHeight: popup.bodyHeight
    color: "transparent"
    surfaceFormat.opaque: false

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    property int bodyWidth: 422
    property int bodyHeight: 152
    readonly property int travel: bodyWidth + 12

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    property bool shown: false
    property bool slidingOut: false
    property real slide: travel

    property string summary: ""
    property string body: ""
    property string appName: ""

    visible: shown || slidingOut

    onShownChanged: {
        if (shown) {
            hideTimer.stop();
            slidingOut = false;
            slide = travel;
            slide = 0;
            dismissTimer.restart();
        } else {
            slidingOut = true;
            slide = travel;
            outTimer.restart();
        }
    }

    Behavior on slide {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: outTimer
        interval: 270
        running: false
        repeat: false
        onTriggered: {
            if (!popup.shown)
                popup.slidingOut = false;
        }
    }

    Timer {
        id: dismissTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: popup.shown = false
    }

    function showNotification(n): void {
        summary = n.summary || "";
        body = n.body || "";
        appName = n.appName || "";
        shown = false;
        shown = true;
    }

    NotificationServer {
        id: server

        onNotification: function (notification) {
            notification.tracked = true;
            popup.showNotification(notification);
        }
    }

    Item {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        width: popup.bodyWidth
        transform: Translate { x: popup.slide }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: popup.borderColor
        }

        Column {
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 6

            Text {
                width: parent.width
                visible: popup.appName.length > 0
                text: popup.appName
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: popup.accentColor
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: popup.summary.length > 0 ? popup.summary : "Новое уведомление"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                font.bold: true
                color: popup.fgColor
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }

            Text {
                width: parent.width
                height: parent.height - y
                text: popup.body
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                color: popup.fgColor
                opacity: 0.85
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 4
            }
        }
    }
}
