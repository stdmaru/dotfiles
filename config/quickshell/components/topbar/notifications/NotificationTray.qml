pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import QtQuick
import QtQuick.Shapes
import QtQuick.Controls

Item {
    id: root

    required property Item attachedBar;
    property bool hasNotifications: Notifications.hasUnread()

    property bool isOpen: true

    width: 1920
    height: 1080
    visible: (background.height > 0) ? true : false

    MouseArea {
        id: overlayArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: () => {
            Notifications.trayOpen = false
        }
    }

    Rectangle {
        id: background
        y: root.attachedBar.height - 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: -5
        width: 550
        height: (Notifications.trayOpen && root.hasNotifications) ? notificationList.contentHeight + 20 :
                (Notifications.trayOpen && !root.hasNotifications) ? 150 : 0
        color: '#11111b'
        bottomLeftRadius: 20
        bottomRightRadius: 20

        Rectangle {
            id: notificationContainer
            width: background.width - 20
            height: background.height - 20
            anchors.centerIn: background
            clip: true
            color: 'transparent'

            ListView {
                id: notificationList
                anchors.fill: notificationContainer
                model: Notifications.all
                clip: true
                delegate: Loader {
                    id: loader
                    required property var modelData

                    sourceComponent: NotificationItem {
                        id: notification;
                        scene: "tray";
                        modelData: loader.modelData
                        width: notificationContainer.width;
                    }
                }
            }

            Rectangle {
                opacity: (!root.hasNotifications) ? 1 : 0
                anchors.top: parent.top
                anchors.topMargin: 65
                width: parent.width

                Text {
                    anchors.bottom: no_notifications_text.top
                    anchors.bottomMargin: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: "Font Awesome 7 Free"
                    font.pointSize: 20
                    color: "white"
                    text: ""
                }

                Text {
                    id: no_notifications_text
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.family: Config.main_font
                    font.pointSize: 14
                    color: "white"
                    text: "Sem notificações"
                }

                Behavior on opacity {
                    NumberAnimation { duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
                }
            }
        }

        // Top left corner
        Shape {
            id: shape_left

            // User defined
            property double rounding: 20
            property double roundingSize: (rounding > background.height / 2) ? background.height / 2 : rounding // Corner cannot be bigger than height / 2

            // Altura e largura da borda, para uma curvatura perfeita, definir a proporção 1:1
            property double lineSizeX: roundingSize // Largura da borda
            property double lineSizeY: roundingSize // Altura da borda

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: background.color

                // ponto inicial: canto superior esquerdo
                startX: 0
                startY: 0

                // linha para a esquerda de 20px
                PathLine {
                    relativeX: -shape_left.lineSizeX
                    relativeY: 0
                }

                // Linha para baixo-direita de 20px, aplicando arredondamento de 20px
                PathArc {
                    relativeX: shape_left.lineSizeX
                    relativeY: shape_left.lineSizeY
                    radiusX: shape_left.roundingSize
                    radiusY: shape_left.roundingSize
                }

                // linha para cima de 20px
                PathLine {
                    relativeX: 0
                    relativeY: -shape_left.lineSizeY
                }
            }
        }

        // Top right corner
        Shape {
            id: shape_right
            // User defined
            property double rounding: 20
            property double roundingSize: (rounding > background.height / 2) ? background.height / 2 : rounding

            // Altura e largura da borda, para uma curvatura perfeita, definir a proporção 1:1
            property double lineSizeX: roundingSize // Largura da borda
            property double lineSizeY: roundingSize // Altura da borda

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: background.color

                // ponto inicial: canto superior direito
                startX: background.width
                startY: 0

                // linha para a direita de 20px
                PathLine {
                    relativeX: shape_right.lineSizeX
                    relativeY: 0
                }

                // Linha para baixo-esquerda de 20px, aplicando arredondamento de 20px
                PathArc {
                    relativeX: -shape_right.lineSizeX
                    relativeY: shape_right.lineSizeY
                    radiusX: shape_right.roundingSize
                    radiusY: shape_right.roundingSize
                    direction: PathArc.Counterclockwise
                }

                // linha para cima de 20px
                PathLine {
                    relativeX: 0
                    relativeY: -shape_right.lineSizeY
                }
            }
        }

        Behavior on height {
            NumberAnimation{ duration: 600; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.05, 0.7, 0.1, 1, 1, 1] }
        }
    }

    // Bloqueador de cliques
    MouseArea {
        z: -1
        anchors.fill: background
        acceptedButtons: Qt.AllButtons
        onClicked: {}
    }
}