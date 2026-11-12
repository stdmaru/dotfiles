pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    function init() {
        console.info("Hyprland daemon started")
    }

    function windowExists(address: string): bool {
        const targetAddress = String(address).replace(/^0x/i, "").toLowerCase()
        if (!targetAddress)
            return false

        for (const win of Hyprland.toplevels.values) {
            if (String(win.address).replace(/^0x/i, "").toLowerCase() === targetAddress)
                return true
        }
        return false
    }

    function dispatchToWindow(address: string) {
        const targetAddress = String(address).replace(/^0x/i, "").toLowerCase()
        if (!targetAddress)
            return

        const window = Hyprland.toplevels.values.find(win =>
            String(win.address).replace(/^0x/i, "").toLowerCase() === targetAddress
        )
        if (!window)
            return

        const monitor = window.monitor ?? window.workspace?.monitor
        if (monitor?.name && Hyprland.focusedMonitor?.name !== monitor.name)
            Hyprland.dispatch(Hyprland.usingLua
                ? `hl.dsp.focus({ monitor = "${monitor.name}" })`
                : `focusmonitor ${monitor.name}`)

        // Focusing only the window address can leave the user on the old
        // workspace. Activate its workspace first, then focus the client.
        if (window.workspace && !window.workspace.focused)
            window.workspace.activate()

        const windowSelector = `address:0x${targetAddress}`
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.focus({ window = "${windowSelector}" })`
            : `focuswindow ${windowSelector}`)
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name.endsWith("v2"))
                return;
            
            if (event.name === "urgent" ) {
                root.dispatchToWindow(event.data)
            } else if (event.name === "configreloaded") {
                //root.configReloaded();
                //root.reloadDynamicConfs();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(event.name)) {
                //Hyprland.refreshWorkspaces();
                //Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(event.name)) {
                //Hyprland.refreshToplevels();
                //Hyprland.refreshWorkspaces();
            } else if (event.name.includes("mon")) {
                //Hyprland.refreshMonitors();
            } else if (event.name.includes("workspace")) {
                //Hyprland.refreshWorkspaces();
            } else if (event.name.includes("window") || event.name.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(event.name)) {
                //Hyprland.refreshToplevels();
            }
        }
    }
}
