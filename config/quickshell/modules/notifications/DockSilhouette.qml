import qs.config
import QtQuick
import QtQuick.Shapes

// Fundo de um painel que brota da barra, desenhado como uma única forma:
// rampas côncavas no topo e cantos arredondados embaixo.
//
// Com o painel alto, cada lateral é rampa + trecho vertical + canto. Quando a
// altura não comporta mais os dois arcos, eles mantêm a largura e perdem só
// altura, e a junção entre eles deixa de ser vertical e se inclina. Quanto
// mais fechado, mais rasa a curva: o painel termina como uma lâmina que se
// dissolve na barra, sem degrau.
// O item ocupa o retângulo do painel; as rampas são desenhadas para fora dele.
Shape {
    id: root

    property color color: Theme.crust
    // Largura das rampas e raio dos cantos inferiores.
    property real shoulder: Config.notification_panel_emergence
    property real cornerRadius: Theme.radius_l

    readonly property real k: 0.5523   // aproximação de arco por Bézier
    // 0 = fechado, 1 = alto o bastante para os dois arcos completos.
    readonly property real fit: Math.max(0, Math.min(1, height / (shoulder + cornerRadius)))
    // Altura da rampa e do canto.
    readonly property real s: shoulder * fit
    readonly property real c: cornerRadius * fit
    // Quão vertical é a tangente na junção rampa/canto.
    readonly property real upright: fit * fit * (3 - 2 * fit)
    // Direção dessa tangente: da diagonal da curva (fechado) até a vertical.
    readonly property real chord: Math.hypot(shoulder + cornerRadius, height) || 1
    readonly property real tx: (shoulder + cornerRadius) / chord * (1 - upright)
    readonly property real ty: height / chord * (1 - upright) + upright
    readonly property real tn: Math.hypot(tx, ty) || 1
    readonly property real dx: tx / tn
    readonly property real dy: ty / tn
    readonly property real rampHandle: k * Math.hypot(shoulder * (1 - upright), s)
    readonly property real cornerHandle: k * Math.hypot(cornerRadius * (1 - upright), c)

    visible: height > 0.5
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        startX: -root.shoulder
        startY: 0

        // Rampa esquerda
        PathCubic {
            x: 0; y: root.s
            control1X: -root.shoulder * (1 - root.k); control1Y: 0
            control2X: -root.dx * root.rampHandle; control2Y: root.s - root.dy * root.rampHandle
        }
        PathLine { x: 0; y: root.height - root.c }
        // Canto inferior esquerdo
        PathCubic {
            x: root.cornerRadius; y: root.height
            control1X: root.dx * root.cornerHandle
            control1Y: root.height - root.c + root.dy * root.cornerHandle
            control2X: root.cornerRadius * (1 - root.k); control2Y: root.height
        }
        PathLine { x: root.width - root.cornerRadius; y: root.height }
        // Canto inferior direito
        PathCubic {
            x: root.width; y: root.height - root.c
            control1X: root.width - root.cornerRadius * (1 - root.k); control1Y: root.height
            control2X: root.width - root.dx * root.cornerHandle
            control2Y: root.height - root.c + root.dy * root.cornerHandle
        }
        PathLine { x: root.width; y: root.s }
        // Rampa direita
        PathCubic {
            x: root.width + root.shoulder; y: 0
            control1X: root.width + root.dx * root.rampHandle
            control1Y: root.s - root.dy * root.rampHandle
            control2X: root.width + root.shoulder * (1 - root.k); control2Y: 0
        }
        PathLine { x: -root.shoulder; y: 0 }
    }
}
