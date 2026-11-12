pragma Singleton

import qs.config
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Ponto único para dispatchers do Hyprland, cobrindo a sintaxe Lua e a legada.
Singleton {
    id: root

    // Singletons são criados sob demanda; o shell chama init() para garantir
    // que o tratamento de eventos esteja ativo desde o início.
    function init(): void {}

    function normalizeAddress(address): string {
        return String(address ?? "").replace(/^0x/i, "").toLowerCase()
    }

    function findWindow(address): var {
        const target = normalizeAddress(address)
        if (!target)
            return null
        return Hyprland.toplevels.values.find(win =>
            normalizeAddress(win.address) === target) ?? null
    }

    function windowExists(address: string): bool {
        return findWindow(address) !== null
    }

    function focusMonitor(name: string): void {
        if (!name)
            return
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ monitor = "${name}" })`
            : `focusmonitor ${name}`)
    }

    function focusWorkspace(id: int): void {
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = ${id} })`
            : `workspace ${id}`)
    }

    function focusWindow(address: string): void {
        const selector = `address:0x${normalizeAddress(address)}`
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ window = "${selector}" })`
            : `focuswindow ${selector}`)
    }

    function exitSession(): void {
        Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit")
    }

    // Leva o usuário até a janela: monitor, workspace e por fim o foco.
    function dispatchToWindow(address: string): void {
        const window = findWindow(address)
        if (!window)
            return

        const monitor = window.monitor ?? window.workspace?.monitor
        if (monitor?.name && Hyprland.focusedMonitor?.name !== monitor.name)
            focusMonitor(monitor.name)

        // Focar apenas pelo endereço pode deixar o usuário na workspace
        // antiga; ative a workspace da janela antes.
        if (window.workspace && !window.workspace.focused)
            window.workspace.activate()

        focusWindow(address)
    }

    Connections {
        target: Hyprland
        enabled: Config.focus_urgent_windows

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "urgent")
                root.dispatchToWindow(event.data)
        }
    }
}
