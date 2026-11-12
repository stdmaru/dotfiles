pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls

SwipeDelegate {
    id: root
    // Entrada exibida (Notifications.NotificationEntry).
    required property var modelData
    // "popup" (toast temporário) ou "tray" (histórico no painel).
    required property string scene
    // Grupo do painel ao qual o cartão pertence; nulo nos popups.
    property var group: null
    readonly property string avatarSource: group?.avatarSource ?? ""
    readonly property string displayBody: group?.displayBody ?? ""

    property int implicitHeightCollapsed: 76

    property bool expand: false
    property bool isExiting: false
    // Expansion is driven by one progress value. The text viewport and the
    // card's implicit height therefore move together instead of the card
    // starting a second, lagging height animation.
    property real expandProgress: 0
    property real exitProgress: 0
    readonly property string expandedBodyText: {
        const body = String(root.displayBody || root.modelData?.body || "")
        const limit = Config.notification_body_max_chars
        if (body.length <= limit)
            return body

        return `${body.slice(0, limit).replace(/\s+$/, "")}…`
    }
    readonly property bool popupActive: root.scene === "popup"
        && Notifications.indexOf(Notifications.popups, root.modelData) >= 0
    readonly property bool popupPointerInside: root.scene === "popup"
        && popupPointerArea.containsMouse

    onPopupActiveChanged: {
        if (!popupActive) {
            timer.stop()
            exitTimer.stop()
        }
    }

    // Time display
    property string relativeTime
    property int currentInterval: 1000

    leftPadding: 0
    rightPadding: 0
    topPadding: 3
    bottomPadding: 3

    background: null

    clip: true
    implicitHeight: container.implicitHeight + topPadding + bottomPadding
    height: implicitHeight * Math.max(0, 1 - exitProgress)
    opacity: Math.max(0, 1 - exitProgress)

    Behavior on expandProgress {
        NumberAnimation {
            duration: Config.notification_expand_ms
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motion_spatial_curve
        }
    }

    Behavior on exitProgress {
        NumberAnimation {
            duration: Config.notification_panel_ms
            easing.type: Easing.BezierSpline
            // Avoid the spatial curve's overshoot here: clamping an overshoot
            // to zero makes the toast look as if it vanishes instantly.
            easing.bezierCurve: Config.motion_effect_curve
        }
    }

    onExpandChanged: expandProgress = expand ? 1 : 0

    Timer {
        id: timer
        interval: root.modelData?.expireTimeout > 0
            ? Math.round(root.modelData.expireTimeout * 1000)
            : 4_000
        onTriggered: {
            if (!root.popupActive || root.modelData.popupHovered || root.popupPointerInside) {
                stop()
                return
            }

            root.beginExit(false)
        }
    }

    // Reconcile the model hover flag with the actual pointer position. This
    // covers missed enter/leave events from layer-shell pointer handlers.
    Timer {
        id: hoverReconcileTimer
        interval: 100
        repeat: true
        running: root.popupActive
        onTriggered: root.syncPopupHover()
    }

    Timer {
        id: exitTimer
        // Let the visual animation finish before removing the model row.
        interval: Config.notification_panel_ms + 80
        onTriggered: {
            // A clear-all request owns removal timing so every card can run
            // its exit animation together before the history is discarded.
            if (root.group?.exitRequested)
                return

            if (root.scene === "popup" && !exitTimer.dismissPermanently) {
                if (!Notifications.expirePopup(root.modelData)) {
                    root.isExiting = false
                    root.exitProgress = 0
                }
                return
            }

            if (root.group)
                Notifications.dismissNotificationGroup(root.group.notifications)
            else
                Notifications.dismissNotification(root.modelData)
        }

        property bool dismissPermanently: false
    }

    Connections {
        target: root.group

        function onExitRequestedChanged() {
            if (!root.group.exitRequested)
                return

            // Restart the timer if this card was already swiped when
            // Clear was pressed, keeping all cards in the same animation.
            exitTimer.stop()
            root.isExiting = false
            root.beginExit(true)
        }
    }

    Timer {
        id: relativeTimer
        repeat: true
        running: !!root.modelData
        interval: root.currentInterval

        onTriggered: root.updateRelativeTime()
    }

    function updateRelativeTime() {
        if (!root.modelData)
            return

        const delta = Date.now() - modelData.createdAt

        // Atualiza texto
        root.relativeTime = Utils.formatRelativeTime(delta)

        // Decide próximo intervalo
        const next = nextUpdateInterval(delta)

        if (next < 0) {
            relativeTimer.stop()
        } else if (next !== root.currentInterval) {
            root.currentInterval = next
            relativeTimer.restart()
        }
    }

    function nextUpdateInterval(deltaMs) {
        const seconds = deltaMs / 1000
        if (seconds < 60)
            return 1000          // 1s

        if (seconds < 3600)
            return 60_000        // 1 min

        if (seconds < 86400)
            return 3_600_000     // 1 hora

        return -1                // não precisa mais atualizar
    }

    function beginExit(dismissPermanently) {
        if (root.isExiting)
            return
        if (root.scene === "popup" && !root.popupActive && !dismissPermanently)
            return
        if (root.scene === "popup" && root.modelData.popupHovered && !dismissPermanently)
            return

        root.isExiting = true
        root.exitProgress = 1
        exitTimer.dismissPermanently = dismissPermanently
        exitTimer.start()

        // Publish the pending removal only after exitProgress has started so
        // showing the empty state cannot interrupt the delegate transition.
        if (root.group && dismissPermanently)
            root.group.dismissPending = true
    }

    function cancelAutomaticExit() {
        if (root.scene !== "popup" || !root.isExiting || exitTimer.dismissPermanently)
            return

        exitTimer.stop()
        root.isExiting = false
        root.exitProgress = 0
    }

    function syncPopupHover() {
        if (!root.popupActive || !root.modelData)
            return

        const inside = root.popupPointerInside
        const changed = root.modelData.popupHovered !== inside
        root.modelData.popupHovered = inside
        if (inside) {
            timer.stop()
            root.cancelAutomaticExit()
        } else if (!root.isExiting && (changed || !timer.running)) {
            // Restart from the full timeout after the cursor leaves.
            timer.restart()
        }
    }

    Component.onCompleted: {
        updateRelativeTime()
        syncPopupHover()
        if (root.group?.exitRequested)
            root.beginExit(true)
    }

    HoverHandler {
        id: popupHover
        target: root
        cursorShape: (root.pressed) ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        acceptedButtons: Qt.AllButtons
        
        onTapped: {
            if (!root.isExiting && !actionsFlowHover.hovered && !replyRowHover.hovered)
                root.expand = !root.expand
        }
    }

    swipe.right: SwipeRectangle{}

    component SwipeRectangle: Rectangle {
        width: parent?.width ?? 0
        height: parent?.height ?? 0
        color: "transparent"
    }

    swipe.onCompleted: {
        root.beginExit(true)
    }

    contentItem: Rectangle {
        id: container
        anchors.top: parent.top
        width: parent.width
        implicitHeight: innerContent.implicitHeight + 10
        color: popupHover.hovered ? Theme.surface0 : Theme.base
        radius: Theme.radius_m
        clip: true
        scale: root.pressed ? 0.99 : 1

        Behavior on color {
            ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
        }
        Behavior on scale {
            NumberAnimation { duration: root.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
        }

        Rectangle {
            id: innerContent
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 5
            }
            width: parent.width - 10
            implicitHeight: Math.max(avatar.height + avatar.anchors.topMargin + avatar.anchors.bottomMargin, content.implicitHeight)
            color: "transparent"

            Rectangle {
                id: avatar
                color: Theme.crust
                width: 56
                height: width
                radius: width
                anchors.margins: 2
                anchors.top: parent.top
                anchors.left: parent.left
                //anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: img
                    source: root.avatarSource || root.modelData?.image || ""
                    width: avatar.width
                    height: avatar.height
                    sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                    smooth: true
                    mipmap: true
                    //fillMode: Image.PreserveAspectCrop
                    z: 1

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: avatar.width
                            height: avatar.height
                            radius: avatar.radius
                            color: "white"   // alpha = 1
                        }
                    }

                    // qsimage URLs are owned by the notification service and
                    // become invalid after Quickshell restarts. Capture only
                    // those transient images once, then the controller stores
                    // a small PNG data payload in the notification history.
                    onStatusChanged: {
                        if (status !== Image.Ready
                                || !root.modelData
                                || root.modelData.imageBase64
                                || !String(root.modelData.image).startsWith("image://qsimage/"))
                            return

                        const imageId = `${root.modelData.id}-${root.modelData.createdAt}`
                        const tempPath = `/tmp/quickshell-notification-image-${imageId}-${Math.random().toString(36).slice(2)}.png`
                        img.grabToImage(function(result) {
                            if (result && result.saveToFile(tempPath))
                                Notifications.captureNotificationImage(root.modelData, tempPath)
                            else
                                Notifications.queueTempImageRemoval(tempPath)
                        }, Qt.size(96, 96))
                    }
                }

                Text {
                    font.family: Theme.font_awesome
                    font.pixelSize: 24
                    anchors.centerIn: parent
                    text: "\uf0f3"
                    color: Theme.subtext0
                }
            }

            Rectangle {
                id: content
                radius: 5
                color: "transparent"
                anchors.leftMargin: 5
                anchors.left: avatar.right

                width: parent.width - avatar.width - 10
                implicitHeight: detailsBottom + 10
                readonly property real detailsBottom: replyRow.visible
                    ? replyRow.y + replyRow.height
                    : actionsFlow.visible
                        ? actionsFlow.y + actionsFlow.height
                        : body.y + body.height
                
                TextMetrics {
                    id: titleText
                    text: root.modelData?.summary ?? ""
                }

                Row {
                    id: appName
                    anchors.top: content.top
                    anchors.left: content.left
                    anchors.topMargin: 5
                    anchors.leftMargin: 5
                    height: Math.max(16, Math.ceil(appNameText.implicitHeight / 2) * 2)
                    spacing: 4
                    opacity: root.expand ? 1 : 0

                    Image {
                        width: 16
                        height: 16
                        anchors.verticalCenter: parent.verticalCenter
                        source: Utils.getAppIcon(
                            root.modelData?.desktopEntry || root.modelData?.appName || "",
                            "application-x-executable"
                        )
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(32, 32)
                        smooth: true
                        mipmap: true
                        asynchronous: true
                    }

                    Text {
                        id: appNameText
                        width: Math.min(implicitWidth, Math.max(0, content.width * 0.5 - 22))
                        height: parent.height
                        text: root.modelData?.appName || "Aplicativo"
                        font.family: Theme.font_ui
                        font.pointSize: 11
                        color: Theme.subtext0
                        maximumLineCount: 1
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: Config.notification_fade_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                    }
                }

                Text {
                    id: title
                    anchors.top: content.top

                    font.family: Theme.font_display
                    text: titleText.text
                    font.pointSize: 11

                    color: Theme.text
                    topPadding: 5
                    leftPadding: 5
                    maximumLineCount: 1

                    states: [
                        State{
                            name: "expanded"
                            when: root.expand
                            AnchorChanges {
                                target: title
                                anchors.top: appName.bottom
                            }
                        }
                    ]
                    
                    transitions: [
                        Transition{
                            AnchorAnimation { duration: Config.notification_slide_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                        }
                    ]
                }

                Text {
                    id: timeSeparator
                    anchors.top: content.top
                    anchors.left: title.right

                    font.family: Theme.font_ui
                    text: "•"
                    font.pointSize: 11

                    color: Theme.subtext0
                    topPadding: 6
                    leftPadding: 5
                    maximumLineCount: 1

                    states: [
                        State {
                            name: "expanded"
                            when: root.expand
                            AnchorChanges {
                                target: timeSeparator
                                anchors.top: content.top
                                anchors.left: appName.right
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            AnchorAnimation {
                                duration: Config.notification_slide_ms
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Config.motion_spatial_curve
                            }
                        }
                    ]
                }

                Text {
                    id: time
                    anchors.top: content.top
                    anchors.left: timeSeparator.right

                    font.family: Theme.font_ui
                    text: root.relativeTime
                    font.pointSize: 10

                    color: Theme.subtext0

                    topPadding: 6
                    leftPadding: 5
                    maximumLineCount: 1
                }

                Text {
                    id: expandBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: appName.verticalCenter
                    font.family: Theme.font_ui
                    text: (root.expand) ? "\uf077" : "\uf078"
                    font.pointSize: 10
                    color: Theme.subtext0
                    rightPadding: 0
                    bottomPadding: 5
                    maximumLineCount: 1
                }
            
                TextMetrics {
                    id: bodyText
                    text: root.expandedBodyText
                    //text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
                    elide: Text.ElideRight
                    elideWidth: content.width - 50
                }

                Text {
                    id: body
                    anchors.top: title.bottom
                    font.family: Theme.font_ui
                    width: parent.width
                    text: bodyText.text
                    wrapMode: Text.WordWrap
                    font.pointSize: 10
                    color: Theme.subtext0
                    leftPadding: 4
                    maximumLineCount: 999
                    height: collapsedBody.implicitHeight
                        + (implicitHeight - collapsedBody.implicitHeight) * root.expandProgress
                    clip: true

                    // Measure the collapsed one-line viewport separately;
                    // the visible Text keeps its full content height so its
                    // viewport can reveal it continuously.
                    Text {
                        id: collapsedBody
                        width: body.width
                        text: body.text
                        font: body.font
                        wrapMode: body.wrapMode
                        leftPadding: body.leftPadding
                        maximumLineCount: 1
                        visible: false
                    }
                }

                Flow {
                    id: actionsFlow
                    anchors.top: body.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    spacing: 6
                    visible: root.expand && (root.modelData?.actions?.length ?? 0) > 0
                    height: visible ? implicitHeight : 0

                    HoverHandler { id: actionsFlowHover }

                    Repeater {
                        model: root.modelData?.actions ?? []

                        delegate: Rectangle {
                            id: actionButton
                            required property var modelData

                            width: Math.min(actionLabel.implicitWidth + 22, actionsFlow.width)
                            height: 30
                            radius: Theme.radius_s
                            enabled: !!root.modelData?.sourceNotification
                            opacity: enabled ? 1 : 0.48
                            color: !enabled ? Theme.base
                                : actionHover.hovered ? Theme.blue : Theme.surface1

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.ui_color_ms
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Config.motion_effect_curve
                                }
                            }

                            Text {
                                id: actionLabel
                                anchors.centerIn: parent
                                width: parent.width - 12
                                text: actionButton.modelData.text
                                color: !actionButton.enabled ? Theme.overlay1
                                    : actionHover.hovered ? Theme.crust : Theme.text
                                font.family: Theme.font_ui
                                font.pointSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            HoverHandler { id: actionHover }

                            TapHandler {
                                enabled: actionButton.enabled
                                acceptedButtons: Qt.LeftButton
                                onTapped: {
                                    if (Notifications.activateAction(root.modelData, actionButton.modelData.identifier)) {
                                        root.beginExit(true)
                                        Notifications.trayOpen = false
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    id: replyRow
                    anchors.top: actionsFlow.visible ? actionsFlow.bottom : body.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    height: visible ? 38 : 0
                    spacing: 6
                    visible: root.expand && !!root.modelData?.hasInlineReply

                    HoverHandler { id: replyRowHover }

                    TextField {
                        id: replyInput
                        width: parent.width - sendReplyButton.width - parent.spacing
                        height: parent.height
                        placeholderText: root.modelData?.inlineReplyPlaceholder || "Responder…"
                        color: Theme.text
                        font.family: Theme.font_ui
                        font.pointSize: 9
                        enabled: !!root.modelData?.sourceNotification
                        selectByMouse: true
                        leftPadding: 10
                        rightPadding: 10
                        onAccepted: sendReply()

                        background: Rectangle {
                            radius: Theme.radius_s
                            color: Theme.mantle
                            border.width: replyInput.activeFocus ? 1 : 0
                            border.color: Theme.blue
                        }

                        function sendReply() {
                            const replyText = text
                            if (!replyText.trim())
                                return

                            text = ""
                            if (Notifications.sendInlineReply(root.modelData, replyText))
                                root.beginExit(true)
                            else
                                text = replyText
                        }
                    }

                    Rectangle {
                        id: sendReplyButton
                        width: 38
                        height: parent.height
                        radius: Theme.radius_s
                        enabled: !!root.modelData?.sourceNotification
                        opacity: enabled ? 1 : 0.48
                        color: enabled && sendReplyHover.hovered ? Theme.blue : Theme.surface1

                        Text {
                            anchors.centerIn: parent
                            text: "➤"
                            color: sendReplyHover.hovered ? Theme.crust : Theme.text
                            font.family: Theme.font_ui
                            font.pointSize: 11
                        }

                        HoverHandler { id: sendReplyHover }
                        TapHandler {
                            enabled: sendReplyButton.enabled
                            acceptedButtons: Qt.LeftButton
                            onTapped: replyInput.sendReply()
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation { duration: Config.notification_fade_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
                
            }
            
        }
    }

    // A no-button MouseArea provides a direct hover signal for layer-shell
    // windows while leaving taps and action buttons available underneath.
    MouseArea {
        id: popupPointerArea
        anchors.fill: parent
        z: 100
        visible: root.scene === "popup"
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onEntered: root.syncPopupHover()
        onExited: root.syncPopupHover()
    }
}
