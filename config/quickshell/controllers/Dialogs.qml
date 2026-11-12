pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.controllers

Singleton {
    id: root

    property bool open: false
    property string mode: "notice"
    property string title: ""
    property string message: ""
    property string icon: ""
    property string iconColor: Theme.blue
    property string targetScreenName: Screens.primaryName
    property var options: []
    property var fields: []
    property var values: ({})
    property bool openPending: false
    // Chamado uma única vez com (value, inputValues) quando o usuário escolhe
    // uma opção; descartado se o diálogo for fechado sem escolha.
    property var acceptCallback: null

    signal accepted(var value, var inputValues)
    signal rejected()

    Process {
        id: cursorPosition
        command: ["hyprctl", "cursorpos"]

        stdout: StdioCollector {
            id: cursorOutput
        }

        onExited: (exitCode, exitStatus) => root.finishOpen(exitCode, cursorOutput.text)
    }

    function normalizeOptions(options, defaults): var {
        const source = options && options.length ? options : defaults
        return source.map((option, index) => {
            if (typeof option === "string")
                return { text: option, value: option, role: index === source.length - 1 ? "primary" : "normal" }

            return {
                text: String(option.text ?? option.label ?? "Opção"),
                value: option.value ?? option.id ?? option.text ?? option.label ?? index,
                role: String(option.role ?? (index === source.length - 1 ? "primary" : "normal"))
            }
        })
    }

    function prepare(kind, dialogTitle, dialogMessage, dialogIcon, dialogIconColor, onAccept): void {
        root.acceptCallback = typeof onAccept === "function" ? onAccept : null
        root.mode = kind
        root.title = dialogTitle || ""
        root.message = dialogMessage || ""
        root.icon = String(dialogIcon || "")
        root.iconColor = String(dialogIconColor || Theme.blue)
        root.targetScreenName = Hyprland.focusedMonitor?.name ?? Screens.primaryName
        root.values = ({})
        root.openPending = true
    }

    function beginOpen(): void {
        if (cursorPosition.running)
            return
        cursorPosition.running = true
    }

    function finishOpen(exitCode, cursorText): void {
        if (!root.openPending)
            return

        // Abre no monitor onde o cursor está; as telas do Quickshell já
        // consideram a rotação, ao contrário do tamanho bruto do monitor.
        if (exitCode === 0) {
            const match = String(cursorText).trim().match(/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/)
            const screen = match ? Screens.at(Number(match[1]), Number(match[2])) : null
            if (screen)
                root.targetScreenName = screen.name
        }
        if (!Screens.byName(root.targetScreenName))
            root.targetScreenName = Screens.primaryName

        root.openPending = false
        root.open = true
    }

    function showNotice(message, title, icon, iconColor, onAccept): void {
        root.prepare("notice", title || "Aviso", message, icon, iconColor, onAccept)
        root.fields = []
        root.options = root.normalizeOptions([], [{ text: "OK", value: "ok", role: "primary" }])
        root.beginOpen()
    }

    function showPrompt(message, options, title, icon, iconColor, onAccept): void {
        root.prepare("prompt", title || "Confirmação", message, icon, iconColor, onAccept)
        root.fields = []
        root.options = root.normalizeOptions(options, [
            { text: "Cancelar", value: "cancel", role: "normal" },
            { text: "OK", value: "ok", role: "primary" }
        ])
        root.beginOpen()
    }

    function showInputs(message, fields, options, title, icon, iconColor, onAccept): void {
        root.prepare("input", title || "Entrada", message, icon, iconColor, onAccept)
        const initialValues = ({})
        const normalizedFields = (fields || []).map((field, index) => {
            const key = String(field.key ?? field.id ?? `field${index + 1}`)
            const value = String(field.value ?? "")
            initialValues[key] = value
            return {
                key: key,
                label: String(field.label ?? ""),
                placeholder: String(field.placeholder ?? ""),
                password: Boolean(field.password),
                value: String(field.value ?? "")
            }
        })
        root.fields = normalizedFields
        root.values = initialValues
        root.options = root.normalizeOptions(options, [
            { text: "Cancelar", value: "cancel", role: "normal" },
            { text: "Confirmar", value: "confirm", role: "primary" }
        ])
        root.beginOpen()
    }

    function setInputValue(key, value): void {
        const nextValues = Object.assign({}, root.values)
        nextValues[key] = value
        root.values = nextValues
    }

    function choose(option): void {
        if (!root.open)
            return
        const callback = root.acceptCallback
        const inputValues = Object.assign({}, root.values)
        root.acceptCallback = null
        root.open = false
        root.accepted(option.value, inputValues)
        callback?.(option.value, inputValues)
    }

    function close(): void {
        root.acceptCallback = null
        if (root.openPending) {
            root.openPending = false
            return
        }
        if (!root.open)
            return
        root.open = false
        root.rejected()
    }
}
