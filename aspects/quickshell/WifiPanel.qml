import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// Панель Wi-Fi — полный аналог BluetoothPanel: layer-shell (PanelWindow),
// прижата к правому верхнему углу, выезжает сверху по IPC `wifi toggle`
// / хоткею Mod+I / клику по иконке в трее.
//
// Источник данных — встроенный синглтон Quickshell.Networking
// (NetworkManager через D-Bus), НЕ парсинг nmcli/iw.
//
// Состояние иконки трея (сила сигнала, связность, ethernet) и опрос раз в
// 30 с живут в ShellRoot (shell.qml), как и состояние bluetooth. Сюда
// пробрасываются только снимки connectivity / portalUrl для строк списка.
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

    // Снимок NetworkConnectivity (0..4) и URL страницы портала из ShellRoot.
    property int connectivity: 0
    property string portalUrl: ""

    // Списки сетей пересобраны — просим ShellRoot обновить снимок иконки
    // трея. Сигналы D-Bus приходят асинхронно и ненадёжны как триггер:
    // rebuild() — единственная точка, где модель точно уже актуальна.
    signal networksChanged()

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
            panel.setScan(true);       // обновляем список AP, пока открыты
        } else {
            slidingOut = true;
            slide = hiddenTop;
            hideTimer.restart();
            panel.setScan(false);      // не сканируем в фоне
        }
    }

    IpcHandler {
        target: "wifi"

        function toggle(): void { panel.shown = !panel.shown; }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    // ---- Устройства и сети -------------------------------------------------

    property var connectedNetworks: []
    property var availableNetworks: []

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

        // Доступные — по убыванию силы сигнала.
        available.sort(function (a, b) {
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });

        panel.connectedNetworks = connected;
        panel.availableNetworks = available;
        panel.networksChanged();
    }

    Component.onCompleted: panel.rebuild()

    Connections {
        target: Networking.devices
        function onValuesChanged(): void { panel.rebuild(); }
    }

    // Списки сетей меняются при сканировании (AP пришли/ушли).
    Instantiator {
        model: Networking.devices
        delegate: Connections {
            required property var modelData
            target: modelData.networks
            function onValuesChanged(): void { panel.rebuild(); }
        }
    }

    // Пересбор при смене connected/силы/имени у каждой сети.
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

    // ---- Питание Wi-Fi -----------------------------------------------------

    property bool wifiOn: Networking.wifiEnabled

    Connections {
        target: Networking
        function onWifiEnabledChanged(): void { panel.rebuild(); }
    }

    // ---- Вёрстка -----------------------------------------------------------

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
                    text: "\uf002"       // nf-fa-search
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
                    text: "\u{f0425}"   // nf-md-power
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
                    heading: "Подключённые"
                    networks: panel.connectedNetworks
                    emptyText: "Нет подключённых сетей"
                    connectivity: panel.connectivity
                    portalUrl: panel.portalUrl
                    bgColor: panel.bgColor
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                }

                WifiSection {
                    width: parent.width
                    heading: "Доступные"
                    networks: panel.availableNetworks
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
