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
    // Инверсивно-акцентный цвет: тёмный значок на акцентном фоне (как nix в баре).
    property color inverseAccentColor: "#132f60"
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

    property real uptimeSeconds: 0
    readonly property int uptimeHours: Math.floor(uptimeSeconds / 3600)
    readonly property int uptimeMinutes: Math.floor((uptimeSeconds % 3600) / 60)

    property int cpuLoad: 0
    property int gpuLoad: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property real memUsedGb: 0
    property real memTotalGb: 0
    property bool hasBattery: false
    property int batteryPercent: 0
    property real batteryHours: -1

    property int netUpSpeed: 0
    property int netDownSpeed: 0
    property var netUpHistory: []
    property var netDownHistory: []
    property int netRevision: 0

    readonly property string powerGlyph: "\u{f0425}"
    readonly property string rebootGlyph: "\u{f0709}"
    readonly property string suspendGlyph: "\u{f0904}"
    readonly property string logoutGlyph: "\u{f0343}"
    readonly property string lockGlyph: "\uf023"
    readonly property string userGlyph: "\uf007"
    readonly property string cpuGlyph: "\u{f4bc}"
    readonly property string memoryGlyph: "\u{efc5}"
    readonly property string gpuGlyph: "\u{f108}"
    readonly property string upGlyph: "\uf062"
    readonly property string downGlyph: "\uf063"
    readonly property string wifiGlyph: "\uf1eb"
    readonly property string batteryGlyph: "\uf240"

    readonly property var actions: [
        { glyph: lockGlyph, command: [ "hyprlock" ] },
        { glyph: powerGlyph, command: [ "systemctl", "poweroff" ] },
        { glyph: rebootGlyph, command: [ "systemctl", "reboot" ] },
        { glyph: suspendGlyph, command: [ "systemctl", "suspend" ] },
        { glyph: logoutGlyph, command: [ "niri", "msg", "action", "quit" ] }
    ]

    function formatSpeed(bytes: int): string {
        if (bytes < 1024) return bytes + "B/s";
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + "K/s";
        return (bytes / 1048576).toFixed(1) + "M/s";
    }

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

    Timer {
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            uptimeProc.running = false;
            uptimeProc.running = true;
        }
    }

    Process {
        id: uptimeProc
        command: [ "cat", "/proc/uptime" ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var seconds = parseFloat(this.text);
                if (!isNaN(seconds))
                    panel.uptimeSeconds = seconds;
            }
        }
    }

    // Ноут или ПК: наличие батареи меняет раскладку кругов.
    Process {
        running: true
        command: [
            "sh", "-c",
            "for b in /sys/class/power_supply/*; do "
            + "[ \"$(cat \"$b/type\" 2>/dev/null)\" = Battery ] && "
            + "{ printf 1; exit; }; done"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: panel.hasBattery = this.text.trim() === "1"
        }
    }

    Timer {
        interval: 2500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            statsProc.running = false;
            statsProc.running = true;
        }
    }

    Process {
        id: statsProc
        command: [
            "sh", "-c",
            "cpu_sample() { awk '/^cpu /{t=0; for(i=2;i<=NF;i++)t+=$i; "
            + "printf \"%d %d\\n\", t, $5+$6}' /proc/stat; }; "
            + "cpu_temp() { for z in /sys/class/thermal/thermal_zone*; do "
            + "[ \"$(cat \"$z/type\" 2>/dev/null)\" = x86_pkg_temp ] && "
            + "{ echo $(( $(cat \"$z/temp\" 2>/dev/null) / 1000 )); return; }; done; "
            + "for h in /sys/class/hwmon/hwmon*; do "
            + "[ \"$(cat \"$h/name\" 2>/dev/null)\" = coretemp ] && "
            + "[ -f \"$h/temp1_input\" ] && "
            + "{ echo $(( $(cat \"$h/temp1_input\") / 1000 )); return; }; done; echo 0; }; "
            + "gpu_temp() { if command -v nvidia-smi >/dev/null 2>&1; then "
            + "t=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits "
            + "2>/dev/null | head -1); "
            + "[ -n \"$t\" ] && { echo \"$t\"; return; }; fi; "
            + "for h in /sys/class/hwmon/hwmon*; do "
            + "case \"$(cat \"$h/name\" 2>/dev/null)\" in "
            + "amdgpu|i915) [ -f \"$h/temp1_input\" ] && "
            + "{ echo $(( $(cat \"$h/temp1_input\") / 1000 )); return; };; "
            + "esac; done; cpu_temp; }; "
            + "iface=$(awk 'NR>1 && $2==\"00000000\" {print $1; exit}' /proc/net/route); "
            + "if [ -z \"$iface\" ]; then for n in /sys/class/net/*; do "
            + "b=${n##*/}; [ \"$b\" = lo ] && continue; "
            + "[ \"$(cat \"$n/operstate\" 2>/dev/null)\" = up ] && { iface=\"$b\"; break; }; "
            + "done; fi; "
            + "gpu_path=/sys/class/drm/card1/gt/gt0/rc6_residency_ms; "
            + "[ -f \"$gpu_path\" ] || gpu_path=/sys/class/drm/card0/gt/gt0/rc6_residency_ms; "
            + "bat_path=; for b in /sys/class/power_supply/*; do "
            + "[ \"$(cat \"$b/type\" 2>/dev/null)\" = Battery ] && "
            + "{ bat_path=\"$b\"; break; }; done; "
            + "bat_status=$(cat \"$bat_path/status\" 2>/dev/null); "
            + "bat_charge0=$(cat \"$bat_path/charge_now\" 2>/dev/null || echo 0); "
            + "bat_cur=$(awk -F= '/^POWER_SUPPLY_CURRENT_NOW=/{print $2}' "
            + "\"$bat_path/uevent\" 2>/dev/null); "
            + "[ -z \"$bat_cur\" ] && bat_cur=0; "
            + "[ \"$bat_cur\" -lt 0 ] && bat_cur=$((0 - bat_cur)); "
            + "c0=$(cpu_sample); r0=$(cat \"$gpu_path\" 2>/dev/null || echo 0); "
            + "rx0=$(cat \"/sys/class/net/$iface/statistics/rx_bytes\" 2>/dev/null || echo 0); "
            + "tx0=$(cat \"/sys/class/net/$iface/statistics/tx_bytes\" 2>/dev/null || echo 0); "
            + "sleep 1; "
            + "bat_charge1=$(cat \"$bat_path/charge_now\" 2>/dev/null || echo 0); "
            + "bat_delta=$(( (bat_charge0 - bat_charge1) * 3600 )); "
            + "[ \"$bat_status\" = Discharging ] && [ \"$bat_delta\" -gt 0 ] "
            + "&& bat_cur=$bat_delta; "
            + "bat_hours=-1; "
            + "[ \"$bat_cur\" -gt 0 ] && [ \"$bat_charge1\" -gt 0 ] "
            + "&& bat_hours=$(awk -v c=\"$bat_charge1\" -v i=\"$bat_cur\" "
            + "'BEGIN{printf \"%.1f\", c/i}'); "
            + "c1=$(cpu_sample); r1=$(cat \"$gpu_path\" 2>/dev/null || echo 0); "
            + "rx1=$(cat \"/sys/class/net/$iface/statistics/rx_bytes\" 2>/dev/null || echo 0); "
            + "tx1=$(cat \"/sys/class/net/$iface/statistics/tx_bytes\" 2>/dev/null || echo 0); "
            + "down=$((rx1-rx0)); up=$((tx1-tx0)); "
            + "[ \"$down\" -lt 0 ] && down=0; [ \"$up\" -lt 0 ] && up=0; "
            + "ct=$(cpu_temp); gt=$(gpu_temp); "
            + "bat=$(for b in /sys/class/power_supply/*; do "
            + "[ \"$(cat \"$b/type\" 2>/dev/null)\" = Battery ] && "
            + "{ cat \"$b/capacity\" 2>/dev/null; exit; }; done); "
            + "[ -z \"$bat\" ] && bat=0; "
            + "mem=$(awk '/MemTotal:/{t=$2} /MemAvailable:/{a=$2} "
            + "END{if(t>0)printf \"%.1f %.1f\",(t-a)/1048576,t/1048576; "
            + "else print \"0 0\"}' /proc/meminfo); "
            + "nv=$(command -v nvidia-smi >/dev/null 2>&1 && "
            + "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits "
            + "2>/dev/null | head -1); "
            + "awk -v c0=\"$c0\" -v c1=\"$c1\" -v r0=\"$r0\" -v r1=\"$r1\" "
            + "-v m=\"$mem\" -v nv=\"$nv\" -v ct=\"$ct\" -v gt=\"$gt\" "
            + "-v dn=\"$down\" -v up=\"$up\" -v bat=\"$bat\" -v bh=\"$bat_hours\" 'BEGIN{ "
            + "split(c0,a); split(c1,b); split(m,mm); "
            + "dt=b[1]-a[1]; idle=b[2]-a[2]; "
            + "cpu=(dt>0)?(dt-idle)*100/dt:0; gpu=-1; "
            + "if(nv!=\"\") gpu=nv; "
            + "else if(r0!=\"\" && r1!=\"\") { d=r1-r0; if(d<0)d=0; "
            + "gpu=(d>1000)?0:100-d/10; } "
            + "printf \"%d %d %s %d %d %d %d %d %s\\n\", "
            + "cpu, ct, m, (gpu<0?0:gpu), gt, dn, up, bat+0, bh }'"
        ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/);
                if (parts.length >= 10) {
                    panel.cpuLoad = Number(parts[0]);
                    panel.cpuTemp = Number(parts[1]);
                    panel.memUsedGb = Number(parts[2]);
                    panel.memTotalGb = Number(parts[3]);
                    panel.gpuLoad = Number(parts[4]);
                    panel.gpuTemp = Number(parts[5]);
                    panel.netDownSpeed = Number(parts[6]);
                    panel.netUpSpeed = Number(parts[7]);
                    panel.batteryPercent = Number(parts[8]);
                    panel.batteryHours = Number(parts[9]);

                    var down = panel.netDownHistory;
                    down.push(panel.netDownSpeed);
                    if (down.length > 24) down.shift();
                    panel.netDownHistory = down;

                    var up = panel.netUpHistory;
                    up.push(panel.netUpSpeed);
                    if (up.length > 24) up.shift();
                    panel.netUpHistory = up;

                    panel.netRevision++;
                }
            }
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
                anchors.fill: parent

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
                    font.pixelSize: 18
                    color: panel.fgColor
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    id: uptimeText
                    anchors {
                        left: userNameText.left
                        right: userNameText.right
                        top: userNameText.bottom
                        topMargin: 2
                    }
                    text: panel.uptimeHours > 0
                        ? "Uptime:\n" + panel.uptimeHours + " hours "
                          + panel.uptimeMinutes + " minutes"
                        : "Uptime:\n" + panel.uptimeMinutes + " minutes"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: Qt.rgba(panel.fgColor.r, panel.fgColor.g, panel.fgColor.b, 0.55)
                    elide: Text.ElideRight
                }

                Row {
                    id: buttons
                    anchors {
                        top: avatarBox.bottom
                        topMargin: 12
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

                Item {
                    id: statsArea
                    anchors {
                        top: buttons.bottom
                        topMargin: 12
                        left: parent.left
                        leftMargin: 12
                        right: parent.right
                        rightMargin: 12
                    }
                    height: 128

                    Repeater {
                        model: panel.hasBattery
                            ? [
                                { kind: "cpu", glyph: panel.cpuGlyph, label: "CPU" },
                                { kind: "network", glyph: panel.wifiGlyph, label: "Network" },
                                { kind: "memory", glyph: panel.memoryGlyph, label: "Memory" },
                                { kind: "battery", glyph: panel.batteryGlyph, label: "Battery" },
                                { kind: "gpu", glyph: panel.gpuGlyph, label: "GPU" }
                              ]
                            : [
                                { kind: "cpu", glyph: panel.cpuGlyph, label: "CPU" },
                                { kind: "memory", glyph: panel.memoryGlyph, label: "Memory" },
                                { kind: "gpu", glyph: panel.gpuGlyph, label: "GPU" },
                                { kind: "network", glyph: panel.wifiGlyph, label: "Network" }
                              ]

                        delegate: Item {
                            id: statRow
                            width: 144
                            height: 40

                            anchors {
                                left: parent.left
                                leftMargin: panel.hasBattery
                                    ? (modelData.kind === "network"
                                        || modelData.kind === "battery" ? 164 : 0)
                                    : (index % 2 === 0 ? 0 : 164)
                                top: parent.top
                                topMargin: panel.hasBattery
                                    ? (modelData.kind === "cpu" ? 0
                                        : modelData.kind === "network" ? 0
                                        : modelData.kind === "memory" ? 44
                                        : modelData.kind === "battery" ? 44 : 88)
                                    : (index < 2 ? 0 : 48)
                            }

                            property bool isNetwork: modelData.kind === "network"
                            property int statValue: modelData.kind === "cpu" ? panel.cpuLoad
                                : modelData.kind === "memory"
                                    ? Math.round(100 * panel.memUsedGb
                                        / Math.max(1, panel.memTotalGb))
                                    : modelData.kind === "gpu" ? panel.gpuLoad
                                    : panel.batteryPercent
                            property int statTemp: modelData.kind === "cpu" ? panel.cpuTemp
                                : modelData.kind === "gpu" ? panel.gpuTemp : 0
                            property string statText: modelData.kind === "memory"
                                ? panel.memUsedGb.toFixed(1) + " GB/"
                                  + panel.memTotalGb.toFixed(1) + " GB"
                                : modelData.kind === "battery"
                                    ? statValue + "%"
                                      + (panel.batteryHours >= 0
                                        ? " " + panel.batteryHours.toFixed(1) + " h" : "")
                                    : statValue + "% " + statTemp + "\u00b0C"

                            onStatValueChanged: ring.requestPaint()

                            Canvas {
                                id: ring
                                width: 40
                                height: 40
                                antialiasing: true

                                property int revision: panel.netRevision
                                onRevisionChanged: ring.requestPaint()

                                onPaint: {
                                    var ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.lineWidth = 4;
                                    var bg = Qt.rgba(panel.fgColor.r,
                                        panel.fgColor.g, panel.fgColor.b, 0.18);

                                    if (statRow.isNetwork) {
                                        // Вырезы: сверху справа и снизу слева.
                                        // Верхняя дуга — входящий трафик, нижняя — исходящий.
                                        var gap = Math.PI / 12;
                                        var topRight = -Math.PI / 4;
                                        var bottomLeft = topRight + Math.PI;
                                        var topStart = bottomLeft + gap;
                                        var topSpan = topRight + 2 * Math.PI - gap - topStart;
                                        var bottomStart = topRight + gap;
                                        var bottomSpan = bottomLeft - gap - bottomStart;

                                        var max = 1024;
                                        var values = panel.netDownHistory;
                                        for (var i = 0; i < values.length; i++)
                                            if (values[i] > max) max = values[i];
                                        values = panel.netUpHistory;
                                        for (var j = 0; j < values.length; j++)
                                            if (values[j] > max) max = values[j];

                                        // Тёмная полоска растёт от левого нижнего
                                        // края вправо (к верхнему правому вырезу).
                                        var upFraction = Math.min(1, panel.netUpSpeed / max);
                                        ctx.strokeStyle = bg;
                                        ctx.beginPath();
                                        ctx.arc(20, 20, 16, bottomStart,
                                                bottomStart + bottomSpan);
                                        ctx.stroke();
                                        ctx.strokeStyle = panel.inverseAccentColor;
                                        ctx.beginPath();
                                        ctx.arc(20, 20, 16,
                                                bottomStart + bottomSpan * (1 - upFraction),
                                                bottomStart + bottomSpan);
                                        ctx.stroke();

                                        ctx.strokeStyle = bg;
                                        ctx.beginPath();
                                        ctx.arc(20, 20, 16, topStart, topStart + topSpan);
                                        ctx.stroke();
                                        ctx.strokeStyle = panel.accentColor;
                                        ctx.beginPath();
                                        ctx.arc(20, 20, 16, topStart,
                                                topStart + topSpan
                                                * Math.min(1, panel.netDownSpeed / max));
                                        ctx.stroke();
                                    } else {
                                        // Разрез сверху справа (30°, как у Wi-Fi),
                                        // дуга идёт вниз.
                                        var gap = Math.PI / 12;
                                        var start = -Math.PI / 4 + gap;
                                        var span = 2 * Math.PI - 2 * gap;
                                        ctx.strokeStyle = bg;
                                        ctx.beginPath();
                                        ctx.arc(20, 20, 16, start, start + span);
                                        ctx.stroke();
                                        ctx.strokeStyle = panel.accentColor;
                                        ctx.beginPath();
                                        ctx.arc(20, 20, 16, start,
                                                start + span
                                                * Math.min(1, statRow.statValue / 100));
                                        ctx.stroke();
                                    }
                                }

                                Component.onCompleted: ring.requestPaint()

                                Connections {
                                    target: panel
                                    function onInverseAccentColorChanged(): void { ring.requestPaint() }
                                    function onAccentColorChanged(): void { ring.requestPaint() }
                                    function onFgColorChanged(): void { ring.requestPaint() }
                                }
                            }

                            Text {
                                anchors.centerIn: ring
                                text: modelData.glyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: panel.fgColor
                            }

                            Column {
                                visible: statRow.isNetwork
                                anchors {
                                    left: ring.right
                                    leftMargin: 8
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: 2

                                Row {
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: panel.downGlyph
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: panel.accentColor
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: panel.formatSpeed(panel.netDownSpeed)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: panel.fgColor
                                    }
                                }

                                Row {
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: panel.upGlyph
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        color: panel.inverseAccentColor
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: panel.formatSpeed(panel.netUpSpeed)
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: panel.fgColor
                                    }
                                }
                            }

                            Column {
                                visible: !statRow.isNetwork
                                anchors {
                                    left: ring.right
                                    leftMargin: 8
                                    top: parent.top
                                    topMargin: 1
                                }

                                Text {
                                    text: statRow.statText
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 12
                                    color: panel.fgColor
                                }

                                Text {
                                    text: modelData.label
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    color: Qt.rgba(panel.fgColor.r, panel.fgColor.g,
                                                   panel.fgColor.b, 0.55)
                                }
                            }
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
