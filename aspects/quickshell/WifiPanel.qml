import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

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

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    focusable: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0

    // Height of the visible panel body (without the sliding space above it).
    property int bodyHeight: 420
    // Distance the body travels: fully off-screen (above) -> resting position.
    readonly property int travel: bodyHeight + 8 + topInset

    property int connectivity: 0
    property string portalUrl: ""

    signal networksChanged()

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
            panel.setScan(true);
        } else {
            slidingOut = true;
            slide = -travel;
            hideTimer.restart();
            panel.setScan(false);
        }
    }

    IpcHandler {
        target: "wifi"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    property var connectedNetworks: []
    property var availableNetworks: []
    property var allNetworks: []

    function setScan(on: bool): void {
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (d && d.type === DeviceType.Wifi)
                d.scannerEnabled = on;
        }
    }

    function rebuild(): void {
        var connected = [];
        var available = [];
        var devs = Networking.devices ? Networking.devices.values : [];

        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!d || d.type !== DeviceType.Wifi) continue;

            var nets = d.networks ? d.networks.values : [];
            for (var j = 0; j < nets.length; j++) {
                var n = nets[j];
                if (!n) continue;
                if (n.connected)
                    connected.push(n);
                else
                    available.push(n);
            }
        }

        available.sort(function (a, b) {
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });

        panel.connectedNetworks = connected;
        panel.availableNetworks = available;
        panel.allNetworks = connected.concat(available);
        panel.networksChanged();
    }

    Component.onCompleted: panel.rebuild()

    Connections {
        target: Networking.devices
        function onValuesChanged(): void { panel.rebuild(); }
    }

    Instantiator {
        model: Networking.devices
        delegate: Connections {
            required property var modelData
            target: modelData.networks
            function onValuesChanged(): void { panel.rebuild(); }
        }
    }

    Instantiator {
        model: panel.connectedNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void { panel.rebuild(); }
            function onSignalStrengthChanged(): void { panel.rebuild(); }
        }
    }

    Instantiator {
        model: panel.availableNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void { panel.rebuild(); }
            function onSignalStrengthChanged(): void { panel.rebuild(); }
            function onNameChanged(): void { panel.rebuild(); }
        }
    }

    property bool wifiOn: Networking.wifiEnabled

    Connections {
        target: Networking
        function onWifiEnabledChanged(): void { panel.rebuild(); }
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
                    id: titleText
                    width: parent.width - 2 * parent.spacing - scanButton.width - powerButton.width
                    height: parent.height
                    text: "Wi-Fi"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: fgColor
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    id: scanButton
                    width: 26
                    height: parent.height
                    color: "transparent"
                    border.width: 1
                    border.color: scanning ? accentColor : borderColor

                    property bool scanning: {
                        var devs = Networking.devices ? Networking.devices.values : [];
                        for (var i = 0; i < devs.length; i++)
                            if (devs[i] && devs[i].type === DeviceType.Wifi
                                && devs[i].scannerEnabled) return true;
                        return false;
                    }

                    Text {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        text: "\uf002"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: scanButton.scanning ? accentColor : fgColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.setScan(!scanButton.scanning)
                    }
                }

                Rectangle {
                    id: powerButton
                    width: 26
                    height: parent.height
                    color: "transparent"
                    border.width: 1
                    border.color: wifiOn ? accentColor : borderColor

                    Text {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        text: "\u{f0425}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: wifiOn ? accentColor : fgColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !panel.wifiOn
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: borderColor }

            Flickable {
                id: flick
                width: parent.width
                height: content.height - 26 - 1 - 2 * content.spacing
                contentHeight: listColumn.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: listColumn
                    width: parent.width
                    spacing: 8

                    WifiSection {
                        width: parent.width
                        heading: ""
                        networks: panel.allNetworks
                        emptyText: "Нет доступных сетей"
                        connectivity: panel.connectivity
                        portalUrl: panel.portalUrl
                        bgColor: panel.bgColor
                        fgColor: panel.fgColor
                        accentColor: panel.accentColor
                        borderColor: panel.borderColor
                    }
                }
            }
        }
    }
}
