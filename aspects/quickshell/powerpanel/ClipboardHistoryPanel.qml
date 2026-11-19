import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: clipboard

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    readonly property string broomGlyph: "\u{f00e2}"

    readonly property string cacheDirectory: {
        var dir = Quickshell.env("XDG_CACHE_HOME");
        if (!dir || dir.length === 0)
            dir = String(Quickshell.env("HOME")) + "/.cache";
        return dir + "/quickshell";
    }
    readonly property string imageCacheDir: cacheDirectory + "/cliphist"

    function isImagePreview(preview: string): bool {
        return /^\[\[\s*binary data\b.*\]\]$/i.test(preview || "");
    }

    function imagePathFor(id: string): string {
        return imageCacheDir + "/" + id;
    }

    function reloadHistory(): void {
        listProc.running = false;
        listProc.running = true;
    }

    function clearHistory(): void {
        clipboardModel.clear();
        clearProc.command = [
            "sh", "-c",
            "cliphist wipe; rm -rf \"$1\"",
            "--", clipboard.imageCacheDir
        ];
        clearProc.running = false;
        clearProc.running = true;
    }

    function copyEntry(id: string): void {
        copyProc.command = [
            "sh", "-c", "cliphist decode \"$1\" | wl-copy", "--", id
        ];
        copyProc.running = false;
        copyProc.running = true;
    }

    Process {
        id: listProc
        command: [ "cliphist", "list" ]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                var lines = ("" + this.text).split(/\r?\n/);
                clipboardModel.clear();
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i];
                    if (!line || line.length === 0)
                        continue;
                    var tab = line.indexOf("\t");
                    var id = tab >= 0 ? line.slice(0, tab) : line;
                    var preview = tab >= 0 ? line.slice(tab + 1) : "";
                    var image = clipboard.isImagePreview(preview);
                    clipboardModel.append({
                        entryId: String(id),
                        preview: String(preview),
                        isImage: image
                    });
                }
            }
        }
    }

    Process {
        id: clearProc
        command: [ "cliphist", "wipe" ]
        onExited: clipboard.reloadHistory()
    }

    Process {
        id: copyProc
    }

    ListModel {
        id: clipboardModel
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(clipboard.bgColor.r, clipboard.bgColor.g,
                       clipboard.bgColor.b, 0.92)
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: clipboard.borderColor
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
                width: parent.width - parent.spacing - clearButton.width
                height: parent.height
                text: "Clipboard"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: clipboard.fgColor
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                id: clearButton
                width: 26
                height: parent.height
                color: "transparent"
                border.width: 1
                border.color: clipboard.borderColor

                Text {
                    anchors.centerIn: parent
                    text: clipboard.broomGlyph
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: clipboard.fgColor
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: clipboard.clearHistory()
                }
            }
        }

        Rectangle {
            id: separator
            width: parent.width
            height: 1
            color: clipboard.borderColor
        }

        Item {
            id: listArea
            width: parent.width
            height: Math.max(0, content.height - header.height
                - separator.height - 2 * content.spacing)

            ListView {
                id: list
                anchors.fill: parent
                model: clipboardModel
                clip: true
                spacing: 6
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: entryItem
                    width: list.width
                    height: contentColumn.implicitHeight + 16

                    property bool hovered: false
                    property string decodedPath: ""

                    readonly property string targetPath: clipboard.imagePathFor(model.entryId)

                    Component.onCompleted: {
                        if (model.isImage) {
                            decodeProc.command = [
                                "sh", "-c",
                                "mkdir -p \"$1\" && cliphist decode \"$2\" > \"$3\"",
                                "--",
                                clipboard.imageCacheDir,
                                String(model.entryId),
                                entryItem.targetPath
                            ];
                            decodeProc.running = true;
                        }
                    }

                    Process {
                        id: decodeProc
                        onExited: function(exitCode) {
                            if (exitCode === 0)
                                entryItem.decodedPath = entryItem.targetPath;
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: entryItem.hovered
                            ? Qt.rgba(clipboard.accentColor.r, clipboard.accentColor.g,
                                      clipboard.accentColor.b, 0.12)
                            : Qt.rgba(clipboard.fgColor.r, clipboard.fgColor.g,
                                      clipboard.fgColor.b, 0.04)
                        border.width: 1
                        border.color: entryItem.hovered
                            ? clipboard.accentColor
                            : Qt.rgba(clipboard.borderColor.r,
                                      clipboard.borderColor.g,
                                      clipboard.borderColor.b, 0.5)
                    }

                    Column {
                        id: contentColumn
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        spacing: 6

                        Image {
                            id: previewImage
                            visible: model.isImage && status === Image.Ready
                            width: parent.width
                            height: visible && sourceSize.width > 0
                                ? Math.min(width * sourceSize.height / sourceSize.width, 160)
                                : 0
                            source: entryItem.decodedPath.length > 0
                                ? "file://" + entryItem.decodedPath : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            smooth: true
                        }

                        Text {
                            id: previewText
                            width: parent.width
                            visible: !model.isImage || previewImage.status !== Image.Ready
                            text: model.preview.length > 0 ? model.preview : model.entryId
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: clipboard.fgColor
                            wrapMode: Text.Wrap
                            maximumLineCount: model.isImage ? 1 : 3
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: entryItem.hovered = true
                        onExited: entryItem.hovered = false
                        onClicked: clipboard.copyEntry(model.entryId)
                    }
                }
            }

            Text {
                anchors.centerIn: list
                visible: clipboardModel.count === 0
                text: "История буфера обмена пуста"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                color: clipboard.fgColor
                opacity: 0.55
            }
        }
    }
}
