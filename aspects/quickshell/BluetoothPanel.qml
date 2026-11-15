import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

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

    function stopScan(): void {
        var a = Bluetooth.defaultAdapter;
        if (a && a.discovering)
            a.discovering = false;
    }

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
            stopScan();
        }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    property var connectedDevices: []
    property var availableDevices: []
    property var lastConnectAttempt: ({})
    property var heldDevices: ({})

    readonly property int pollIntervalMs: 5000
    readonly property int retryIntervalMs: 10000
    readonly property int manualHoldMs: 30000

    function rebuild(): void {
        var connected = [];
        var paired = [];
        var available = [];
        var vals = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i];
            if (!d) continue;
            if (d.connected)
                connected.push(d);
            else if (d.paired || d.bonded)
                paired.push(d);
            else
                available.push(d);
        }
        panel.connectedDevices = connected.concat(paired);
        panel.availableDevices = available;
    }

    function holdDevice(address: string): void {
        if (address)
            panel.heldDevices[address] = Date.now();
    }

    function pollPairedDevices(): void {
        var adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.enabled) return;
        var now = Date.now();
        var vals = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i];
            if (!d || d.connected || !(d.paired || d.bonded)) continue;
            if (d.state !== BluetoothDeviceState.Disconnected) continue;
            var key = d.address;
            if (!key) continue;
            if (now - (panel.heldDevices[key] || 0) < panel.manualHoldMs) continue;
            if (now - (panel.lastConnectAttempt[key] || 0) < panel.retryIntervalMs) continue;
            panel.lastConnectAttempt[key] = now;
            d.connect();
        }
    }

    Component.onCompleted: rebuild()

    Timer {
        interval: panel.pollIntervalMs
        running: panel.adapterOn
        repeat: true
        triggeredOnStart: true
        onTriggered: panel.pollPairedDevices()
    }

    Connections {
        target: Bluetooth.devices
        function onValuesChanged(): void {
            panel.rebuild();
            panel.pollPairedDevices();
        }
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void {
                if (modelData.connected)
                    delete panel.heldDevices[modelData.address];
                panel.rebuild();
            }
            function onStateChanged(): void { panel.rebuild(); }
            function onPairedChanged(): void { panel.rebuild(); }
            function onBondedChanged(): void { panel.rebuild(); }
            function onBatteryChanged(): void { panel.rebuild(); }
            function onNameChanged(): void { panel.rebuild(); }
        }
    }

    property bool adapterPresent: Bluetooth.defaultAdapter !== null
    property bool adapterOn: Bluetooth.defaultAdapter
        ? Bluetooth.defaultAdapter.enabled : false
    property bool powerBusy: false

    function setPower(on: bool): void {
        if (Bluetooth.defaultAdapter) {
            Bluetooth.defaultAdapter.enabled = on;
            return;
        }
        if (powerBusy) return;
        powerBusy = true;
        powerProc.command = [ "bluetoothctl", "power", on ? "on" : "off" ];
        powerProc.running = true;
    }

    Process {
        id: powerProc
        running: false
        stdout: StdioCollector { waitForEnd: true }
        onExited: panel.powerBusy = false
    }

    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged(): void { panel.rebuild(); }
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
                    text: "Bluetooth"
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

                    property bool scanning: Bluetooth.defaultAdapter
                        ? Bluetooth.defaultAdapter.discovering : false

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
                        onClicked: {
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.discovering =
                                    !Bluetooth.defaultAdapter.discovering;
                        }
                    }
                }

                Rectangle {
                    id: powerButton
                    width: 26
                    height: parent.height
                    color: "transparent"
                    border.width: 1
                    border.color: adapterOn ? accentColor : borderColor

                    Text {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        text: "\u{f0425}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: powerBusy ? borderColor
                             : (adapterOn ? accentColor : fgColor)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: setPower(!adapterOn)
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

                    BtSection {
                        width: parent.width
                        heading: "Подключённые"
                        devices: panel.connectedDevices
                        emptyText: "Нет подключённых устройств"
                        bgColor: panel.bgColor
                        fgColor: panel.fgColor
                        accentColor: panel.accentColor
                        borderColor: panel.borderColor
                        onDeviceSelected: panel.stopScan()
                        onDeviceReleased: function (device) { panel.holdDevice(device.address); }
                    }

                    BtSection {
                        width: parent.width
                        heading: "Доступные"
                        devices: panel.availableDevices
                        emptyText: "Нет доступных устройств"
                        bgColor: panel.bgColor
                        fgColor: panel.fgColor
                        accentColor: panel.accentColor
                        borderColor: panel.borderColor
                        onDeviceSelected: panel.stopScan()
                        onDeviceReleased: function (device) { panel.holdDevice(device.address); }
                    }
                }
            }
        }
    }
}
