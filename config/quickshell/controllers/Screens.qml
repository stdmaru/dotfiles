pragma Singleton

import qs.config
import Quickshell

// Resolve qual monitor hospeda a barra e os demais widgets principais.
Singleton {
    id: root

    readonly property string primaryName: {
        const names = Quickshell.screens.map(screen => screen.name)
        return names.includes(Config.primary_screen)
            ? Config.primary_screen
            : (names[0] ?? "")
    }

    readonly property ShellScreen primary:
        Quickshell.screens.find(screen => screen.name === root.primaryName) ?? null

    function isPrimary(screen): bool {
        return !!screen && screen.name === root.primaryName
    }

    function byName(name: string): ShellScreen {
        return Quickshell.screens.find(screen => screen.name === name) ?? null
    }

    // Monitor que contém o ponto (coordenadas globais do compositor).
    function at(x: real, y: real): ShellScreen {
        return Quickshell.screens.find(screen =>
            x >= screen.x && x < screen.x + screen.width
            && y >= screen.y && y < screen.y + screen.height
        ) ?? null
    }
}
