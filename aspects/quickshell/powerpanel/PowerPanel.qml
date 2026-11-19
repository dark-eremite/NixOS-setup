import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs

PanelWindow {
    id: panel

    anchors {
        top: true
        right: true
        bottom: true
    }
    margins {
        top: 8 + panel.topInset
        // The window reaches past the right edge of the screen, so the body can
        // slide in from the side instead of the window itself being moved.
        right: 12 - panel.travel
        bottom: 8
    }
    implicitWidth: panel.bodyWidth + panel.travel
    color: "transparent"
    surfaceFormat.opaque: false

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    property real topInset: 0

    // Width of the visible panel body (without the sliding space next to it).
    property int bodyWidth: 320
    // Distance the body travels: resting position -> fully off-screen (right).
    readonly property int travel: bodyWidth + 12

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    onClosed: shown = false

    property bool shown: false
    property bool slidingOut: false
    // Offset of the body inside the window: 0 = resting position,
    // travel = fully off-screen to the right.
    property real slide: travel

    visible: shown || slidingOut

    property string avatarPath: ""
    readonly property string userName: Quickshell.env("USER")

    readonly property string powerGlyph: "\u{f0425}"
    readonly property string rebootGlyph: "\u{f0709}"
    readonly property string suspendGlyph: "\u{f0904}"
    readonly property string logoutGlyph: "\u{f0343}"
    readonly property string userGlyph: "\uf007"

    readonly property var actions: [
        { glyph: powerGlyph, command: [ "systemctl", "poweroff" ] },
        { glyph: rebootGlyph, command: [ "systemctl", "reboot" ] },
        { glyph: suspendGlyph, command: [ "systemctl", "suspend" ] },
        { glyph: logoutGlyph, command: [ "niri", "msg", "action", "quit" ] }
    ]

    function toggle(): void { shown = !shown; }

    // Notification history is a section of this panel, not a separate window.
    property bool historyShown: false
    property bool clipboardShown: false
    property bool colorPickerShown: false
    property bool portsShown: false
    readonly property bool notificationsEnabled: notificationHistory.notificationsEnabled

    function toggleHistory(): void {
        panel.closeTrayMenu();
        if (!historyShown) {
            clipboardShown = false;
            colorPickerShown = false;
            portsShown = false;
        }
        historyShown = !historyShown;
    }

    function toggleClipboard(): void {
        panel.closeTrayMenu();
        if (!clipboardShown) {
            historyShown = false;
            colorPickerShown = false;
            portsShown = false;
        }
        clipboardShown = !clipboardShown;
    }

    function toggleColorPicker(): void {
        panel.closeTrayMenu();
        if (!colorPickerShown) {
            historyShown = false;
            clipboardShown = false;
            portsShown = false;
        }
        colorPickerShown = !colorPickerShown;
    }

    function togglePorts(): void {
        panel.closeTrayMenu();
        if (!portsShown) {
            historyShown = false;
            clipboardShown = false;
            colorPickerShown = false;
        }
        portsShown = !portsShown;
    }

    // The bottom block doubles as a system tray: the four built-in actions
    // and registered SNI apps share one grid of 6 columns, up to 4 rows.
    readonly property int trayColumns: 6
    readonly property int trayRowsMax: 4
    readonly property int trayCellHeight: 36
    readonly property int trayCapacity: trayColumns * trayRowsMax

    readonly property var fixedTrayActions: [
        { glyph: "\u{f009e}", action: "notifications" },
        { glyph: "\uf0c5", action: "clipboard" },
        { glyph: "\uf1fb", action: "colorpicker" },
        { glyph: "\uf233", action: "ports" }
    ]

    property var trayModel: []
    property var activeTrayItem: null
    property var trayMenuHandle: null
    property bool trayMenuOpen: false

    function rebuildTrayModel(): void {
        var list = [];
        for (var i = 0; i < panel.fixedTrayActions.length; i++)
            list.push({ action: panel.fixedTrayActions[i] });

        var items = SystemTray.items ? SystemTray.items.values : [];
        for (var j = 0; j < items.length && list.length < panel.trayCapacity; j++)
            list.push({ trayItem: items[j] });

        panel.trayModel = list;
    }

    function closeTrayMenu(): void {
        panel.trayMenuOpen = false;
        panel.trayMenuHandle = null;
        panel.activeTrayItem = null;
    }

    function showTrayMenu(item): void {
        if (!item || !item.hasMenu) {
            panel.closeTrayMenu();
            return;
        }
        if (panel.activeTrayItem === item && panel.trayMenuOpen) {
            panel.closeTrayMenu();
            return;
        }
        panel.historyShown = false;
        panel.clipboardShown = false;
        panel.colorPickerShown = false;
        panel.portsShown = false;
        panel.activeTrayItem = item;
        panel.trayMenuHandle = item.menu;
        panel.trayMenuOpen = true;
    }

    function activateFixedAction(action: string): void {
        if (action === "notifications") panel.toggleHistory();
        else if (action === "clipboard") panel.toggleClipboard();
        else if (action === "colorpicker") panel.toggleColorPicker();
        else if (action === "ports") panel.togglePorts();
    }

    Component.onCompleted: panel.rebuildTrayModel()

    Connections {
        target: SystemTray.items
        function onValuesChanged(): void { panel.rebuildTrayModel(); }
    }

    Connections {
        target: panel.activeTrayItem
        function onHasMenuChanged(): void {
            if (!panel.activeTrayItem || !panel.activeTrayItem.hasMenu)
                panel.closeTrayMenu();
        }
    }

    onHistoryShownChanged: {
        if (historyShown) {
            clipboardShown = false;
            colorPickerShown = false;
            portsShown = false;
            notificationHistory.reloadHistory();
        }
    }

    onClipboardShownChanged: {
        if (clipboardShown) {
            historyShown = false;
            colorPickerShown = false;
            portsShown = false;
            clipboardHistory.reloadHistory();
        }
    }

    onColorPickerShownChanged: {
        if (colorPickerShown) {
            historyShown = false;
            clipboardShown = false;
            portsShown = false;
        }
    }

    onPortsShownChanged: {
        if (portsShown) {
            historyShown = false;
            clipboardShown = false;
            colorPickerShown = false;
            portsPanel.reloadPorts();
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void { panel.toggle(); }
        function open(): void { panel.shown = true; }
        function close(): void { panel.shown = false; }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            panel.shown = true;
            panel.historyShown = !panel.historyShown;
        }
        function open(): void {
            panel.shown = true;
            panel.historyShown = true;
        }
        function close(): void { panel.historyShown = false; }
        function clear(): void { notificationHistory.clearHistory(); }
        function toggleEnabled(): void { notificationHistory.toggleNotifications(); }
    }

    signal screenPickRequested()

    function applyPickedColor(hex: string): void {
        var h = String(hex || "").toUpperCase();
        if (h.length > 0) {
            colorPickerPanel.setFromHex(h);
            pickCopyProc.command = [
                "sh", "-c", "printf '%s' \"$1\" | wl-copy", "--", h
            ];
            pickCopyProc.running = false;
            pickCopyProc.running = true;
        }
        panel.historyShown = false;
        panel.clipboardShown = false;
        panel.portsShown = false;
        panel.colorPickerShown = true;
        panel.shown = true;
    }

    Process {
        id: pickCopyProc
    }

    Process {
        running: true
        command: [
            "sh", "-c",
            "for f in \"$HOME\"/.face/*; do "
            + "case \"$f\" in *.jpg|*.jpeg|*.png|*.webp|*.bmp) printf '%s' \"$f\"; break;; esac; "
            + "done"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: panel.avatarPath = this.text.trim()
        }
    }

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
            slide = travel;
            slide = 0;
        } else {
            slidingOut = true;
            slide = travel;
            historyShown = false;
            clipboardShown = false;
            colorPickerShown = false;
            portsShown = false;
            panel.closeTrayMenu();
            hideTimer.restart();
        }
    }

    // Only the body moves; the window keeps a fixed position, because
    // layer-shell margins are applied by the compositor on surface commit.
    Item {
        id: body
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        width: panel.bodyWidth
        transform: Translate { x: panel.slide }

        Item {
            id: topBlock
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: width

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: panel.borderColor
            }

            Item {
                id: headerBlock
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent.height - buttons.height

                Item {
                    id: avatarBox
                    width: 104
                    height: 104
                    anchors {
                        top: parent.top
                        left: parent.left
                        topMargin: 12
                        leftMargin: 12
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(panel.fgColor.r, panel.fgColor.g, panel.fgColor.b, 0.08)
                    }

                    Image {
                        id: avatar
                        anchors.fill: parent
                        source: panel.avatarPath.length > 0 ? "file://" + panel.avatarPath : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        visible: status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !avatar.visible
                        text: panel.userGlyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 48
                        color: panel.fgColor
                        opacity: 0.55
                    }
                }

                Text {
                    id: userNameText
                    anchors {
                        left: avatarBox.right
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                        top: avatarBox.top
                    }
                    text: panel.userName
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: panel.fgColor
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Row {
                id: buttons
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 40
                spacing: 0

                Repeater {
                    model: panel.actions

                    delegate: Item {
                        width: buttons.width / panel.actions.length
                        height: buttons.height

                        property bool hovered: false

                        Rectangle {
                            anchors.fill: parent
                            color: parent.hovered
                                ? Qt.rgba(panel.accentColor.r, panel.accentColor.g,
                                          panel.accentColor.b, 0.12)
                                : "transparent"
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.glyph
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 20
                            color: parent.hovered ? panel.accentColor : panel.fgColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                            onClicked: Quickshell.execDetached(modelData.command)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: bottomBlock
            anchors {
                top: topBlock.bottom
                topMargin: 8
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.92)
            border.width: 2
            border.color: panel.borderColor

            Item {
                id: bottomContent
                anchors {
                    fill: parent
                    margins: 6
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: panel.closeTrayMenu()
                }

                Grid {
                    id: trayGrid
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    columns: panel.trayColumns
                    columnSpacing: 0
                    rowSpacing: 0
                    height: Math.ceil(panel.trayModel.length / panel.trayColumns)
                        * panel.trayCellHeight
                    z: 1

                    Repeater {
                        model: panel.trayModel

                        delegate: Item {
                            id: cell
                            width: trayGrid.width / panel.trayColumns
                            height: panel.trayCellHeight

                            property var trayItem: modelData.trayItem || null
                            property var action: modelData.action || null
                            property bool hovered: false
                            property bool needsAttention: cell.trayItem
                                && cell.trayItem.status === Status.NeedsAttention
                            property bool active: cell.action && (
                                (cell.action.action === "notifications" && panel.historyShown)
                                || (cell.action.action === "clipboard" && panel.clipboardShown)
                                || (cell.action.action === "colorpicker" && panel.colorPickerShown)
                                || (cell.action.action === "ports" && panel.portsShown)
                            )

                            Rectangle {
                                anchors.fill: parent
                                color: parent.hovered || parent.active
                                    ? Qt.rgba(panel.accentColor.r, panel.accentColor.g,
                                              panel.accentColor.b, 0.12)
                                    : "transparent"
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: parent.needsAttention ? 2 : 0
                                border.color: panel.accentColor
                            }

                            Image {
                                id: trayIcon
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: cell.trayItem ? cell.trayItem.icon : ""
                                sourceSize.width: 20
                                sourceSize.height: 20
                                fillMode: Image.PreserveAspectFit
                                visible: cell.trayItem && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: cell.trayItem
                                    ? (cell.trayItem.title
                                        ? cell.trayItem.title.charAt(0).toUpperCase()
                                        : "\uf108")
                                    : cell.action.glyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: cell.trayItem ? 14 : 20
                                color: parent.hovered || parent.active
                                    ? panel.accentColor : panel.fgColor
                                visible: !cell.trayItem || trayIcon.status !== Image.Ready
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onEntered: cell.hovered = true
                                onExited: cell.hovered = false
                                onPressed: function (mouse) {
                                    if (cell.trayItem) {
                                        if (mouse.button === Qt.RightButton
                                            || cell.trayItem.onlyMenu)
                                            panel.showTrayMenu(cell.trayItem);
                                        else if (mouse.button === Qt.MiddleButton)
                                            cell.trayItem.secondaryActivate();
                                        else {
                                            panel.closeTrayMenu();
                                            cell.trayItem.activate();
                                        }
                                    } else if (cell.action) {
                                        panel.activateFixedAction(cell.action.action);
                                    }
                                }
                            }
                        }
                    }
                }

                TrayMenu {
                    id: trayMenu
                    anchors {
                        top: trayGrid.bottom
                        topMargin: 8
                        left: parent.left
                        right: parent.right
                    }
                    z: 5
                    visible: panel.trayMenuOpen && !!panel.trayMenuHandle
                    open: panel.trayMenuOpen
                    rootHandle: panel.trayMenuHandle
                    bgColor: panel.bgColor
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                    onDismissRequested: panel.closeTrayMenu()
                }

                NotificationHistoryPanel {
                    id: notificationHistory
                    anchors {
                        top: trayGrid.bottom
                        topMargin: trayMenu.visible ? trayMenu.height + 16 : 8
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: panel.historyShown

                    bgColor: panel.bgColor
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                }

                ClipboardHistoryPanel {
                    id: clipboardHistory
                    anchors {
                        top: trayGrid.bottom
                        topMargin: trayMenu.visible ? trayMenu.height + 16 : 8
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: panel.clipboardShown

                    bgColor: panel.bgColor
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                }

                ColorPickerPanel {
                    id: colorPickerPanel
                    anchors {
                        top: trayGrid.bottom
                        topMargin: trayMenu.visible ? trayMenu.height + 16 : 8
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: panel.colorPickerShown

                    bgColor: panel.bgColor
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor

                    onRequestScreenPick: {
                        panel.shown = false;
                        panel.screenPickRequested();
                    }
                }

                PortsPanel {
                    id: portsPanel
                    anchors {
                        top: trayGrid.bottom
                        topMargin: trayMenu.visible ? trayMenu.height + 16 : 8
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    visible: panel.portsShown

                    bgColor: panel.bgColor
                    fgColor: panel.fgColor
                    accentColor: panel.accentColor
                    borderColor: panel.borderColor
                }
            }
        }
    }
}
