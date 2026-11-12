pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property Item attachedTo
    required property bool isPrimaryScreen

    readonly property real padding: Math.min(10, listView.contentHeight)
    readonly property real shoulderProgress: Config.notification_panel_emergence > 0
        ? Math.min(1, Math.max(0, background.height
            / (Config.notification_panel_emergence + background.bottomLeftRadius)))
        : 0

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: attachedTo.bottom
    anchors.topMargin: root.attachedTo?.barBottom !== undefined ? (root.attachedTo.barBottom - root.attachedTo.height) : (Config.frame_enabled ? Config.frame_thickness : -5)
    width: Math.min(470, parent.width - 24)
    height: Math.min(listView.contentHeight + padding * 2, 500)
    // Keep the ListView active while empty so its add transition also runs
    // when the first notification arrives.
    visible: isPrimaryScreen

    Behavior on height {
        NumberAnimation {
            duration: Config.notification_panel_ms
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "#11111b"
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 15
        bottomRightRadius: 15
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

    // Mirror the tray's curved shoulders so the popup stack grows out of the
    // topbar rather than appearing as a detached rectangle.
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
