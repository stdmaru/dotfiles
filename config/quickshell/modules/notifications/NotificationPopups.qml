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
            // O espaço entre cartões fica dentro de cada delegate (veja
            // `gap`), para encolher junto com o cartão que sai.
            spacing: 0
            cacheBuffer: 500

            delegate: Item {
                id: popupDelegate
                required property var modelData
                required property int index
                // Entrada animada pelo próprio delegate, e não pela transição
                // `add` do ListView: quando várias chegam juntas, cada nova
                // desloca as anteriores e o ListView interrompe a transição
                // delas no meio, deixando os cartões parados fora do lugar.
                // No centro o cartão desce da barra; à direita, entra pela
                // borda da tela. Deslocamentos vão de 1 a 0.
                property real enterX: root.dockedRight ? 1 : 0
                property real enterY: root.dockedRight ? 0 : 1
                property real enterHeight: 0

                // Espaço acima do cartão; o primeiro não tem. Some junto com o
                // cartão quando ele sai, e cresce quando outro chega acima.
                property real gap: index > 0 ? 4 : 0
                readonly property real visibleGap: gap * Math.max(0, 1 - notification.exitProgress)

                Behavior on gap {
                    NumberAnimation {
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                    }
                }

                width: listView.width
                implicitHeight: notification.implicitHeight + gap
                height: (visibleGap + notification.height) * enterHeight
                opacity: 0
                clip: true

                Component.onCompleted: entryAnimation.start()

                ParallelAnimation {
                    id: entryAnimation

                    NumberAnimation {
                        target: popupDelegate
                        property: "enterHeight"
                        to: 1
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                    }
                    NumberAnimation {
                        target: popupDelegate
                        property: "enterX"
                        to: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: popupDelegate
                        property: "enterY"
                        to: 0
                        duration: Config.notification_panel_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                    }
                    NumberAnimation {
                        target: popupDelegate
                        property: "opacity"
                        to: 1
                        duration: Config.notification_fade_ms
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_effect_curve
                    }
                }

                NotificationItem {
                    id: notification
                    scene: "popup"
                    modelData: popupDelegate.modelData
                    width: popupDelegate.width
                    y: popupDelegate.visibleGap

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

            // Sem transição `displaced`: cada cartão anima a própria altura ao
            // entrar e sair, e a lista reposiciona os demais a cada quadro.
            // Animar o y por cima disso fazia os cartões se sobreporem.
        }
    }


}
