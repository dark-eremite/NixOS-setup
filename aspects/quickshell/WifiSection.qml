import QtQuick
import Quickshell
import Quickshell.Networking

// Секция списка сетей. Иконка строки — nf-md-wifi_strength_<1..4> по силе
// сигнала (signalStrength приходит как доля 0..1 из NM Strength / 100).
// У ПОДКЛЮЧЁННОЙ сети иконка меняется на *_alert (нет интернета) или
// *_lock (captive-портал) по глобальной связности; справа такой строки
// появляется кнопка nf-md-key_link, открывающая страницу портала.
// Остальные сети в списке — просто доступные AP, им всегда обычный glyph.
Column {
    id: section

    property string heading: ""
    property var networks: []
    property string emptyText: ""
    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    // Снимок глобальной связности (NetworkConnectivity): Unknown=0, None=1,
    // Portal=2, Limited=3, Full=4. Приходит из WifiPanel раз в 30 с.
    property int connectivity: 0
    property string portalUrl: ""

    signal networkSelected()

    width: 300
    spacing: 4

    readonly property var strengthGlyphs: [
        "\u{f091f}", "\u{f0922}", "\u{f0925}", "\u{f0928}"
    ]
    readonly property var alertGlyphs: [
        "\u{f0920}", "\u{f0923}", "\u{f0926}", "\u{f0929}"
    ]
    readonly property var lockGlyphs: [
        "\u{f0921}", "\u{f0924}", "\u{f0927}", "\u{f092a}"
    ]

    // 0..1 -> 1..4. Сигнал 0 (AP пропал из эфира) всё равно даёт 1,
    // чтобы не рисовать «пустую» иконку.
    function bars(signal): int {
        var s = Math.max(0, Math.min(1, signal || 0));
        return Math.max(1, Math.min(4, Math.ceil(s * 4)));
    }

    function glyphFor(net): string {
        var n = section.bars(net.signalStrength) - 1;
        if (!net.connected)
            return section.strengthGlyphs[n];
        if (section.connectivity === 2)      // Portal
            return section.lockGlyphs[n];
        if (section.connectivity === 3 || section.connectivity === 1) // Limited / None
            return section.alertGlyphs[n];
        return section.strengthGlyphs[n];
    }

    function openPortal(): void {
        // ConnectivityCheckUri из NetworkManager; фолбэк — detection-URL,
        // который сам редиректит на страницу авторизации портала.
        var url = section.portalUrl.length > 0
            ? section.portalUrl
            : "http://nmcheck.gnome.org/check_network_status.txt";
        Quickshell.execDetached([ "xdg-open", url ]);
    }

    Text {
        width: parent.width
        height: 18
        text: section.heading + "  " + section.networks.length
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 11
        color: section.accentColor
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        width: parent.width
        height: 22
        visible: section.networks.length === 0
        text: section.emptyText
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 10
        color: section.fgColor
        opacity: 0.6
        verticalAlignment: Text.AlignVCenter
    }

    Repeater {
        model: section.networks

        delegate: Rectangle {
            id: cell
            width: section.width
            height: 34
            color: modelData.connected
                ? Qt.rgba(section.accentColor.r, section.accentColor.g,
                          section.accentColor.b, 0.18)
                : "transparent"
            border.width: 1
            border.color: section.borderColor

            required property var modelData

            // Кнопка портала — только у подключённой сети с Portal.
            readonly property bool onPortal: modelData.connected
                && section.connectivity === 2

            // Клик по строке подключает / отключает сеть. Объявлен ПЕРВЫМ
            // (ниже Row по z), иначе он перехватил бы клик по кнопке портала.
            // Text/Rectangle без MouseArea прозрачны для мыши, поэтому клики
            // по остальной части строки всё равно доходят сюда.
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    section.networkSelected();
                    if (modelData.connected)
                        modelData.disconnect();
                    else
                        modelData.connect();
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Text {
                    width: 20
                    height: parent.height
                    text: section.glyphFor(modelData)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: modelData.connected ? section.accentColor : section.fgColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Column {
                    width: parent.width - 20 - 8 - 8 - actionIcon.width
                        - (portalButton.visible ? portalButton.width + parent.spacing : 0)
                    height: parent.height
                    spacing: 1

                    Text {
                        width: parent.width
                        text: modelData.name || modelData.address
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: section.fgColor
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: Math.round((modelData.signalStrength || 0) * 100) + "%"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 9
                        color: section.fgColor
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: actionIcon
                    width: 20
                    height: parent.height
                    // nf-md-lan_disconnect / nf-md-lan_connect
                    text: modelData.connected ? "\u{f0319}" : "\u{f0318}"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: modelData.connected ? section.accentColor : section.fgColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // nf-md-key_link: ведёт на страницу авторизации портала.
                // Width 20 и visible=false убирают кнопку из раскладки,
                // когда портала нет (колонка имени занимает всё место).
                Rectangle {
                    id: portalButton
                    width: 20
                    height: parent.height
                    visible: cell.onPortal
                    color: "transparent"
                    border.width: 1
                    border.color: section.accentColor

                    Text {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        text: "\u{f119f}"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: section.accentColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.openPortal()
                    }
                }
            }
        }
    }
}
