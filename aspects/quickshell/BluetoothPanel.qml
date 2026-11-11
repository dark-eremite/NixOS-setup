import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Окно управления bluetooth (BlueZ через D-Bus).
// Открывается по IPC `quickshell ipc call bluetooth toggle` / хоткею Mod+B
// и по клику на иконку bluetooth в трее.
FloatingWindow {
    id: panel

    title: "Bluetooth"
    implicitWidth: 340
    implicitHeight: 420
    minimumSize: Qt.size(340, 260)
    color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)

    // Палитра приходит из ShellRoot (shell.qml), чтобы окно меняло цвета
    // вместе с баром при смене обоев/темы.
    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    property bool shown: false
    visible: shown

    onClosed: shown = false

    IpcHandler {
        target: "bluetooth"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    // --- Состояние устройств -------------------------------------------------
    // Bluetooth.devices — QAbstractListModel; values — список QObject.
    // Пересобираем две секции при изменении состава или состояния устройств.
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

    // connected/paired/state/battery меняются без изменения состава модели —
    // пересобираем по сигналам каждого устройства.
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

    // --- Вёрстка -------------------------------------------------------------
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

        // Заголовок + питание адаптера
        Row {
            width: parent.width
            height: 26
            spacing: 8

            Text {
                width: parent.width - parent.spacing - powerButton.width
                height: parent.height
                text: "  Bluetooth"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: fgColor
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: powerButton
                width: 74
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: adapterOn ? accentColor : borderColor

                property bool adapterOn: Bluetooth.defaultAdapter
                    ? Bluetooth.defaultAdapter.enabled : false

                Text {
                    anchors.centerIn: parent
                    text: powerButton.adapterOn ? "ON" : "OFF"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: fgColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                    }
                }
            }
        }

        // Статус адаптера + кнопка сканирования
        Row {
            width: parent.width
            height: 24
            spacing: 8

            Text {
                id: adapterStatus
                width: parent.width - parent.spacing - scanButton.width
                height: parent.height
                text: {
                    var a = Bluetooth.defaultAdapter;
                    if (!a) return "Адаптер не найден";
                    var s = BluetoothAdapterState.toString(a.state);
                    return a.name + " · " + s + (a.discovering ? " · поиск…" : "");
                }
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                color: fgColor
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: scanButton
                width: 74
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: borderColor

                property bool scanning: Bluetooth.defaultAdapter
                    ? Bluetooth.defaultAdapter.discovering : false

                Text {
                    anchors.centerIn: parent
                    text: scanButton.scanning ? "■ stop" : "⟳ scan"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    color: fgColor
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
        }

        Rectangle { width: parent.width; height: 1; color: borderColor }

        // Секции со списком устройств (Flickable занимает остаток высоты)
        Flickable {
            id: flick
            width: parent.width
            height: content.height - 26 - 24 - 1 - 3 * content.spacing
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
                }
            }
        }
    }
}
