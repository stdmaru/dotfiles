pragma Singleton

import qs.controllers
import Quickshell
import Quickshell.Hyprland

// Estado do lançador de aplicativos: aberto/fechado, em qual monitor e de
// que forma ele aparece.
Singleton {
    id: root

    property bool open: false
    property ShellScreen screen: null
    // Preso à barra ou, sem barra à vista, como cartão flutuante. Decidido
    // ao abrir para não mudar de forma no meio da animação.
    property bool attached: true
    // Quanto do lançador está à mostra (0 a 1), para a barra acompanhar.
    property real progress: 0

    function toggle(): void {
        if (root.open) {
            close()
            return
        }
        if (Session.locked)
            return
        root.show(Hyprland.focusedWorkspace?.hasFullscreen ?? false)
    }

    function close(): void {
        root.open = false
    }

    function show(fullscreen: bool): void {
        root.screen = Screens.byName(Hyprland.focusedMonitor?.name ?? "") ?? Screens.primary
        if (!root.screen)
            return

        // Um aplicativo em tela cheia cobre a barra; brotar dela ficaria solto.
        root.attached = Screens.isPrimary(root.screen) && !fullscreen
        root.open = true
    }
}
