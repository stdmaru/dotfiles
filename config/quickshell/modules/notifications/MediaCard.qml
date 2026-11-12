pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris
import QtQuick

// Controle do player MPRIS ativo: capa, faixa, transporte e busca.
Rectangle {
    id: root

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
    // Enquanto o usuário arrasta, a barra segue o ponteiro e não o player.
    property bool seekPreviewActive: false
    property real seekPreviewProgress: 0
    readonly property real displayedPlayerProgress: seekPreviewActive
        ? seekPreviewProgress : playerProgress
    readonly property string trackSubtitle: {
        if (!activePlayer)
            return "Abra um player compatível com MPRIS"
        const parts = [activePlayer.trackArtist, activePlayer.trackAlbum].filter(part => part)
        return parts.length > 0 ? parts.join(" - ") : activePlayer.identity
    }

    function formatTrackTime(seconds): string {
        const total = Math.max(0, Math.floor(seconds ?? 0))
        return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`
    }

    function activatePlayer(action: string): void {
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

    height: 150
    radius: Theme.radius_m
    color: musicArea.pressed ? Theme.basePressed
        : musicArea.containsMouse ? Theme.baseHover : Theme.base

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
                font.family: Theme.font_display
                font.pixelSize: 13
                color: Theme.subtext0
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
                radius: Theme.radius_s
                color: Theme.surface0
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
                    font.family: Theme.font_nerd
                    font.pixelSize: 32
                    color: Theme.mauve
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
                    font.family: Theme.font_display
                    font.pixelSize: 13
                    color: Theme.text
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.trackSubtitle
                    font.family: Theme.font_ui
                    font.pixelSize: 11
                    color: Theme.overlay1
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
                font.family: Theme.font_nerd
                font.pixelSize: 24
                color: !root.activePlayer?.canGoPrevious ? Theme.surface2
                    : prevArea.pressed ? Theme.blue
                    : prevArea.containsMouse ? Theme.mauve : Theme.text
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
                color: !root.activePlayer?.canTogglePlaying ? Theme.surface0
                    : playArea.pressed ? Theme.sapphire
                    : playArea.containsMouse ? Theme.lavender : Theme.blue
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
                    font.family: Theme.font_nerd
                    font.pixelSize: 22
                    color: root.activePlayer?.canTogglePlaying ? Theme.crust : Theme.surface2
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
                font.family: Theme.font_nerd
                font.pixelSize: 24
                color: !root.activePlayer?.canGoNext ? Theme.surface2
                    : nextArea.pressed ? Theme.blue
                    : nextArea.containsMouse ? Theme.mauve : Theme.text
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
                font.family: Theme.font_ui
                font.pixelSize: 9
                color: Theme.overlay1
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
                    color: seekArea.containsMouse ? Theme.surface1 : Theme.surface0

                    Behavior on color {
                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                    }
                }

                Rectangle {
                    width: parent.width * root.displayedPlayerProgress
                    height: parent.height
                    radius: 2
                    color: Theme.blue
                }

                Rectangle {
                    id: seekThumb
                    width: 10
                    height: 10
                    radius: width / 2
                    x: Math.max(0, Math.min(parent.width - width,
                        parent.width * root.displayedPlayerProgress - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    color: seekArea.pressed || seekArea.containsMouse ? Theme.mauve : Theme.blue
                    border.width: 1
                    border.color: Theme.text
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
                font.family: Theme.font_ui
                font.pixelSize: 9
                color: Theme.overlay1
                text: root.activePlayer ? root.formatTrackTime(root.activePlayer.length) : "0:00"
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        // O MPRIS não notifica a posição continuamente; force a releitura
        // apenas enquanto o cartão está visível.
        running: root.visible && !!root.activePlayer?.isPlaying
        onTriggered: root.activePlayer?.positionChanged()
    }
}
