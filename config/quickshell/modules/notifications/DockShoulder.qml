import qs.config
import QtQuick
import QtQuick.Shapes

// Curva côncava que une um painel à barra, fazendo-o parecer brotar dela.
// Fica encostada no canto superior do painel: à esquerda, ou à direita quando
// `mirrored`.
Shape {
    id: root

    property bool mirrored: false
    // 0 = recolhida, 1 = totalmente formada.
    property real progress: 1
    property color color: Theme.crust

    function fx(value: real): real {
        return root.mirrored ? root.width - value : value
    }

    width: Config.notification_panel_emergence
    height: Config.notification_panel_emergence * Math.max(0, Math.min(1, progress))
    visible: width > 0 && height > 0

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        startX: root.fx(0)
        startY: 0
        PathCubic {
            x: root.fx(root.width); y: root.height
            control1X: root.fx(root.width * 0.5523); control1Y: 0
            control2X: root.fx(root.width); control2Y: root.height * 0.4477
        }
        PathLine { x: root.fx(root.width); y: 0 }
    }
}
