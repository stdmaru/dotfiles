import qs.config
import QtQuick
import QtQuick.Shapes

// Fundo de um painel que brota da barra, desenhado como uma única forma. O
// item ocupa o retângulo do painel; rampas e filetes são desenhados para fora
// dele. Cada lateral tem um tipo:
//
// - "ramp": rampa côncava ligando o topo do painel à barra, trecho vertical e
//   canto inferior arredondado. Com o painel baixo, os dois arcos perdem
//   altura e a junção se inclina: quanto mais fechado, mais rasa a curva, e o
//   painel termina como uma lâmina que se dissolve na barra.
// - "flush": a lateral continua reta a borda da barra (o canto da barra fica
//   reto enquanto o painel está aberto) e termina num canto arredondado.
// - "border": a lateral se funde à borda da moldura e termina num filete
//   côncavo descendo por ela. Fechado, o filete é idêntico ao canto do recorte
//   da moldura, então o painel brota dele sem salto.
Shape {
    id: root

    property color color: Theme.crust
    property string leftEdge: "ramp"
    property string rightEdge: "ramp"
    // Largura das rampas e raio dos cantos inferiores.
    property real shoulder: Config.panel_curve
    // Rampa e cantos de baixo usam o mesmo raio (Config.panel_curve).
    property real cornerRadius: shoulder
    // Raio do filete das laterais "border": o do recorte da moldura, para o
    // painel brotar dele sem salto.
    property real borderRadius: Config.frame_corner_radius

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

    // Segmentos da lateral esquerda, de cima para baixo, em coordenadas do
    // painel. Termina no começo da borda inferior.
    function sideSegments(edge: string): var {
        const h = root.height
        const r = root.cornerRadius
        const k = root.k

        if (edge === "flush") {
            // Canto que achata junto com o painel.
            const cf = Math.min(r, h)
            return [
                { from: [0, 0], to: [0, h - cf] },
                { from: [0, h - cf], c1: [0, h - cf + k * cf], c2: [r * (1 - k), h], to: [r, h] }
            ]
        }

        if (edge === "border") {
            // Filete côncavo: arco de centro (b, h + b).
            const b = root.borderRadius
            return [
                { from: [0, 0], to: [0, h + b] },
                { from: [0, h + b], c1: [0, h + b - k * b], c2: [b * (1 - k), h], to: [b, h] }
            ]
        }

        return [
            { from: [-root.shoulder, 0],
              c1: [-root.shoulder * (1 - k), 0],
              c2: [-root.dx * root.rampHandle, root.s - root.dy * root.rampHandle],
              to: [0, root.s] },
            { from: [0, root.s], to: [0, h - root.c] },
            { from: [0, h - root.c],
              c1: [root.dx * root.cornerHandle, h - root.c + root.dy * root.cornerHandle],
              c2: [r * (1 - k), h],
              to: [r, h] }
        ]
    }

    // A lateral direita é a esquerda espelhada e percorrida de baixo para cima.
    function mirrored(segments: var): var {
        const flip = point => [root.width - point[0], point[1]]
        return segments.slice().reverse().map(segment => ({
            from: flip(segment.to),
            c1: segment.c2 ? flip(segment.c2) : undefined,
            c2: segment.c1 ? flip(segment.c1) : undefined,
            to: flip(segment.from)
        }))
    }

    function svg(segments: var): string {
        return segments.map(segment => segment.c1
            ? `C ${segment.c1[0]} ${segment.c1[1]} ${segment.c2[0]} ${segment.c2[1]} ${segment.to[0]} ${segment.to[1]}`
            : `L ${segment.to[0]} ${segment.to[1]}`).join(" ")
    }

    readonly property string path: {
        const left = sideSegments(root.leftEdge)
        const right = mirrored(sideSegments(root.rightEdge))
        const start = left[0].from
        // Lateral esquerda, borda inferior, lateral direita e o topo de volta.
        return `M ${start[0]} ${start[1]} ${svg(left)} L ${right[0].from[0]} ${right[0].from[1]} ${svg(right)} Z`
    }

    // Uma lateral "border" continua desenhada fechada: é o canto da moldura.
    visible: height > 0.5 || leftEdge === "border" || rightEdge === "border"
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"

        PathSvg { path: root.path }
    }
}
