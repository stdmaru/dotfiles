import qs.config
import qs.components.common
import QtQuick
import Quickshell.Hyprland

pragma ComponentBehavior: Bound

Row {
    id: root
    spacing: 3
    anchors.verticalCenter: parent.verticalCenter

    // CONFIG
    property bool showAll: Config.workspaces_showAll
    property int maxWorkspaces: Config.workspaces_max
    property var labels: Config.workspaces_labels

    // Helpers
    function workspaceIds() {
        return Hyprland.workspaces.values.map(ws => ws.id)
    }

    function workspaceById(id) {
        return Hyprland.workspaces.values.find(ws => ws.id === id)
    }

    function dispatchWorkspace(id) {
        const request = Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = ${id} })`
            : `workspace ${id}`
        Hyprland.dispatch(request)
    }

    function isWorkspaceEmpty(ws) {
        return ws
            && ws.toplevels
            && ws.toplevels.values.length === 0
    }

    function isWorkspaceInRange(ws) {
        return ws.id >= 1 && ws.id <= maxWorkspaces
    }

    function firstFreeWorkspace() {
        const used = workspaceIds()

        for (let id = 1; id <= maxWorkspaces; id++) {
            if (!used.includes(id))
                return id
        }

        return null
    }

    function existsEmptyWorkspace() {
        return Hyprland.workspaces.values.some(ws =>
            isWorkspaceInRange(ws) && isWorkspaceEmpty(ws)
        )
    }

    property var workspaceModel: {
        // MODO: mostrar todos (1..maxWorkspaces)
        if (showAll) {
            return Array.from({ length: maxWorkspaces }, (_, i) => {
                const id = i + 1
                return {
                    id,
                    real: workspaceById(id) ?? null
                }
            })
        }

        // MODO: dinâmico (não vazias + atual)
        const focusedId = Hyprland.focusedWorkspace
            ? Hyprland.focusedWorkspace.id
            : null

        return Hyprland.workspaces.values
            .filter(ws =>
                isWorkspaceInRange(ws) &&
                (
                    !isWorkspaceEmpty(ws) ||
                    ws.id === focusedId
                )
            )
            .map(ws => ({
                id: ws.id,
                real: ws
            }))
    }

    // WORKSPACES
    Repeater {
        model: root.workspaceModel

        delegate: Button {
            required property var modelData

            height: 22
            leftPadding: 5
            rightPadding: 5
            fontSize: 14

            text: root.labels[modelData.id] ?? String(modelData.id)
            // Workspaces sem janelas ficam esmaecidas.
            opacity: active || !root.isWorkspaceEmpty(modelData.real ?? { toplevels: { values: [] } }) ? 1 : 0.45
            active: Hyprland.focusedWorkspace?.id === modelData.id
            onClicked: {
                if (!Hyprland.focusedWorkspace
                    || Hyprland.focusedWorkspace.id !== modelData.id)
                    root.dispatchWorkspace(modelData.id)
            }
        }
    }

    // BOTÃO "+"
    Button {
        visible: !root.showAll
              && root.firstFreeWorkspace() !== null
              && !root.existsEmptyWorkspace()
        height: 22
        leftPadding: 8
        rightPadding: 8
        text: "+"

        onClicked: {
            const ws = root.firstFreeWorkspace()
            if (ws !== null)
                root.dispatchWorkspace(ws)
        }
    }
}
