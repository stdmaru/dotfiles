import qs.config
import QtQuick
import QtQuick.Shapes

// Fundo de um painel que brota da barra, desenhado como uma única forma:
// rampas côncavas no topo e cantos arredondados embaixo.
//
// As rampas e os cantos encolhem junto com a altura, de modo que ao fechar o
// painel se achata em uma curva contínua até sumir na barra, sem quinas.
// O item ocupa o retângulo do painel; as rampas são desenhadas para fora dele.
Shape {
    id: root

    property color color: Theme.crust
    // Tamanho máximo das rampas e dos cantos inferiores.
    property real shoulder: Config.notification_panel_emergence
    property real cornerRadius: Theme.radius_l

    // Rampa e canto dividem a altura disponível.
    readonly property real s: Math.max(0, Math.min(shoulder, height / 2))
    readonly property real c: Math.max(0, Math.min(cornerRadius, height / 2))

    visible: height > 0.5
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        startX: -root.s
        startY: 0

        // Rampa esquerda
        PathArc {
            x: 0; y: root.s
            radiusX: root.s; radiusY: root.s
            direction: PathArc.Clockwise
        }
        PathLine { x: 0; y: root.height - root.c }
        // Canto inferior esquerdo
        PathArc {
            x: root.c; y: root.height
            radiusX: root.c; radiusY: root.c
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.c; y: root.height }
        // Canto inferior direito
        PathArc {
            x: root.width; y: root.height - root.c
            radiusX: root.c; radiusY: root.c
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width; y: root.s }
        // Rampa direita
        PathArc {
            x: root.width + root.s; y: 0
            radiusX: root.s; radiusY: root.s
            direction: PathArc.Clockwise
        }
        PathLine { x: -root.s; y: 0 }
    }
}
