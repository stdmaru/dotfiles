//@ pragma IconTheme AdwaitaLegacy

pragma ComponentBehavior: Bound

import qs.controllers
import qs.modules.dialogs
import qs.modules.launcher
import qs.modules.lock
import qs.modules.screen
import Quickshell
import Quickshell.Io
import QtQuick

// Ponto de entrada: apenas compõe os módulos. O estado vive nos singletons de
// controllers/ e cada módulo desenha a sua parte.
ShellRoot {
  // Barra, popups e painel (monitor principal) e moldura (todos).
  Variants {
    model: Quickshell.screens
    ScreenWindow {}
  }

  Variants {
    model: Quickshell.screens

    AppLauncher {
      required property ShellScreen modelData
      targetScreen: modelData
    }
  }

  // Estado de diálogo único, com um escudo de entrada em cada monitor.
  Variants {
    model: Quickshell.screens

    DialogBox {
      required property ShellScreen modelData
      targetScreen: modelData
    }
  }

  Lock {}

  // quickshell ipc call <target> <função>
  IpcHandler {
    target: "launcher"
    function toggle(): void { Launcher.toggle() }
    function close(): void { Launcher.close() }
  }

  IpcHandler {
    target: "notifications"
    function toggle(): void {
      if (!Session.locked)
        Notifications.trayOpen = !Notifications.trayOpen
    }
    function clear(): void { Notifications.clearAll() }
    function toggleDnd(): void { Notifications.doNotDisturb = !Notifications.doNotDisturb }
  }

  IpcHandler {
    target: "session"
    function lock(): void { Session.lock() }
    function suspend(): void { Session.suspend() }
  }

  Component.onCompleted: {
    Hypr.init()
    Weather.init()
    Network.init()
    Notifications.init()
  }
}
