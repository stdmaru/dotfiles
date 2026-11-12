pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import qs.components.common as Common
import QtQuick
import QtQuick.Controls

// Painel que desce da barra: histórico de notificações à esquerda e
// calendário, clima e mídia à direita.
Item {
    id: root

    // Barra da qual o painel brota.
    required property Item attachedBar

    readonly property bool historyEmptyOrLeaving: {
        for (let i = 0; i < Notifications.tray.count; ++i) {
            if (!Notifications.tray.get(i).group.dismissPending)
                return false
        }
        return true
    }
    property real expansionProgress: Notifications.trayOpen ? 1 : 0

    anchors.fill: parent
    visible: Notifications.trayOpen || expansionProgress > 0

    Behavior on expansionProgress {
        NumberAnimation {
            duration: Config.notification_panel_ms
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: Notifications
        function onTrayOpenChanged(): void {
            if (Notifications.trayOpen)
                calendarCard.resetToToday()
        }
    }

    // Qualquer clique fora do painel (inclusive na barra) o fecha. Fica abaixo
    // da superfície do painel, cujos controles continuam clicáveis.
    MouseArea {
        anchors.fill: parent
        visible: Notifications.trayOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: Notifications.trayOpen = false
    }

    Common.DockSilhouette {
        x: background.x
        y: background.y
        width: background.width
        height: background.height
    }

    Rectangle {
        id: background

        readonly property real targetWidth: Math.min(Config.notification_panel_max_width, root.width - 24)
        readonly property real targetHeight: Math.min(Config.notification_panel_height, root.height - background.y - 24)

        x: (root.width - width) / 2
        y: root.attachedBar.barBottom
        width: targetWidth
        height: targetHeight * Math.max(0, root.expansionProgress)
        // Só recorta o conteúdo; o fundo é a silhueta desenhada atrás.
        color: "transparent"
        clip: true
        z: 1

        // Consome cliques em áreas vazias do painel para que não cheguem ao
        // fechamento por clique externo. Os controles ficam acima dele.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        Item {
            id: panelContent
            // O conteúdo mantém o tamanho final enquanto o painel recortado
            // cresce, para que nada reflua no meio da animação.
            readonly property real gap: 15
            readonly property real weightSum: Config.notification_panel_left_weight
                + Config.notification_panel_right_weight
            width: Math.max(0, background.targetWidth - Config.notification_panel_inset * 2)
            height: Math.max(0, background.targetHeight - Config.notification_panel_inset * 2)
            x: Config.notification_panel_inset
            y: Config.notification_panel_inset
            opacity: root.expansionProgress

            Item {
                id: notificationsPane
                width: (panelContent.width - panelContent.gap)
                    * Config.notification_panel_left_weight / panelContent.weightSum
                height: panelContent.height

                Column {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        id: notificationsTitle
                        text: "Notificações"
                        font.family: Theme.font_display
                        font.pixelSize: 18
                        color: Theme.text
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
                            required property var group
                            readonly property real rowGap: 6
                            width: notificationList.width
                            implicitHeight: notification.implicitHeight + rowGap
                            // O espaço entre cartões encolhe junto com a
                            // linha, para a remoção não terminar em um salto.
                            height: notification.height
                                + rowGap * Math.max(0, 1 - notification.exitProgress)
                            clip: true

                            NotificationItem {
                                id: notification
                                scene: "tray"
                                group: notificationRow.group
                                modelData: notificationRow.group.head
                                width: notificationRow.width
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            visible: root.historyEmptyOrLeaving
                            opacity: visible ? 1 : 0

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.family: Theme.font_awesome
                                font.pixelSize: 24
                                color: Theme.subtext0
                                text: "\uf0f3"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                font.family: Theme.font_display
                                font.pixelSize: 14
                                color: Theme.subtext0
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
                                font.family: Theme.font_display
                                font.pixelSize: 11
                                color: Theme.text
                            }

                            Switch {
                                id: doNotDisturbSwitch
                                width: 40
                                height: parent.height
                                checked: Notifications.doNotDisturb
                                onToggled: Preferences.notifications.doNotDisturb = checked
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
                                    color: doNotDisturbSwitch.checked ? Theme.blue : Theme.surface1
                                    border.width: doNotDisturbSwitch.checked ? 0 : 1
                                    border.color: Theme.surface2

                                    Behavior on color {
                                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.OutCubic }
                                    }

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        y: 3
                                        x: doNotDisturbSwitch.checked ? parent.width - width - 3 : 3
                                        radius: width / 2
                                        color: doNotDisturbSwitch.checked ? Theme.crust : Theme.text

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
                                font.family: Theme.font_display
                                font.pixelSize: 11
                                color: clearButton.enabled
                                    ? (clearButton.hovered ? Theme.red : Theme.text)
                                    : Theme.surface2
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: Theme.radius_s
                                color: clearButton.hovered && clearButton.enabled ? "#34232f" : Theme.base

                                Behavior on color {
                                    ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: widgetsPane
                anchors.right: parent.right
                width: (panelContent.width - panelContent.gap)
                    * Config.notification_panel_right_weight / panelContent.weightSum
                height: panelContent.height
                spacing: 12

                CalendarCard {
                    id: calendarCard
                    width: parent.width
                }

                WeatherCard {
                    width: parent.width
                }

                MediaCard {
                    width: parent.width
                }
            }
        }
    }


}
