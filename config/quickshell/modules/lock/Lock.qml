pragma ComponentBehavior: Bound

import qs.controllers
import Quickshell
import Quickshell.Wayland
import QtQuick

// Parte visual do bloqueio de sessão; o estado vive em controllers/Session.
Scope {
  id: root

  WlSessionLock {
    id: sessionLock
    locked: Session.locked
    onSecureChanged: Session.surfaceSecure = secure

    surface: Component {
      LockSurface {}
    }
  }

  // Uma superfície de session-lock não aceita pedido de blur, então o blur do
  // compositor fica em uma layer-surface comum, em tela cheia, logo abaixo.
  // (regra "quickshell-lock-blur" no hyprland.lua)
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: blurWindow
      required property ShellScreen modelData

      screen: modelData
      visible: Session.locked && Session.blurVisible && Session.surfaceSecure
      color: "transparent"
      focusable: false
      aboveWindows: true
      exclusionMode: ExclusionMode.Ignore
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }
      mask: Region {}
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell-lock-blur"
      BackgroundEffect.blurRegion: Region { item: blurArea }

      Item {
        id: blurArea
        anchors.fill: parent
      }
    }
  }
}
