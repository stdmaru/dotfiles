pragma ComponentBehavior: Bound

import qs.controllers
import QtQuick
import QtQuick.Shapes

Item {
    id: root
    required property Item attachedTo

    // Âncoras do container invisível
    anchors.horizontalCenter: attachedTo.horizontalCenter
    anchors.top: attachedTo.bottom
    anchors.topMargin: -5
    
    width: 470
    height: background.height
    
    Rectangle {
        id: background
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        color: "#11111b"
        bottomLeftRadius: 15
        bottomRightRadius: 15
        clip: true
        height: (listView.contentHeight > 0) ? listView.contentHeight + 10 : 0

        ListView {
            id: listView
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.width - 20
            height: 1080 // FIXME
            
            model: Notifications.all
            interactive: false
            clip: true
            
            delegate: Loader {
                id: loader
                required property var modelData
                
                sourceComponent: NotificationItem {
                    scene: "popup";
                    modelData: loader.modelData
                    width: listView?.width ?? 0;
                }
            }

            // --- TRANSIÇÕES ---
            add: Transition {
                ParallelAnimation {
                    NumberAnimation {properties: "x"; from: listView.width; to: 0; duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]}
                    NumberAnimation {properties: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]}
                }
            }
            displaced: Transition {
                ParallelAnimation {
                    NumberAnimation {property: "y"; duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]}
                    NumberAnimation {property: "opacity"; to: 1; duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
                }
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

    // Bloqueador de cliques
    MouseArea {
        z: -1
        anchors.fill: background
        acceptedButtons: Qt.AllButtons
        onClicked: {}
    }
}