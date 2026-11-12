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
        top: panel.slide
        right: 12
    }
    implicitWidth: 340
    implicitHeight: 420
    color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)

    aboveWindows: true

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
    readonly property real hiddenTop: -(implicitHeight + 8)
    readonly property real shownTop: 8
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

    function rebuild(): void {
        var connected = [];
        var available = [];
        var vals = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i];
            if (!d) continue;
            if (d.connected)
                connected.push(d);
            else
                available.push(d);
        }
        panel.connectedDevices = connected;
        panel.availableDevices = available;
    }

    Component.onCompleted: rebuild()

    Connections {
        target: Bluetooth.devices
        function onValuesChanged(): void { panel.rebuild(); }
    }

    Instantiator {
        model: Bluetooth.devices
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged(): void { panel.rebuild(); }
            function onStateChanged(): void { panel.rebuild(); }
            function onPairedChanged(): void { panel.rebuild(); }
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
                }
            }
        }
    }
}
