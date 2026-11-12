pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import qs.components.common
import QtQuick

Item {
    id: root
    // Barra da qual a pilha de popups brota.
    required property Item attachedTo

    readonly property real padding: Math.min(10, listView.contentHeight)
    // No canto direito, a pilha se encaixa como o menu do sistema: a lateral
    // direita continua a borda da barra (ou se funde à moldura).
    readonly property bool dockedRight: Preferences.notifications.popupPosition === "right"
    // Há popups encaixados sob a barra; ela endireita o canto até sumirem.
    readonly property bool docking: dockedRight && height > 0.5

    x: dockedRight
        ? parent.width - width - (Config.frame_enabled ? Config.frame_thickness : Config.bar_margin)
        : (parent.width - width) / 2
    anchors.top: attachedTo.bottom
    anchors.topMargin: root.attachedTo.barBottom - root.attachedTo.height
    width: Math.min(Preferences.notifications.popupWidth, parent.width - 24)
    // Segue o conteúdo diretamente: os itens já animam a própria altura
    // (entrada, expansão, saída), e uma animação aqui por cima só atrasaria
    // o fundo em relação a eles.
    height: Math.min(listView.contentHeight + padding * 2, 500)

    DockSilhouette {
        anchors.fill: parent
        rightEdge: !root.dockedRight ? "ramp"
            : Config.frame_enabled ? "border" : "flush"
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "transparent"
        clip: true

        ListView {
            id: listView
            x: root.padding
            y: root.padding
            width: Math.max(1, root.width - root.padding * 2)
            // Keep the delegate viewport alive while the shell's own height
            // is being derived from contentHeight. The background clips the
            // excess until the first item has unfolded.
            height: 500
            model: Notifications.popups
            interactive: false
            clip: true
            spacing: 4
            cacheBuffer: 500

            delegate: Item {
                id: popupDelegate
                required property var modelData
                // Deslocamento de entrada (1 → 0), animado em `add`: no
                // centro o cartão desce da barra; à direita, entra pela borda
                // da tela.
                property real enterX: 0
                property real enterY: 0

                width: listView.width
                implicitHeight: notification.implicitHeight
                height: notification.height
                clip: true

                NotificationItem {
                    id: notification
                    scene: "popup"
                    modelData: popupDelegate.modelData
                    width: popupDelegate.width

                    // O recorte do fundo esconde o cartão fora do painel, então
                    // à direita ele parece vir de trás da borda da tela, e sai
                    // de volta por ela.
                    transform: Translate {
                        x: (popupDelegate.enterX
                            + (root.dockedRight ? notification.exitProgress : 0))
                            * (popupDelegate.width + root.padding * 2)
                        y: -popupDelegate.enterY * notification.implicitHeight
                    }
                }
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "height"
                        from: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                    }
                    NumberAnimation {
                        property: "enterX"
                        from: root.dockedRight ? 1 : 0
                        to: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        property: "enterY"
                        from: root.dockedRight ? 0 : 1
                        to: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        duration: Config.notification_fade_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_effect_curve
                    }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "height"
                        to: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_effect_curve
                    }
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Config.notification_panel_ms
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Config.motion_spatial_curve
                }
            }
        }
    }


}
