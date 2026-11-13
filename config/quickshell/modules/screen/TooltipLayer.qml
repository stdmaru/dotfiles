import qs.config
import qs.controllers
import Quickshell
import Quickshell.Wayland
import QtQuick

// Dica dos controles da barra (estado em TooltipManager). Fica numa camada
// própria, criada só enquanto a dica aparece: como é a superfície mais nova
// da camada Overlay, fica acima dos painéis que brotam da barra (menus,
// lançador) em vez de por trás deles.
PanelWindow {
  id: tipWindow

  screen: Screens.primary
  visible: TooltipManager.shown
  color: "transparent"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell-tooltip"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  // Não recebe nenhum clique.
  mask: Region {}

  Rectangle {
    id: bubble

    readonly property rect anchorRect: TooltipManager.anchorRect

    width: Math.min(320, Math.max(96, textMetrics.advanceWidth + 24))
    height: label.implicitHeight + 18
    x: Math.max(4, Math.min(tipWindow.width - width - 4,
      Math.round(anchorRect.x + (anchorRect.width - width) / 2)))
    y: anchorRect.y + anchorRect.height + 7
    radius: Theme.radius_s
    color: Qt.rgba(Theme.mantle.r, Theme.mantle.g, Theme.mantle.b, 0.975)
    border.width: 1
    border.color: Theme.outline
    opacity: TooltipManager.opacity

    TextMetrics {
      id: textMetrics
      text: TooltipManager.longestLine(TooltipManager.activeText)
      font.family: Theme.font_ui
      font.pixelSize: 12
      font.weight: Font.Medium
    }

    Text {
      id: label
      anchors.centerIn: parent
      width: bubble.width - 24
      text: TooltipManager.activeText
      color: Theme.text
      font.family: Theme.font_ui
      font.pixelSize: 12
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.Wrap
    }
  }
}
