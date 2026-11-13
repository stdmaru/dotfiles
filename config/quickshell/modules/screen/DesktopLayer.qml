import qs.controllers
import Quickshell
import Quickshell.Wayland
import QtQuick

// Área de trabalho: camada transparente entre o papel de parede e as janelas,
// que recebe os cliques onde não há janela.
PanelWindow {
  id: win

  required property ShellScreen targetScreen

  screen: targetScreen
  color: "transparent"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "quickshell-desktop"

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    onPressed: mouse => ContextMenu.show(win.targetScreen, mouse.x, mouse.y, [
      { text: "Configurações", icon: "", action: () => Settings.show("") }
    ])
  }
}
