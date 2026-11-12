pragma Singleton

import qs.controllers
import Quickshell
import Quickshell.Hyprland

// Estado do lançador de aplicativos: aberto/fechado e em qual monitor.
Singleton {
    id: root

    property bool open: false
    property ShellScreen screen: null

    function toggle(): void {
        if (root.open) {
            close()
            return
        }
        if (Session.locked)
            return

        root.screen = Screens.byName(Hyprland.focusedMonitor?.name ?? "") ?? Screens.primary
        if (root.screen)
            root.open = true
    }

    function close(): void {
        root.open = false
    }
}
