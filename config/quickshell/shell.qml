//@ pragma IconTheme AdwaitaLegacy
// O text-input-v3 do Qt perde o rastro da superfície focada sempre que uma
// janela com campo de texto some, e passa a avisar em todo enable/disable.
// Sem método de entrada (fcitx/ibus) ele não serve para nada; o módulo
// "compose" mantém as teclas mortas (´ + a = á) via xkb.
//@ pragma Env QT_IM_MODULE=compose

pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import qs.modules.dialogs
import qs.modules.launcher
import qs.modules.lock
import qs.modules.screen
import qs.modules.settings
import Quickshell
import Quickshell.Io
import QtQuick

// Ponto de entrada: apenas compõe os módulos. O estado vive nos singletons de
// controllers/ e cada módulo desenha a sua parte.
ShellRoot {
  // Área de trabalho (clique direito abre o menu contextual).
  Variants {
    model: Quickshell.screens

    DesktopLayer {
      required property ShellScreen modelData
      targetScreen: modelData
    }
  }

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

  // Dica dos controles da barra, acima dos painéis.
  TooltipLayer {}

  // Menu contextual (ContextMenu), acima de tudo.
  Variants {
    model: Quickshell.screens

    ContextMenuLayer {
      required property ShellScreen modelData
      targetScreen: modelData
    }
  }

  Lock {}

  // Janela de configurações; só existe enquanto está aberta.
  LazyLoader {
    active: Settings.open
    SettingsWindow {}
  }

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
    function toggleDnd(): void { Preferences.notifications.doNotDisturb = !Preferences.notifications.doNotDisturb }
  }

  IpcHandler {
    target: "settings"
    function toggle(): void { Settings.toggle() }
    function open(category: string): void { Settings.show(category) }
    function close(): void { Settings.close() }
  }

  IpcHandler {
    target: "theme"
    function set(id: string): void { Preferences.set("appearance", "theme", id) }
    function get(): string { return Preferences.appearance.theme }
    // Passa para o próximo tema da lista.
    function cycle(): void {
      const themes = Theme.themes
      const index = themes.findIndex(theme => theme.id === Preferences.appearance.theme)
      Preferences.set("appearance", "theme", themes[(index + 1) % themes.length].id)
    }
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
