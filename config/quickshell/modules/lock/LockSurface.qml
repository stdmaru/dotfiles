pragma ComponentBehavior: Bound

import qs.controllers
import Quickshell.Wayland
import QtQuick

// Superfície de bloqueio de um monitor. Todas cobrem a tela e mostram o
// relógio; apenas a do monitor principal mostra o cartão de login.
WlSessionLockSurface {
  id: root

  color: "transparent"

  LockContent {
    anchors.fill: parent
    showLogin: Screens.isPrimary(root.screen)
  }
}
