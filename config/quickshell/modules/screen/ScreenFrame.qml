import qs.config
import QtQuick
import QtQuick.Shapes

// Moldura opcional ao redor da tela (Config.frame_enabled), com cantos
// internos arredondados. `topInset` é a altura ocupada pela barra, se houver.
Item {
  id: root

  property real topInset: 0
  readonly property real thickness: Config.frame_thickness
  readonly property real innerTop: topInset + thickness

  // Superior (abaixo da barra, quando ela existe)
  Rectangle { y: root.topInset; width: root.width; height: root.thickness; color: Config.frame_color }
  // Inferior
  Rectangle { y: root.height - root.thickness; width: root.width; height: root.thickness; color: Config.frame_color }
  // Esquerda
  Rectangle {
    y: root.innerTop
    width: root.thickness
    height: Math.max(0, root.height - root.innerTop - root.thickness)
    color: Config.frame_color
  }
  // Direita
  Rectangle {
    x: root.width - root.thickness
    y: root.innerTop
    width: root.thickness
    height: Math.max(0, root.height - root.innerTop - root.thickness)
    color: Config.frame_color
  }

  FrameCorner { x: root.thickness; y: root.innerTop }
  FrameCorner { x: root.width - root.thickness - width; y: root.innerTop; flipHorizontal: true }
  FrameCorner { x: root.thickness; y: root.height - root.thickness - height; flipVertical: true }
  FrameCorner {
    x: root.width - root.thickness - width
    y: root.height - root.thickness - height
    flipHorizontal: true
    flipVertical: true
  }

  component FrameCorner: Shape {
    id: corner

    property bool flipHorizontal: false
    property bool flipVertical: false

    width: Config.frame_corner_radius
    height: Config.frame_corner_radius
    antialiasing: true
    transform: Scale {
      xScale: corner.flipHorizontal ? -1 : 1
      yScale: corner.flipVertical ? -1 : 1
      origin.x: corner.width / 2
      origin.y: corner.height / 2
    }

    ShapePath {
      fillColor: Config.frame_color
      strokeColor: "transparent"
      startX: 0
      startY: corner.height
      PathLine { x: 0; y: 0 }
      PathLine { x: corner.width; y: 0 }
      PathCubic {
        x: 0
        y: corner.height
        control1X: corner.width * 0.4477
        control1Y: 0
        control2X: 0
        control2Y: corner.height * 0.4477
      }
    }
  }
}
