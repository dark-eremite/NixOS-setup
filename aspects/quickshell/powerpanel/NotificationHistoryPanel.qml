import QtQuick
import Quickshell
import Quickshell.Io

// History view embedded into PowerPanel. It is a plain Item, not a window:
// PowerPanel owns the window and decides when this section is visible.
Item {
    id: history

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

    property bool notificationsEnabled: true

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
                timeLabel: history.formatTime(entry.time),
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
        if (history.notificationsEnabled === enabled)
            return;
        history.notificationsEnabled = enabled;
        stateProc.command = [
            "sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "--",
            enabled ? "1" : "0", history.statePath
        ];
        stateProc.running = false;
        stateProc.running = true;
    }

    function toggleNotifications(): void {
        history.setNotificationsEnabled(!history.notificationsEnabled);
    }

    FileView {
        id: historyFile
        path: history.historyPath
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: history.reloadHistory()
        onFileChanged: historyFile.reload()
        onLoadFailed: historyModel.clear()
    }

    FileView {
        id: stateFile
        path: history.statePath
        watchChanges: true
        preload: true
        blockLoading: true
        printErrors: false
        onLoaded: history.notificationsEnabled = (this.text().trim() !== "0")
        onFileChanged: stateFile.reload()
        onLoadFailed: history.notificationsEnabled = true
    }

    Process {
        id: clearProc
        command: [ "sh", "-c", ": > \"$1\"", "--", history.historyPath ]
    }

    Process {
        id: stateProc
        command: [ "sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "--", "1", history.statePath ]
    }

    ListModel {
        id: historyModel
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(history.bgColor.r, history.bgColor.g,
                       history.bgColor.b, 0.92)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: history.borderColor
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
                color: history.fgColor
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: clearButton
                width: 26
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: history.borderColor

                Text {
                    anchors.centerIn: parent
                    text: history.broomGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: history.fgColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: history.clearHistory()
                }
            }

            Rectangle {
                id: enableButton
                width: 26
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: history.notificationsEnabled
                    ? history.accentColor : history.borderColor

                Text {
                    anchors.centerIn: parent
                    text: history.notificationsEnabled
                        ? history.bellOnGlyph : history.bellOffGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: history.notificationsEnabled
                        ? history.accentColor : history.fgColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: history.toggleNotifications()
                }
            }
        }

        Rectangle {
            id: separator
            width: parent.width
            height: 1
            color: history.borderColor
        }

        Item {
            id: listArea
            width: parent.width
            height: Math.max(0, content.height - header.height
                - separator.height - 2 * content.spacing)

            ListView {
                id: list
                anchors.fill: parent
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
                        color: Qt.rgba(history.fgColor.r, history.fgColor.g,
                                       history.fgColor.b, 0.04)
                        border.width: 1
                        border.color: Qt.rgba(history.borderColor.r,
                                              history.borderColor.g,
                                              history.borderColor.b, 0.5)
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
                                color: history.accentColor
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
                                color: history.fgColor
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
                            color: history.fgColor
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
                            color: history.fgColor
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
                color: history.fgColor
                opacity: 0.55
            }
        }
    }
}
