import qs.config
import QtQuick
import QtQuick.Shapes

// Moldura do modo moldura (Config.frame_enabled): uma única forma que cobre a
// tela inteira menos um recorte de cantos arredondados, onde ficam as janelas.
// A faixa superior tem a altura da barra no monitor principal, então a barra
// é parte da moldura em vez de um retângulo à parte.
Shape {
  id: root

  // Altura da faixa superior.
  property real topBand: Config.frame_thickness
  readonly property real side: Config.frame_thickness
  readonly property real radius: Math.max(0, Math.min(Config.frame_corner_radius,
    (hole.right - hole.left) / 2, (hole.bottom - hole.top) / 2))

  // Recorte por onde as janelas aparecem.
  readonly property QtObject hole: QtObject {
    readonly property real left: root.side
    readonly property real top: root.topBand
    readonly property real right: root.width - root.side
    readonly property real bottom: root.height - root.side
  }

  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    fillColor: Theme.crust
    strokeColor: "transparent"
    // O recorte é um segundo contorno dentro do primeiro.
    fillRule: ShapePath.OddEvenFill

    // Borda externa: a tela inteira.
    startX: 0
    startY: 0
    PathLine { x: root.width; y: 0 }
    PathLine { x: root.width; y: root.height }
    PathLine { x: 0; y: root.height }
    PathLine { x: 0; y: 0 }

    // Recorte arredondado.
    PathMove { x: root.hole.left + root.radius; y: root.hole.top }
    PathLine { x: root.hole.right - root.radius; y: root.hole.top }
    PathArc {
      x: root.hole.right; y: root.hole.top + root.radius
      radiusX: root.radius; radiusY: root.radius
    }
    PathLine { x: root.hole.right; y: root.hole.bottom - root.radius }
    PathArc {
      x: root.hole.right - root.radius; y: root.hole.bottom
      radiusX: root.radius; radiusY: root.radius
    }
    PathLine { x: root.hole.left + root.radius; y: root.hole.bottom }
    PathArc {
      x: root.hole.left; y: root.hole.bottom - root.radius
      radiusX: root.radius; radiusY: root.radius
    }
    PathLine { x: root.hole.left; y: root.hole.top + root.radius }
    PathArc {
      x: root.hole.left + root.radius; y: root.hole.top
      radiusX: root.radius; radiusY: root.radius
    }
  }
}
