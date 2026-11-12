pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool open: false
    property string mode: "notice"
    property string title: ""
    property string message: ""
    property string icon: ""
    property string iconColor: "#89b4fa"
    property string targetScreenName: "DP-2"
    property var options: []
    property var fields: []
    property var values: ({})
    property bool openPending: false

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

    function prepare(kind, dialogTitle, dialogMessage, dialogIcon, dialogIconColor): void {
        root.mode = kind
        root.title = dialogTitle || ""
        root.message = dialogMessage || ""
        root.icon = String(dialogIcon || "")
        root.iconColor = String(dialogIconColor || "#89b4fa")
        root.targetScreenName = Hyprland.focusedMonitor?.name ?? "DP-2"
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

        if (exitCode === 0) {
            const match = String(cursorText).trim().match(/(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)/)
            if (match) {
                const x = Number(match[1])
                const y = Number(match[2])
                const monitor = Hyprland.monitors.values.find(item =>
                    x >= item.x && x < item.x + item.width
                    && y >= item.y && y < item.y + item.height
                )
                if (monitor)
                    root.targetScreenName = monitor.name
            }
        }

        root.openPending = false
        root.open = true
    }

    function showNotice(message, title, icon, iconColor): void {
        root.prepare("notice", title || "Aviso", message, icon, iconColor)
        root.fields = []
        root.options = root.normalizeOptions([], [{ text: "OK", value: "ok", role: "primary" }])
        root.beginOpen()
    }

    function showPrompt(message, options, title, icon, iconColor): void {
        root.prepare("prompt", title || "Confirmação", message, icon, iconColor)
        root.fields = []
        root.options = root.normalizeOptions(options, [
            { text: "Cancelar", value: "cancel", role: "normal" },
            { text: "OK", value: "ok", role: "primary" }
        ])
        root.beginOpen()
    }

    function showInputs(message, fields, options, title, icon, iconColor): void {
        root.prepare("input", title || "Entrada", message, icon, iconColor)
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
        root.open = false
        root.accepted(option.value, Object.assign({}, root.values))
    }

    function close(): void {
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
