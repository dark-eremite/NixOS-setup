import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland

PanelWindow {
    id: popup

    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: -popup.travel
        right: 12
    }
    implicitWidth: popup.bodyWidth
    implicitHeight: popup.stackHeight + popup.travel
    color: "transparent"
    surfaceFormat.opaque: false

    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    property int bodyWidth: 422
    property int bodyHeight: 160
    property int bodyGap: 12
    // Единственное место, где задаётся число одновременно видимых уведомлений.
    property int maxNotifications: 2

    readonly property int step: bodyHeight + bodyGap
    readonly property int travel: step
    readonly property int stackHeight: maxNotifications * bodyHeight + (maxNotifications - 1) * bodyGap
    // Позиция самого нижнего слота: его низ совпадает с нижним краем экрана.
    readonly property int bottomSlotY: stackHeight - bodyHeight

    property color bgColor: "#111318"
    property color fgColor: "#e1e2e9"
    property color accentColor: "#a7c8ff"
    property color borderColor: "#59FFFFFF"

    readonly property string bellGlyph: "\u{f0178}"

    property int sequence: 0

    ListModel {
        id: notifications
    }

    visible: notifications.count > 0

    function iconSource(icon: string): string {
        if (!icon || icon.length === 0)
            return "";
        if (icon.indexOf("/") === 0)
            return "file://" + icon;
        if (icon.indexOf("file:") === 0 || icon.indexOf("http:") === 0 || icon.indexOf("https:") === 0 || icon.indexOf("image://") === 0 || icon.indexOf("qrc:") === 0)
            return icon;
        if (typeof Quickshell.iconPath === "function") {
            var p = Quickshell.iconPath(icon, true);
            if (p && p.length > 0)
                return p;
        }
        return "";
    }

    function activeCount(): int {
        var n = 0;
        for (var i = 0; i < notifications.count; i++) {
            if (!notifications.get(i).exiting)
                n++;
        }
        return n;
    }

    function oldestActiveId(): int {
        for (var i = 0; i < notifications.count; i++) {
            if (!notifications.get(i).exiting)
                return notifications.get(i).notifId;
        }
        return -1;
    }

    // Пересчитывает слоты снизу вверх: 0 — самый нижний (самый свежий).
    function relayout(): void {
        var slot = 0;
        for (var i = notifications.count - 1; i >= 0; i--) {
            if (notifications.get(i).exiting)
                continue;
            notifications.setProperty(i, "slot", slot++);
        }
    }

    // Начинает уход вправо, не дожидаясь таймера.
    function removeById(id: int): void {
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).notifId !== id)
                continue;
            if (notifications.get(i).exiting)
                return;
            notifications.setProperty(i, "exiting", true);
            var item = cards.itemAt(i);
            if (item)
                item.exit();
            else
                popup.finalizeRemoval(id);
            return;
        }
    }

    function finalizeRemoval(id: int): void {
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).notifId === id) {
                notifications.remove(i);
                relayout();
                return;
            }
        }
    }

    function pushNotification(n): void {
        var id = ++sequence;
        notifications.append({
            notifId: id,
            slot: 0,
            exiting: false,
            summary: n.summary || "",
            body: n.body || "",
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            image: n.image || ""
        });
        if (activeCount() > maxNotifications) {
            var old = oldestActiveId();
            if (old > 0)
                removeById(old);
        }
        relayout();
    }

    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        persistenceSupported: true
        keepOnReload: false

        onNotification: function (notification) {
            notification.tracked = true;
            popup.pushNotification(notification);
        }
    }

    Item {
        anchors.fill: parent

        Repeater {
            id: cards
            model: notifications

            delegate: Item {
                id: card
                width: popup.bodyWidth
                height: popup.bodyHeight
                y: popup.bottomSlotY - model.slot * popup.step
                opacity: 1

                readonly property int notifId: model.notifId
                readonly property string imageSource: model.image.length > 0 ? popup.iconSource(model.image) : ""
                readonly property string iconSourceValue: imageSource.length > 0 ? imageSource : popup.iconSource(model.appIcon)

                Behavior on y {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.InCubic
                    }
                }

                transform: Translate {
                    id: shift
                    x: 0
                    y: popup.travel

                    Behavior on x {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.InCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                function exit(): void {
                    shift.x = popup.bodyWidth + 40;
                    opacity = 0;
                    exitTimer.restart();
                }

                Component.onCompleted: {
                    shift.y = 0;
                    dismissTimer.restart();
                }

                Timer {
                    id: dismissTimer
                    interval: 5000
                    running: false
                    repeat: false
                    onTriggered: popup.removeById(notifId)
                }

                Timer {
                    id: exitTimer
                    interval: 280
                    running: false
                    repeat: false
                    onTriggered: popup.finalizeRemoval(notifId)
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(popup.bgColor.r, popup.bgColor.g, popup.bgColor.b, 0.92)
                    border.width: 2
                    border.color: popup.borderColor
                }

                Row {
                    anchors {
                        fill: parent
                        leftMargin: 24
                        rightMargin: 12
                        topMargin: 12
                        bottomMargin: 12
                    }
                    spacing: 24

                    Item {
                        id: leftColumn
                        width: 64
                        height: parent.height

                        Item {
                            id: iconBox
                            width: 64
                            height: 64
                            anchors {
                                top: parent.top
                                horizontalCenter: parent.horizontalCenter
                            }

                            Image {
                                id: iconImage
                                anchors.fill: parent
                                source: iconSourceValue
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                smooth: true
                                visible: status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !iconImage.visible
                                text: popup.bellGlyph
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 34
                                color: popup.fgColor
                                opacity: 0.7
                            }
                        }

                        Text {
                            id: appNameText
                            anchors {
                                top: iconBox.bottom
                                topMargin: 12
                                left: parent.left
                                right: parent.right
                            }
                            text: model.appName
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: popup.accentColor
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.NoWrap
                        }
                    }

                    Item {
                        id: rightColumn
                        width: parent.width - leftColumn.width - parent.spacing
                        height: parent.height

                        Text {
                            id: titleText
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            text: model.summary.length > 0 ? model.summary : "Новое уведомление"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 16
                            font.bold: true
                            color: popup.fgColor
                            elide: Text.ElideRight
                            wrapMode: Text.NoWrap
                        }

                        Text {
                            id: bodyText
                            anchors {
                                top: titleText.bottom
                                topMargin: 6
                                left: parent.left
                                right: parent.right
                                bottom: parent.bottom
                            }
                            text: model.body
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                            color: popup.fgColor
                            opacity: 0.85
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
