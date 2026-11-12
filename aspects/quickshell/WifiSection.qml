import QtQuick
import Quickshell
import Quickshell.Networking

Column {
    id: section

    property string heading: ""
    property var networks: []
    property string emptyText: ""
    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    property int connectivity: 0
    property string portalUrl: ""

    property string editingNet: ""
    property string wrongNet: ""
    property string passwordText: ""
    property bool showPassword: false

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
    readonly property string eyeGlyph: "\u{f0208}"
    readonly property string eyeOffGlyph: "\u{f0209}"

    function netKey(net): string {
        return (net.name || "") + "|" + (net.address || "");
    }

    function needsPassword(net): bool {
        var s = net.security;
        return s !== WifiSecurityType.Open
            && s !== WifiSecurityType.Owe
            && s !== WifiSecurityType.Unknown;
    }

    function bars(signal): int {
        var s = Math.max(0, Math.min(1, signal || 0));
        return Math.max(1, Math.min(4, Math.ceil(s * 4)));
    }

    function glyphFor(net, barsCount, conn): string {
        var n = barsCount - 1;
        if (!net.connected)
            return section.strengthGlyphs[n];
        if (conn === 2)
            return section.lockGlyphs[n];
        if (conn === 3 || conn === 1)
            return section.alertGlyphs[n];
        return section.strengthGlyphs[n];
    }

    function startEditing(net): void {
        section.editingNet = section.netKey(net);
        section.wrongNet = "";
        section.passwordText = "";
        section.showPassword = false;
    }

    function closeEditing(): void {
        section.editingNet = "";
        section.passwordText = "";
        section.showPassword = false;
    }

    function tryConnect(net, psk): void {
        if (psk.length === 0) return;
        net.connectWithPsk(psk);
        section.passwordText = psk;
    }

    function handleClick(net, secured, editing): void {
        if (net.connected) {
            net.disconnect();
            section.networkSelected();
            return;
        }
        if (editing) return;
        section.networkSelected();
        if (secured)
            section.startEditing(net);
        else
            net.connect();
    }

    function openPortal(): void {
        var url = section.portalUrl.length > 0
            ? section.portalUrl
            : "http://nmcheck.gnome.org/check_network_status.txt";
        Quickshell.execDetached([ "xdg-open", url ]);
    }

    Instantiator {
        model: section.networks
        delegate: Connections {
            required property var modelData
            target: modelData

            function onConnectionFailed(reason): void {
                var key = section.netKey(modelData);
                if (section.editingNet !== key) return;
                if (reason === ConnectionFailReason.WifiNetworkLost) return;
                section.closeEditing();
                section.wrongNet = key;
            }

            function onConnectedChanged(): void {
                var key = section.netKey(modelData);
                if (!modelData.connected) return;
                if (section.editingNet === key) section.closeEditing();
                if (section.wrongNet === key) section.wrongNet = "";
            }
        }
    }

    Text {
        width: parent.width
        height: 18
        visible: section.heading.length > 0
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

            readonly property string key: section.netKey(modelData)
            readonly property bool editing: section.editingNet === key
                && !modelData.connected
            readonly property bool wrong: section.wrongNet === key
            readonly property bool secured: section.needsPassword(modelData)
            readonly property bool onPortal: modelData.connected
                && section.connectivity === 2
            readonly property int sigBars: section.bars(modelData.signalStrength)
            readonly property int sigPercent:
                Math.round((modelData.signalStrength || 0) * 100)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: section.handleClick(modelData, cell.secured, cell.editing)
            }

            Row {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Text {
                    width: 20
                    height: parent.height
                    text: section.glyphFor(modelData, cell.sigBars,
                                           section.connectivity)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: modelData.connected ? section.accentColor : section.fgColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Item {
                    width: parent.width - 28
                        - (cell.editing ? 28 : 0)
                        - (cell.onPortal ? 28 : 0)
                    height: parent.height

                    Column {
                        anchors.fill: parent
                        spacing: 1
                        visible: !cell.editing

                        Text {
                            width: parent.width
                            text: modelData.name || modelData.address
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: section.fgColor
                            elide: Text.ElideRight
                        }

                        Row {
                            width: parent.width
                            spacing: 4

                            Text {
                                id: percentText
                                text: cell.sigPercent + "%"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: section.fgColor
                                opacity: 0.6
                            }

                            Text {
                                width: cell.wrong
                                    ? parent.width - percentText.width - parent.spacing
                                    : 0
                                visible: cell.wrong
                                text: "wrong password"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 9
                                color: section.accentColor
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideLeft
                            }
                        }
                    }

                    Item {
                        id: editor
                        anchors.fill: parent
                        visible: cell.editing

                        Text {
                            anchors.fill: parent
                            visible: passwordInput.text.length === 0
                            text: (modelData.name || modelData.address) + " password"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            color: section.fgColor
                            opacity: 0.5
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        TextInput {
                            id: passwordInput
                            anchors.fill: parent
                            focus: false
                            echoMode: section.showPassword
                                ? TextInput.Normal : TextInput.Password
                            selectByMouse: true
                            clip: true
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: section.fgColor
                            selectionColor: section.accentColor
                            selectedTextColor: section.bgColor
                            verticalAlignment: TextInput.AlignVCenter
                            activeFocusOnPress: true

                            onTextEdited: section.passwordText = text
                            onAccepted: section.tryConnect(modelData, text)
                            Keys.onEscapePressed: section.closeEditing()
                        }

                        Connections {
                            target: cell
                            function onEditingChanged(): void {
                                if (cell.editing) {
                                    passwordInput.text = section.passwordText;
                                    passwordInput.forceActiveFocus();
                                    passwordInput.cursorPosition =
                                        passwordInput.text.length;
                                } else {
                                    passwordInput.text = "";
                                }
                            }
                        }

                        Component.onCompleted: {
                            if (cell.editing) {
                                passwordInput.text = section.passwordText;
                                passwordInput.forceActiveFocus();
                                passwordInput.cursorPosition =
                                    passwordInput.text.length;
                            }
                        }
                    }
                }

                Rectangle {
                    id: eyeButton
                    width: 20
                    height: parent.height
                    visible: cell.editing
                    color: "transparent"
                    border.width: 1
                    border.color: section.showPassword
                        ? section.accentColor : section.borderColor

                    Text {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        text: section.showPassword
                            ? section.eyeOffGlyph : section.eyeGlyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: section.showPassword
                            ? section.accentColor : section.fgColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: section.showPassword = !section.showPassword
                    }
                }

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
