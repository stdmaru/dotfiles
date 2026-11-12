import Quickshell
import Quickshell.Wayland

// Faixa invisível que reserva espaço em uma borda do monitor: as janelas do
// Hyprland não a ocupam. Presa à borda e às duas vizinhas, a zona exclusiva
// vale só para ela.
PanelWindow {
  required property ShellScreen targetScreen
  // "top", "bottom", "left" ou "right".
  required property string edge
  property bool active: true
  property real size: 0

  screen: targetScreen
  visible: active && size > 0
  implicitWidth: 1
  implicitHeight: 1
  color: "transparent"
  mask: Region {}
  anchors {
    top: edge !== "bottom"
    bottom: edge !== "top"
    left: edge !== "right"
    right: edge !== "left"
  }
  exclusiveZone: size
  WlrLayershell.exclusionMode: ExclusionMode.Normal
  WlrLayershell.namespace: "quickshell-reserved"
}
