import QtQuick
import Quickshell
import Quickshell.Io

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
    property int bodyWidth: 340
    readonly property int travel: bodyWidth + 12

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    readonly property string broomGlyph: "\u{f00e2}"
    readonly property string bellOnGlyph: "\u{f009e}"
    readonly property string bellOffGlyph: "\u{f009b}"

    readonly property string cacheDirectory: {
        var dir = Quickshell.env("XDG_CACHE_HOME");
        if (!dir || dir.length === 0)
            dir = String(Quickshell.env("HOME")) + "/.cache";
        return dir + "/quickshell";
    }
    readonly property string historyPath: cacheDirectory + "/notifications.jsonl"
    readonly property string statePath: cacheDirectory + "/notifications-enabled"

    property bool shown: false
    property bool slidingOut: false
    property real slide: travel
    property bool notificationsEnabled: true

    visible: shown || slidingOut

    onClosed: shown = false

    function toggle(): void { shown = !shown; }
    function open(): void { shown = true; }
    function close(): void { shown = false; }

    function pad2(n): string {
        return (n < 10 ? "0" : "") + n;
    }

    function formatTime(epoch): string {
        var d = new Date(Number(epoch) * 1000);
        if (isNaN(d.getTime()))
            return "";
        return pad2(d.getDate()) + "." + pad2(d.getMonth() + 1)
            + " " + pad2(d.getHours()) + ":" + pad2(d.getMinutes());
    }

    // The daemon appends newest entries at the end, so the list is rebuilt from
    // the end to keep the newest notification at the top.
    function reloadHistory(): void {
        var lines = historyFile.text().split(/\r?\n/);
        historyModel.clear();
        for (var i = lines.length - 1; i >= 0; i--) {
            var line = lines[i].trim();
            if (line.length === 0)
                continue;
            var entry;
            try {
                entry = JSON.parse(line);
            } catch (e) {
                continue;
            }
            historyModel.append({
                timeLabel: panel.formatTime(entry.time),
                app: String(entry.app || ""),
                summary: String(entry.summary || ""),
                body: String(entry.body || "")
            });
        }
    }

    function clearHistory(): void {
        historyModel.clear();
        clearProc.running = false;
        clearProc.running = true;
    }

    function setNotificationsEnabled(enabled: bool): void {
        if (panel.notificationsEnabled === enabled)
            return;
        panel.notificationsEnabled = enabled;
        stateProc.command = [
            "sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "--",
            enabled ? "1" : "0", panel.statePath
        ];
        stateProc.running = false;
        stateProc.running = true;
    }

    function toggleNotifications(): void {
        panel.setNotificationsEnabled(!panel.notificationsEnabled);
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void { panel.toggle(); }
        function open(): void { panel.open(); }
        function close(): void { panel.close(); }
        function clear(): void { panel.clearHistory(); }
        function toggleEnabled(): void { panel.toggleNotifications(); }
    }

    FileView {
        id: historyFile
        path: panel.historyPath
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: panel.reloadHistory()
        onFileChanged: historyFile.reload()
        onLoadFailed: historyModel.clear()
    }

    FileView {
        id: stateFile
        path: panel.statePath
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: panel.notificationsEnabled = (this.text().trim() !== "0")
        onFileChanged: stateFile.reload()
        onLoadFailed: panel.notificationsEnabled = true
    }

    Process {
        id: clearProc
        command: [ "sh", "-c", ": > \"$1\"", "--", panel.historyPath ]
    }

    Process {
        id: stateProc
        command: [ "sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "--", "1", panel.statePath ]
    }

    ListModel {
        id: historyModel
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
            historyFile.reload();
        } else {
            slidingOut = true;
            slide = travel;
            hideTimer.restart();
        }
    }

    Item {
        id: body
        anchors {
            top: parent.top
            left: parent.left
            bottom: parent.bottom
        }
        width: panel.bodyWidth
        transform: Translate { x: panel.slide }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(panel.bgColor.r, panel.bgColor.g, panel.bgColor.b, 0.92)
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: panel.borderColor
        }

        Column {
            id: content
            anchors {
                fill: parent
                margins: 12
            }
            spacing: 8

            Row {
                id: header
                width: parent.width
                height: 26
                spacing: 8

                Text {
                    id: titleText
                    width: parent.width - 2 * parent.spacing
                        - clearButton.width - enableButton.width
                    height: parent.height
                    text: "Notifications"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    color: panel.fgColor
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    id: clearButton
                    width: 26
                    height: parent.height
                    color: "transparent"
                    border.width: 1
                    border.color: panel.borderColor

                    Text {
                        anchors.centerIn: parent
                        text: panel.broomGlyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: panel.fgColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.clearHistory()
                    }
                }

                Rectangle {
                    id: enableButton
                    width: 26
                    height: parent.height
                    color: "transparent"
                    border.width: 1
                    border.color: panel.notificationsEnabled
                        ? panel.accentColor : panel.borderColor

                    Text {
                        anchors.centerIn: parent
                        text: panel.notificationsEnabled
                            ? panel.bellOnGlyph : panel.bellOffGlyph
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: panel.notificationsEnabled
                            ? panel.accentColor : panel.fgColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.toggleNotifications()
                    }
                }
            }

            Rectangle {
                id: separator
                width: parent.width
                height: 1
                color: panel.borderColor
            }

            ListView {
                id: list
                width: parent.width
                height: content.height - header.height - separator.height
                    - 2 * content.spacing
                model: historyModel
                clip: true
                spacing: 8
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    width: list.width
                    height: 24 + summaryText.height
                        + (bodyText.visible ? bodyText.height + 4 : 0)

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(panel.fgColor.r, panel.fgColor.g,
                                       panel.fgColor.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(panel.borderColor.r,
                                              panel.borderColor.g,
                                              panel.borderColor.b, 0.5)
                    }

                    Column {
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        spacing: 4

                        Row {
                            width: parent.width
                            height: 12

                            Text {
                                id: appText
                                width: parent.width - timeText.width - 8
                                height: parent.height
                                text: model.app
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: panel.accentColor
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: timeText
                                width: implicitWidth
                                height: parent.height
                                text: model.timeLabel
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: panel.fgColor
                                opacity: 0.6
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Text {
                            id: summaryText
                            width: parent.width
                            text: model.summary.length > 0
                                ? model.summary : "Уведомление"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                            color: panel.fgColor
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }

                        Text {
                            id: bodyText
                            width: parent.width
                            visible: model.body.length > 0
                            text: model.body
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: panel.fgColor
                            opacity: 0.85
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: list
                visible: historyModel.count === 0
                text: "История уведомлений пуста"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: panel.fgColor
                opacity: 0.55
            }
        }
    }
}
