pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import QtQuick

Item {
    id: root
    // Barra da qual a pilha de popups brota.
    required property Item attachedTo

    readonly property real padding: Math.min(10, listView.contentHeight)
    readonly property real shoulderProgress: Config.notification_panel_emergence > 0
        ? Math.min(1, Math.max(0, background.height
            / (Config.notification_panel_emergence + background.bottomLeftRadius)))
        : 0

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: attachedTo.bottom
    anchors.topMargin: root.attachedTo.barBottom - root.attachedTo.height
    width: Math.min(470, parent.width - 24)
    height: Math.min(listView.contentHeight + padding * 2, 500)

    Behavior on height {
        NumberAnimation {
            duration: Config.notification_panel_ms
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: Theme.crust
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Theme.radius_l
        bottomRightRadius: Theme.radius_l
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

                width: listView.width
                implicitHeight: notification.implicitHeight
                height: notification.height
                clip: true

                NotificationItem {
                    id: notification
                    scene: "popup"
                    modelData: popupDelegate.modelData
                    width: popupDelegate.width
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

    // Mesmos ombros curvos do painel, para a pilha de popups crescer a partir
    // da barra em vez de surgir como um retângulo solto.
    DockShoulder {
        x: background.x - width
        y: background.y
        z: 2
        progress: root.shoulderProgress
        color: background.color
    }

    DockShoulder {
        mirrored: true
        x: background.x + background.width
        y: background.y
        z: 2
        progress: root.shoulderProgress
        color: background.color
    }
}
