pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Qt5Compat.GraphicalEffects
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell.Services.Mpris

Item {
    id: root

    required property Item attachedBar
    required property bool isPrimaryScreen

    property var calendarMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property var selectedDate: new Date()
    property int calendarSlideDirection: -1
    property int calendarMonthOffset: 0
    readonly property var weekdays: ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property var activePlayer: {
        const players = Mpris.players.values
        const playing = players.find(player => player.isPlaying)
        return playing ?? players.find(player => player.trackTitle) ?? players[0] ?? null
    }
    readonly property string activePlayerIcon: root.activePlayer
        ? Utils.getAppIcon(root.activePlayer.desktopEntry || root.activePlayer.identity, "audio-x-generic")
        : ""
    readonly property real playerProgress: activePlayer && activePlayer.length > 0
        ? Math.max(0, Math.min(1, activePlayer.position / activePlayer.length))
        : 0
    property bool seekPreviewActive: false
    property real seekPreviewProgress: 0
    readonly property real displayedPlayerProgress: seekPreviewActive
        ? seekPreviewProgress : playerProgress
    readonly property real dayCellWidth: (calendarGrid.width - 6 * calendarGrid.spacing) / 7
    readonly property bool notificationHistoryEmptyOrLeaving: {
        for (let i = 0; i < Notifications.tray.count; ++i) {
            const notification = Notifications.tray.get(i).modelData
            if (!notification.trayDismissPending)
                return false
        }
        return true
    }
    readonly property var calendarDays: {
        const year = calendarMonth.getFullYear()
        const month = calendarMonth.getMonth()
        const firstWeekday = (new Date(year, month, 1).getDay() + 6) % 7

        return Array.from({ length: 42 }, (_, index) => {
            const date = new Date(year, month, index - firstWeekday + 1)
            return {
                day: date.getDate(),
                timestamp: date.getTime(),
                inMonth: date.getMonth() === month,
                isToday: date.toDateString() === new Date().toDateString(),
                isSelected: date.toDateString() === selectedDate.toDateString()
            }
        })
    }
    property real expansionProgress: Notifications.trayOpen ? 1 : 0
    // Caelestia blends the dock and drawer as complete shapes, including the
    // moving lower corner. Approximate that join by keeping the shoulder full
    // until the lower corner reaches it, then shrinking both to zero together.
    readonly property real shoulderProgress: Config.notification_panel_emergence > 0
        ? Math.min(1, Math.max(0, background.height
            / (Config.notification_panel_emergence + Config.notification_panel_corner_radius)))
        : 0

    anchors.fill: parent
    visible: isPrimaryScreen && (Notifications.trayOpen || expansionProgress > 0)

    Behavior on expansionProgress {
        NumberAnimation {
            duration: Config.notification_panel_ms
            easing.type: Easing.OutCubic
            //easing.bezierCurve: Config.motion_spatial_curve
        }
    }

    function changeMonth(offset) {
        if (calendarMonthAnimation.running)
            return

        calendarMonthOffset = offset
        calendarSlideDirection = offset > 0 ? -1 : 1
        calendarMonthAnimation.start()
    }

    SequentialAnimation {
        id: calendarMonthAnimation

        ParallelAnimation {
            NumberAnimation {
                target: calendarGrid
                property: "x"
                to: calendarGrid.width * root.calendarSlideDirection
                duration: 100
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: calendarMonthTitle
                property: "x"
                to: calendarMonthTitle.width * root.calendarSlideDirection
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        ScriptAction {
            script: {
                root.calendarMonth = new Date(
                    root.calendarMonth.getFullYear(),
                    root.calendarMonth.getMonth() + root.calendarMonthOffset,
                    1
                )
                root.selectedDate = new Date(root.calendarMonth)
                calendarGrid.x = -calendarGrid.width * root.calendarSlideDirection
                calendarMonthTitle.x = -calendarMonthTitle.width * root.calendarSlideDirection
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: calendarGrid
                property: "x"
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: calendarMonthTitle
                property: "x"
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    }

    function formatTrackTime(seconds) {
        const total = Math.max(0, Math.floor(seconds ?? 0))
        return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`
    }

    function forecastDayName(day, index) {
        if (index === 0)
            return "Hoje"

        const parts = day.date.split("-").map(Number)
        const date = new Date(parts[0], parts[1] - 1, parts[2])
        return ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"][date.getDay()]
    }

    function activatePlayer(action) {
        const player = root.activePlayer
        if (!player)
            return

        if (action === "previous" && player.canGoPrevious)
            player.previous()
        else if (action === "toggle" && player.canTogglePlaying)
            player.togglePlaying()
        else if (action === "next" && player.canGoNext)
            player.next()
    }

    MouseArea {
        anchors.fill: parent
        anchors.topMargin: root.attachedBar?.barBottom ?? root.attachedBar.height
        visible: Notifications.trayOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: Notifications.trayOpen = false
    }

    // Close on any dock click too. It sits above the topbar but below the
    // drawer surface, so the drawer's controls remain clickable.
    MouseArea {
        x: 0
        y: 0
        width: parent.width
        height: root.attachedBar?.barBottom ?? root.attachedBar.height
        visible: Notifications.trayOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 0
        onClicked: Notifications.trayOpen = false
    }

    Rectangle {
        id: background

        readonly property real targetWidth: Math.min(Config.notification_panel_max_width, root.width - 24)
        readonly property real targetHeight: Math.min(Config.notification_panel_height, root.height - background.y - 24)

        x: (root.width - width) / 2
        y: root.attachedBar?.barBottom ?? (Config.frame_enabled ? root.attachedBar.height + Config.frame_thickness : (root.attachedBar.height - 5))
        width: targetWidth
        height: targetHeight * Math.max(0, root.expansionProgress)
        color: "#11111b"
        // Keep the tray's upper corners square; outward fins below form the
        // convex transition where it grows out of the dock.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Config.notification_panel_corner_radius
        bottomRightRadius: Config.notification_panel_corner_radius
        clip: true
        z: 1

        // Consume clicks on empty panel space (for example inside the
        // calendar card) so they do not reach the full-screen outside-click
        // handler behind the tray. Interactive children are stacked above it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        Row {
            id: panelContent
            // Keep content at its final size while the clipped panel grows
            // downward, so children do not reflow mid-animation.
            width: Math.max(0, background.targetWidth - Config.notification_panel_inset * 2)
            height: Math.max(0, background.targetHeight - Config.notification_panel_inset * 2)
            x: Config.notification_panel_inset
            y: Config.notification_panel_inset
            opacity: root.expansionProgress
            spacing: 15
            
            Item {
                id: notificationsPane
                width: (panelContent.width - panelContent.spacing * 2 - 1)
                    * Config.notification_panel_left_weight
                    / (Config.notification_panel_left_weight + Config.notification_panel_right_weight)
                height: panelContent.height

                Column {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        id: notificationsTitle
                        text: "Notificações"
                        font.family: Config.main_font
                        font.pixelSize: 18
                        color: "#cdd6f4"
                    }

                    ListView {
                        id: notificationList
                        width: parent.width
                        height: Math.max(0, parent.height - notificationsTitle.implicitHeight
                            - notificationActions.height - parent.spacing * 2)
                        model: Notifications.tray
                        clip: true
                        spacing: 0

                        delegate: Item {
                            id: notificationRow
                            required property var modelData
                            required property string avatarSource
                            required property string displayBody
                            required property var groupedNotifications
                            readonly property real rowGap: 6
                            width: notificationList.width
                            implicitHeight: notification.implicitHeight + rowGap
                            // Include the inter-card gap in the collapsing
                            // row so its removal does not create a final jump.
                            height: notification.height
                                + rowGap * Math.max(0, 1 - notification.exitProgress)
                            clip: true

                            NotificationItem {
                                id: notification
                                scene: "tray"
                                modelData: notificationRow.modelData
                                avatarSource: notificationRow.avatarSource
                                displayBody: notificationRow.displayBody
                                groupedNotifications: notificationRow.groupedNotifications
                                width: notificationRow.width
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            visible: root.notificationHistoryEmptyOrLeaving
                            opacity: visible ? 1 : 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.family: "Font Awesome 7 Free"
                                font.pixelSize: 24
                                color: "#a6adc8"
                                text: ""
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.family: Config.main_font
                                font.pixelSize: 14
                                color: "#a6adc8"
                                text: "Sem notificações"
                            }

                            Behavior on opacity {
                                NumberAnimation{ duration: 180; easing.type: Easing.OutCubic}
                            }
                        }
                    }

                    Row {
                        id: notificationActions
                        width: parent.width
                        height: 34
                        spacing: 8

                        Row {
                            id: doNotDisturbControl
                            width: parent.width - clearButton.width - parent.spacing
                            height: parent.height
                            spacing: 8

                            Text {
                                id: doNotDisturbLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Não perturbe"
                                font.family: Config.main_font
                                font.pixelSize: 11
                                color: "#cdd6f4"
                            }

                            Switch {
                                id: doNotDisturbSwitch
                                width: 40
                                height: parent.height
                                checked: Notifications.doNotDisturb
                                onToggled: Notifications.doNotDisturb = checked
                                leftPadding: 0
                                rightPadding: 0
                                text: ""
                                contentItem: Item {}

                                indicator: Rectangle {
                                    width: 38
                                    height: 22
                                    x: doNotDisturbSwitch.leftPadding
                                    y: (doNotDisturbSwitch.height - height) / 2
                                    radius: height / 2
                                    color: doNotDisturbSwitch.checked ? "#89b4fa" : "#45475a"
                                    border.width: doNotDisturbSwitch.checked ? 0 : 1
                                    border.color: "#585b70"

                                    Behavior on color {
                                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        y: 3
                                        x: doNotDisturbSwitch.checked ? parent.width - width - 3 : 3
                                        radius: width / 2
                                        color: doNotDisturbSwitch.checked ? "#11111b" : "#cdd6f4"

                                        Behavior on x {
                                            NumberAnimation { duration: Config.ui_color_ms; easing.type: Easing.OutCubic }
                                        }
                                    }
                                }
                            }
                        }

                        Button {
                            id: clearButton
                            width: 76
                            height: parent.height
                            text: "Limpar"
                            enabled: Notifications.all.count > 0
                            onClicked: Notifications.clearAll()

                            contentItem: Text {
                                text: clearButton.text
                                font.family: Config.main_font
                                font.pixelSize: 11
                                color: clearButton.enabled
                                    ? (clearButton.hovered ? "#f38ba8" : "#cdd6f4")
                                    : "#585b70"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: 9
                                color: clearButton.hovered && clearButton.enabled ? "#34232f" : "#1e1e2e"

                                Behavior on color {
                                    ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                width: 0
                height: panelContent.height
                color: "#313244"
            }

            Item {
                id: widgetsPane
                width: panelContent.width
                    * Config.notification_panel_right_weight
                    / (Config.notification_panel_left_weight + Config.notification_panel_right_weight)
                height: panelContent.height
                anchors.right: parent.right

                Column {
                    anchors.fill: parent
                    spacing: 12

                    Rectangle {
                        id: calendarCard
                        width: parent.width
                        height: 245
                        radius: 14
                        color: "#1e1e2e"

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 7

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 8

                                Item {
                                    id: calendarTitleViewport
                                    width: parent.width - 72
                                    height: parent.height
                                    clip: true

                                    Text {
                                        id: calendarMonthTitle
                                        width: parent.width
                                        height: parent.height
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: Config.main_font
                                        font.pixelSize: 15
                                        color: "#cdd6f4"
                                        text: `${root.monthNames[root.calendarMonth.getMonth()]} ${root.calendarMonth.getFullYear()}`
                                    }
                                }

                                Repeater {
                                    model: ["‹", "›"]

                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: navArea.pressed ? "#45475a"
                                            : navArea.containsMouse ? "#3b3d54" : "#313244"
                                        scale: navArea.pressed ? 0.92 : navArea.containsMouse ? 1.06 : 1

                                        Behavior on color {
                                            ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                        }
                                        Behavior on scale {
                                            NumberAnimation { duration: navArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            anchors.verticalCenterOffset: -2
                                            font.pixelSize: 20
                                            color: "#cdd6f4"
                                        }

                                        MouseArea {
                                            id: navArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: !calendarMonthAnimation.running
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.changeMonth(parent.modelData === "‹" ? -1 : 1)
                                        }
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                height: 18
                                spacing: calendarGrid.spacing

                                Repeater {
                                    model: root.weekdays

                                    Text {
                                        required property string modelData
                                        width: root.dayCellWidth
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: Config.main_font
                                        font.pixelSize: 10
                                        color: "#7f849c"
                                        text: modelData
                                    }
                                }
                            }

                            Item {
                                id: calendarGridViewport
                                width: parent.width
                                height: calendarGrid.implicitHeight
                                clip: true

                                Grid {
                                    id: calendarGrid
                                    width: parent.width
                                    columns: 7
                                    spacing: 3

                                    Repeater {
                                        model: root.calendarDays

                                        delegate: Rectangle {
                                            required property var modelData
                                            width: root.dayCellWidth
                                            height: 24
                                            radius: 7
                                            color: modelData.isSelected ? "#89b4fa"
                                                : dayArea.pressed ? "#45475a"
                                                : dayArea.containsMouse ? "#31364d"
                                                : modelData.isToday ? "#313244"
                                                : "transparent"
                                            scale: dayArea.pressed ? 0.92 : dayArea.containsMouse ? 1.06 : 1

                                            Behavior on color {
                                                ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                            }
                                            Behavior on scale {
                                                NumberAnimation { duration: dayArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData.day
                                                font.family: Config.main_font
                                                font.pixelSize: 11
                                                color: parent.modelData.isSelected ? "#11111b"
                                                    : parent.modelData.inMonth ? "#cdd6f4" : "#585b70"
                                            }

                                            MouseArea {
                                                id: dayArea
                                                anchors.fill: parent
                                                enabled: parent.modelData.inMonth && !calendarMonthAnimation.running
                                                hoverEnabled: true
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: root.selectedDate = new Date(parent.modelData.timestamp)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: weatherCard
                        width: parent.width
                        height: 141
                        radius: 14
                        color: weatherArea.pressed ? "#292b40"
                            : weatherArea.containsMouse ? "#25263a" : "#1e1e2e"

                        Behavior on color {
                            ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                        }

                        MouseArea {
                            id: weatherArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "xdg-open",
                                `https://www.google.com/search?q=weather ${Weather.region} ${Weather.state} ${Weather.country}`
                            ])
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4
                            z: 1

                            // Header, current conditions and forecast follow
                            // one vertical rhythm and fit inside this card.
                            Row {
                                id: header
                                width: parent.width
                                height: 15
                                spacing: 6

                                Text {
                                    id: weatherTitle
                                    text: "Clima"
                                    font.family: Config.main_font
                                    font.pixelSize: 13
                                    color: "#a6adc8"
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    width: parent.width - weatherTitle.implicitWidth - parent.spacing
                                    height: parent.height
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    font.pixelSize: 10
                                    color: "#7f849c"
                                    text: Weather.hasData ? `${Weather.region}, ${Weather.state}` : ""
                                }
                            }

                            Row {
                                id: currentConditions
                                width: parent.width
                                height: 38
                                spacing: 8
                                topPadding: 8
                                
                                Text {
                                    id: temperatureNow
                                    width: 40
                                    height: parent.height
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 42
                                    color: "#89dceb"

                                    text: Weather.hasData ? Weather.glyph : "\ue226"
                                }

                                Column {
                                    width: parent.width - temperatureNow.width - currentConditions.spacing
                                    height: parent.height
                                    spacing: 1

                                    Text {
                                        width: parent.width
                                        height: 21
                                        verticalAlignment: Text.AlignVCenter
                                        font.family: Config.main_font
                                        font.pixelSize: 20
                                        color: "#cdd6f4"

                                        text: Weather.hasData
                                            ? `${Weather.tempCurrent}${Config.temperature_metric}`
                                            : "--°C"
                                    }

                                    Text {
                                        width: parent.width
                                        height: 16
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        font.pixelSize: 11
                                        color: "#a6adc8"

                                        text: Weather.hasData
                                            ? `${Weather.description} · sensação ${Weather.tempFeelsLike}${Config.temperature_metric}`
                                            : "Carregando clima…"
                                    }
                                }
                            }

                            Row {
                                id: weatherForecast
                                width: parent.width
                                height: 54
                                spacing: 4
                                topPadding: 20
                                Repeater {
                                    model: Weather.forecast

                                    delegate: Column {
                                        required property var modelData
                                        required property int index
                                        width: (parent.width - 4 * 4) / 5
                                        spacing: 0

                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            height: 2
                                            font.pixelSize: 9
                                            color: "#a6adc8"
                                            text: root.forecastDayName(parent.modelData, parent.index)
                                        }

                                        Text {
                                            width: parent.width
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.family: "JetBrainsMono Nerd Font Mono"
                                            height: 32
                                            font.pixelSize: 32
                                            color: "#89dceb"
                                            text: parent.modelData.glyph
                                        }

                                        Row {
                                            width: parent.width
                                            height: 2

                                            Text {
                                                width: parent.width / 2
                                                height: parent.height
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 9
                                                color: "#cdd6f4"
                                                text: `${parent.parent.modelData.max}°`
                                            }

                                            Text {
                                                width: parent.width / 2
                                                height: parent.height
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font.pixelSize: 9
                                                color: "#7f849c"
                                                text: `${parent.parent.modelData.min}°`
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: musicCard
                        width: parent.width
                        height: 150
                        radius: 14
                        color: musicArea.pressed ? "#292b40"
                            : musicArea.containsMouse ? "#25263a" : "#1e1e2e"

                        Behavior on color {
                            ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                        }

                        MouseArea {
                            id: musicArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.activePlayer?.canRaise ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: {
                                if (root.activePlayer?.canRaise)
                                    root.activePlayer.raise()
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5
                            z: 1

                            Row {
                                width: parent.width
                                height: 18
                                spacing: 6

                                Text {
                                    width: parent.width - (mediaSourceIcon.visible
                                        ? mediaSourceIcon.width + parent.spacing : 0)
                                    height: parent.height
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Reprodutor de mídia"
                                    font.family: Config.main_font
                                    font.pixelSize: 13
                                    color: "#a6adc8"
                                }

                                Image {
                                    id: mediaSourceIcon
                                    width: 18
                                    height: 18
                                    source: root.activePlayerIcon
                                    visible: !!root.activePlayer && !!source
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    sourceSize.width: 36
                                    sourceSize.height: 36
                                }
                            }

                            Row {
                                width: parent.width
                                height: 52
                                spacing: 10

                                Rectangle {
                                    id: albumArtFrame
                                    width: 52
                                    height: 52
                                    radius: 9
                                    color: "#313244"
                                    clip: true

                                    readonly property bool hasAlbumArt: !!root.activePlayer?.trackArtUrl

                                    Image {
                                        id: albumCover
                                        anchors.fill: parent
                                        anchors.margins: albumArtFrame.hasAlbumArt ? 3 : 0
                                        source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        // Keep enough source detail for the circular mask, but avoid
                                        // mipmap filtering softening this very small 46px thumbnail.
                                        sourceSize.width: Math.max(128, Math.ceil(width * 3))
                                        sourceSize.height: Math.max(128, Math.ceil(height * 3))
                                        mipmap: false
                                        antialiasing: true
                                        visible: albumArtFrame.hasAlbumArt

                                        layer.enabled: visible
                                        layer.effect: OpacityMask {
                                            maskSource: Rectangle {
                                                width: albumCover.width
                                                height: albumCover.height
                                                radius: 6
                                                color: "white"
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "\udb81\udf5a"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 32
                                        color: "#cba6f7"
                                        visible: !albumArtFrame.hasAlbumArt
                                    }
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    width: parent.width - albumArtFrame.width - parent.spacing

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: root.activePlayer
                                            ? (root.activePlayer.trackTitle || root.activePlayer.identity)
                                            : "Nenhuma música tocando"
                                        font.family: Config.main_font
                                        font.pixelSize: 13
                                        color: "#cdd6f4"
                                    }

                                    Text {
                                        width: parent.width
                                        elide: Text.ElideRight
                                        text: `${root.activePlayer ? (root.activePlayer.trackArtist + " - " + root.activePlayer.trackAlbum || root.activePlayer.identity) : "Abra um player compatível com MPRIS" }`
                                        font.pixelSize: 11
                                        color: "#7f849c"
                                    }
                                }
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8

                                Text {
                                    width: 24
                                    height: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "\uf048"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 24
                                    color: !root.activePlayer?.canGoPrevious ? "#585b70"
                                        : prevArea.pressed ? "#89b4fa"
                                        : prevArea.containsMouse ? "#cba6f7" : "#cdd6f4"
                                    scale: prevArea.pressed ? 0.88 : prevArea.containsMouse ? 1.12 : 1

                                    Behavior on color {
                                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: prevArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                    }

                                    MouseArea {
                                        id: prevArea
                                        anchors.fill: parent
                                        enabled: !!root.activePlayer?.canGoPrevious
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.activatePlayer("previous")
                                    }
                                }

                                Rectangle {
                                    id: playButton
                                    width: 26
                                    height: 26
                                    radius: 13
                                    color: !root.activePlayer?.canTogglePlaying ? "#313244"
                                        : playArea.pressed ? "#74c7ec"
                                        : playArea.containsMouse ? "#b4befe" : "#89b4fa"
                                    scale: playArea.pressed ? 0.92 : playArea.containsMouse ? 1.08 : 1

                                    Behavior on color {
                                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: playArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.activePlayer?.isPlaying ? "\uf04c" : "\uf04b"
                                        font.family: "JetBrainsMono Nerd Font Mono"
                                        font.pixelSize: 22
                                        color: root.activePlayer?.canTogglePlaying ? "#11111b" : "#585b70"
                                    }

                                    MouseArea {
                                        id: playArea
                                        anchors.fill: parent
                                        enabled: !!root.activePlayer?.canTogglePlaying
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.activatePlayer("toggle")
                                    }
                                }

                                Text {
                                    width: 24
                                    height: 24
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: "\uf051"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 24
                                    color: !root.activePlayer?.canGoNext ? "#585b70"
                                        : nextArea.pressed ? "#89b4fa"
                                        : nextArea.containsMouse ? "#cba6f7" : "#cdd6f4"
                                    scale: nextArea.pressed ? 0.88 : nextArea.containsMouse ? 1.12 : 1

                                    Behavior on color {
                                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: nextArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                    }

                                    MouseArea {
                                        id: nextArea
                                        anchors.fill: parent
                                        enabled: !!root.activePlayer?.canGoNext
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.activatePlayer("next")
                                    }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 6

                                Text {
                                    id: elapsedLabel
                                    font.pixelSize: 9
                                    color: "#7f849c"
                                    text: root.activePlayer ? root.formatTrackTime(root.activePlayer.position) : "0:00"
                                }

                                Item {
                                    id: seekTrack
                                    width: Math.max(0, parent.width - elapsedLabel.implicitWidth - durationLabel.implicitWidth - parent.spacing * 2)
                                    height: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 2
                                        color: seekArea.containsMouse ? "#45475a" : "#313244"

                                        Behavior on color {
                                            ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width * root.displayedPlayerProgress
                                        height: parent.height
                                        radius: 2
                                        color: "#89b4fa"
                                    }

                                    Rectangle {
                                        id: seekThumb
                                        width: 10
                                        height: 10
                                        radius: width / 2
                                        x: Math.max(0, Math.min(parent.width - width,
                                            parent.width * root.displayedPlayerProgress - width / 2))
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: seekArea.pressed || seekArea.containsMouse ? "#cba6f7" : "#89b4fa"
                                        border.width: 1
                                        border.color: "#cdd6f4"
                                        scale: seekArea.pressed ? 1.18 : 1
                                        z: 1

                                        Behavior on scale {
                                            NumberAnimation { duration: Config.ui_hover_ms; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    MouseArea {
                                        id: seekArea
                                        anchors.fill: parent
                                        enabled: !!root.activePlayer?.canSeek
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                        function updatePosition(pointerX) {
                                            const player = root.activePlayer
                                            if (!player || !player.canSeek || player.length <= 0 || width <= 0)
                                                return

                                            const progress = Math.max(0, Math.min(1, pointerX / width))
                                            root.seekPreviewProgress = progress
                                            root.seekPreviewActive = true
                                            player.position = player.length * progress
                                        }

                                        onPressed: updatePosition(mouse.x)
                                        onPositionChanged: {
                                            if (pressed)
                                                updatePosition(mouse.x)
                                        }
                                        onReleased: seekPreviewTimer.restart()
                                        onCanceled: seekPreviewTimer.restart()

                                        Timer {
                                            id: seekPreviewTimer
                                            interval: 300
                                            onTriggered: root.seekPreviewActive = false
                                        }
                                    }
                                }

                                Text {
                                    id: durationLabel
                                    font.pixelSize: 9
                                    color: "#7f849c"
                                    text: root.activePlayer ? root.formatTrackTime(root.activePlayer.length) : "0:00"
                                }
                            }
                        }

                        Timer {
                            interval: 1000
                            repeat: true
                            running: !!root.activePlayer?.isPlaying
                            onTriggered: root.activePlayer.positionChanged()
                        }
                    }
                }
            }
        }

    }

    // Caelestia uses a soft SDF union; these mirrored cubic shoulders approximate
    // its circular joins at the two re-entrant corners.
    Shape {
        id: leftDockShoulder
        readonly property real growth: Config.notification_panel_emergence * root.shoulderProgress
        x: background.x - width
        y: background.y
        width: Config.notification_panel_emergence
        height: growth
        visible: width > 0 && height > 0
        z: 2

        ShapePath {
            fillColor: background.color
            strokeColor: "transparent"
            startX: 0
            startY: 0
            PathCubic {
                x: leftDockShoulder.width; y: leftDockShoulder.height
                control1X: leftDockShoulder.width * 0.5523; control1Y: 0
                control2X: leftDockShoulder.width; control2Y: leftDockShoulder.height * 0.4477
            }
            PathLine { x: leftDockShoulder.width; y: 0 }
        }

    }

    Shape {
        id: rightDockShoulder
        x: background.x + background.width
        readonly property real growth: Config.notification_panel_emergence * root.shoulderProgress
        y: background.y
        width: Config.notification_panel_emergence
        height: growth
        visible: width > 0 && height > 0
        z: 2

        ShapePath {
            fillColor: background.color
            strokeColor: "transparent"
            startX: rightDockShoulder.width
            startY: 0
            PathCubic {
                x: 0; y: rightDockShoulder.height
                control1X: rightDockShoulder.width * 0.4477; control1Y: 0
                control2X: 0; control2Y: rightDockShoulder.height * 0.4477
            }
            PathLine { x: 0; y: 0 }
        }

    }

}
