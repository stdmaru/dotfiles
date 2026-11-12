pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import qs.modules.bar
import qs.modules.notifications
import Quickshell
import Quickshell.Wayland
import QtQuick

// Camada transparente em tela cheia de um monitor. Desenha a moldura (modo
// moldura) e, no monitor principal, a barra e tudo que brota dela (popups,
// painel, menus). A máscara de entrada deixa passar cliques fora desses
// elementos.
PanelWindow {
  id: win

  required property ShellScreen modelData
  readonly property bool isPrimary: Screens.isPrimary(modelData)
  readonly property var layer: layerLoader.item
  readonly property real barHeight: layer ? layer.bar.y + layer.bar.height : 0
  // Altura da faixa superior da moldura: a barra no principal, a espessura
  // da moldura nos demais.
  readonly property real frameTop: isPrimary ? Config.bar_bottom : Config.frame_thickness

  screen: modelData
  visible: isPrimary || Config.frame_enabled
  color: "transparent"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "quickshell-shell"

  mask: Region {
    ItemRegion { target: win.layer?.bar ?? null }
    ItemRegion { target: win.layer?.popups ?? null }
    ItemRegion { target: win.layer?.tray ?? null }
    ItemRegion { target: win.layer?.trayMenu ?? null }
  }

  // Espaço que as janelas do Hyprland não ocupam. Cada borda é uma janela à
  // parte porque esta camada ignora zonas exclusivas. Flutuante, só a barra
  // reserva o topo; no modo moldura, as quatro bordas reservam a moldura.
  ReservedEdge {
    targetScreen: win.modelData
    edge: "top"
    active: win.isPrimary || Config.frame_enabled
    size: Config.frame_enabled ? win.frameTop : win.barHeight
  }
  ReservedEdge { targetScreen: win.modelData; edge: "left"; active: Config.frame_enabled; size: Config.frame_thickness }
  ReservedEdge { targetScreen: win.modelData; edge: "right"; active: Config.frame_enabled; size: Config.frame_thickness }
  ReservedEdge { targetScreen: win.modelData; edge: "bottom"; active: Config.frame_enabled; size: Config.frame_thickness }

  Loader {
    anchors.fill: parent
    active: Config.frame_enabled
    sourceComponent: ScreenFrame {
      topBand: win.frameTop
    }
  }

  Loader {
    id: layerLoader
    anchors.fill: parent
    active: win.isPrimary

    sourceComponent: Item {
      readonly property alias bar: bar
      readonly property alias popups: popups
      readonly property alias tray: tray
      readonly property alias trayMenu: trayMenu

      Bar {
        id: bar
        parentWindow: win
        trayMenu: trayMenu
        visible: !Session.locked || Session.barVisibleWhileLocked
      }

      NotificationPopups {
        id: popups
        attachedTo: bar
      }

      NotificationTray {
        id: tray
        attachedBar: bar
      }

      TrayMenu {
        id: trayMenu
        parentWindow: win
      }
    }
  }

  // Região de entrada que acompanha um item e some quando ele está oculto.
  component ItemRegion: Region {
    property Item target: null

    x: target?.x ?? 0
    y: target?.y ?? 0
    width: target?.visible ? target.width : 0
    height: target?.visible ? target.height : 0
  }
}
