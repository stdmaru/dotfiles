pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import qs.config
import qs.controllers

PopupWindow {
    id: root

    required property PanelWindow parentWindow
    required property var sessionController

    readonly property int panelWidth: 360
    property string menuType: ""
    property string previousMenuType: ""
    property bool isOpen: false
    property bool focusGrabEnabled: true
    property bool toggleButtonPressed: false
    property bool toggleClickInProgress: false
    property int slideDirection: -1
    property real panelProgress: 0
    property real pageProgress: 1
    property real panelContentHeight: 0
    property real volume: 0.5
    property real volumeBeforeMute: volume
    property bool muted: false
    property string soundTab: "outputs"
    property bool wifiDeviceAvailable: false
    property bool wifiEnabled: false
    property string expandedWifiSsid: ""
    property string activeWifiConnectionUuid: ""
    property string activeWifiSsid: ""
    property double lastWifiScanAt: 0
    property string connectingWifiSsid: ""
    property string wifiStatusSsid: ""
    property string wifiStatusMessage: ""
    property bool wifiStatusError: false
    property string pendingWifiSsid: ""
    property string pendingWifiPassword: ""
    property string pendingWifiUuid: ""
    property bool pendingWifiDisconnect: false
    property bool pendingWifiForget: false
    property int wifiPasswordResetVersion: 0
    property string activeConnection: "Sem conexão ativa"
    property string connectionKind: ""

    ListModel {
        id: availableWifiModel
    }

    property var savedWifiConnections: []
    property string pendingDialogPowerAction: ""
    property bool suspendAfterLock: false
    readonly property var outputDevices: Pipewire.nodes.values.filter(node => node.isSink && !node.isStream && node.audio !== null)

    implicitWidth: panelWidth
    // Keep the native Wayland popup surface stable. Resizing QWindow on every
    // animation frame causes repeated configure/commit cycles; only the visual
    // panel inside this surface should grow and shrink.
    implicitHeight: 540
    visible: false
    color: "transparent"
    grabFocus: false
    mask: Region { item: panel }

    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - width - 8
    anchor.rect.y: Config.frame_enabled ? (Config.topbar_height - 10 + Config.frame_thickness + 3) : (Config.topbar_height - 2)

    Behavior on panelContentHeight {
        enabled: root.isOpen
        NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    HyprlandFocusGrab {
        active: root.isOpen && root.focusGrabEnabled

        windows: [root]

        onCleared: {
            root.focusGrabEnabled = false

            if (root.toggleButtonPressed || root.toggleClickInProgress) {
                root.rearmFocusGrab()
                return
            }

            dismissTimer.restart()
        }
    }

    Timer {
        id: dismissTimer
        interval: 180
        onTriggered: root.closeMenu()
    }

    Timer {
        id: pressRecoveryTimer
        interval: 1000
        onTriggered: root.toggleButtonPressed = false
    }

    onVisibleChanged: {
        if (!visible) {
            root.expandedWifiSsid = ""
        }
    }

    Component.onCompleted: {
        wifiDevicePoll.running = true
        wifiPoll.running = true
        connectionPoll.running = true
        savedWifiPoll.running = true
    }

    onWifiEnabledChanged: {
        root.requestWifiScan()
    }

    onWifiDeviceAvailableChanged: {
        root.requestWifiScan()
    }

    onSavedWifiConnectionsChanged: {
        root.requestWifiScan()
    }

    onExpandedWifiSsidChanged: {
        if (root.wifiScanPaused()) {
            wifiScanDelay.stop()
            availableWifiPoll.running = false
        } else {
            root.requestWifiScan()
        }
    }

    function noteToggleButtonPress(pressed) {
        root.toggleButtonPressed = pressed
        if (pressed) {
            dismissTimer.stop()
            pressRecoveryTimer.restart()
            if (!root.focusGrabEnabled)
                rearmFocusGrab()
        } else {
            pressRecoveryTimer.stop()
        }
    }

    function rearmFocusGrab() {
        if (!root.isOpen)
            return
        root.focusGrabEnabled = false
        Qt.callLater(() => {
            if (root.isOpen)
                root.focusGrabEnabled = true
        })
    }

    function pageIndex(type) {
        return type === "power" ? 0 : type === "sound" ? 1 : 2
    }

    function componentFor(type) {
        if (type === "sound") return soundPage
        if (type === "network") return networkPage
        if (type === "power") return powerPage
        return null
    }

    function updatePanelContentHeight() {
        if (currentPage.item)
            panelContentHeight = Math.min(currentPage.item.implicitHeight + 36, height - 4)
    }

    function wifiPasswordInputExpanded() {
        if (!root.expandedWifiSsid)
            return false

        if (root.savedWifiConnections.some(connection => connection.ssid === root.expandedWifiSsid))
            return false

        for (let i = 0; i < availableWifiModel.count; ++i) {
            const network = availableWifiModel.get(i)
            if (network.ssid === root.expandedWifiSsid)
                return network.security !== ""
        }

        return false
    }

    function wifiScanPaused() {
        return root.connectingWifiSsid !== "" || root.wifiPasswordInputExpanded()
    }

    function requestWifiScan() {
        if (!root.wifiEnabled || !root.wifiDeviceAvailable || root.wifiScanPaused()) {
            wifiScanDelay.stop()
            return
        }
        if (availableWifiPoll.running || wifiScanDelay.running)
            return

        const remaining = 15000 - (Date.now() - root.lastWifiScanAt)
        if (remaining <= 0) {
            root.startWifiScanNow()
        } else {
            wifiScanDelay.interval = remaining
            wifiScanDelay.restart()
        }
    }

    function startWifiScanNow() {
        if (!root.wifiEnabled || !root.wifiDeviceAvailable || root.wifiScanPaused()
                || availableWifiPoll.running)
            return

        root.lastWifiScanAt = Date.now()
        availableWifiPoll.running = true
    }

    function refreshPageData(type) {
        if (type === "sound")
            volumePoll.running = true

        if (type === "network") {
            wifiDevicePoll.running = true
            wifiPoll.running = true
            connectionPoll.running = true
            savedWifiPoll.running = true
            root.requestWifiScan()
        }
    }

    function toggle(type) {
        toggleClickInProgress = true
        Qt.callLater(() => root.toggleClickInProgress = false)
        dismissTimer.stop()
        pressRecoveryTimer.stop()
        toggleButtonPressed = false
        if (isOpen && menuType === type) {
            closeMenu()
            return
        }

        if (!isOpen) {
            focusGrabEnabled = false
            menuType = type
            previousMenuType = ""
            isOpen = true
            visible = true

            panelProgress = 0
            panelAnimation.to = 1
            panelAnimation.restart()

            Qt.callLater(() => {
                if (root.isOpen)
                    root.focusGrabEnabled = true

                root.updatePanelContentHeight()
            })
        } else {
            if (pageAnimation.running) {
                pageAnimation.stop()
                pageProgress = 1
                previousMenuType = ""
            }
            previousMenuType = menuType
            slideDirection = pageIndex(type) > pageIndex(menuType) ? 1 : -1
            menuType = type
            pageProgress = 0
            pageAnimation.restart()
            Qt.callLater(root.updatePanelContentHeight)
        }

        refreshPageData(type)
    }

    function closeMenu() {
        if (!isOpen)
            return
        dismissTimer.stop()
        pressRecoveryTimer.stop()
        isOpen = false
        panelAnimation.to = 0
        panelAnimation.restart()
    }

    function setVolume(value) {
        volume = Math.max(0, Math.min(1, value))
        muted = volume <= 0 ? true : false
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", volume.toFixed(2)])
    }

    function setDefaultOutput(node) {
        Pipewire.preferredDefaultAudioSink = node
    }

    function toggleMute() {
        if(!muted) {
            volumeBeforeMute = volume
            setVolume(0)
        } else {
            setVolume(volumeBeforeMute)
        }
    }

    function runPowerAction(action) {
        if (action === "poweroff" || action === "reboot") {
            root.pendingDialogPowerAction = action
            const isPoweroff = action === "poweroff"
            Dialogs.showPrompt(
                "Os aplicativos serão encerrados e a sessão será finalizada.",
                [
                    { text: "Cancelar", value: "cancel", role: "normal" },
                    { text: isPoweroff ? "Desligar" : "Reiniciar", value: "confirm", role: "primary" }
                ],
                isPoweroff ? "Desligar o computador?" : "Reiniciar o computador?",
                isPoweroff ? "" : "",
                isPoweroff ? "#f38ba8" : "#a6e3a1"
            )
            closeMenu()
            return
        }

        if (action === "lock")
            root.sessionController.lockSession()
        else if (action === "logout")
            Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
        else if (action === "suspend") {
            root.suspendAfterLock = true
            root.sessionController.lockSession()
        }

        closeMenu()
    }

    Connections {
        target: Dialogs

        function onAccepted(value, inputValues) {
            if (!root.pendingDialogPowerAction)
                return

            const action = root.pendingDialogPowerAction
            root.pendingDialogPowerAction = ""
            if (value !== "confirm")
                return

            Quickshell.execDetached(["systemctl", action])
        }

        function onRejected() {
            root.pendingDialogPowerAction = ""
        }
    }

    Connections {
        target: root.sessionController

        function onLockReadyChanged() {
            if (!root.suspendAfterLock || !root.sessionController.lockReady)
                return

            root.suspendAfterLock = false
            Quickshell.execDetached(["systemctl", "suspend"])
        }
    }

    function updateAvailableWifiNetworks(networks) {
        const savedSsids = new Set(root.savedWifiConnections.map(connection => connection.ssid))
        const normalizedNetworks = networks.map(network => ({
            ssid: network.ssid,
            signal: network.signal,
            security: network.security,
            inUse: Boolean(network.inUse)
                || (root.connectionKind === "Wi-Fi" && network.ssid === root.activeWifiSsid),
            saved: savedSsids.has(network.ssid)
        }))

        // Keep the active access point when several APs advertise the same
        // SSID, then put saved networks first and sort each tier by signal.
        const uniqueNetworks = new Map()
        for (const network of normalizedNetworks) {
            const existing = uniqueNetworks.get(network.ssid)
            if (!existing || (network.inUse && !existing.inUse)
                    || (network.inUse === existing.inUse && network.signal > existing.signal))
                uniqueNetworks.set(network.ssid, network)
        }
        const sortedNetworks = Array.from(uniqueNetworks.values()).sort((left, right) =>
            Number(right.saved) - Number(left.saved)
                || Number(right.inUse) - Number(left.inUse)
                || right.signal - left.signal
        )

        const sortedSsids = new Set(sortedNetworks.map(network => network.ssid))
        for (let i = availableWifiModel.count - 1; i >= 0; --i) {
            if (!sortedSsids.has(availableWifiModel.get(i).ssid))
                availableWifiModel.remove(i)
        }
        for (let i = 0; i < sortedNetworks.length; ++i) {
            const network = sortedNetworks[i]
            let existing = -1
            for (let j = i; j < availableWifiModel.count; ++j) {
                if (availableWifiModel.get(j).ssid === network.ssid) {
                    existing = j
                    break
                }
            }
            if (existing < 0)
                availableWifiModel.insert(i, network)
            else {
                if (existing !== i)
                    availableWifiModel.move(existing, i, 1)
                availableWifiModel.set(i, network)
            }
        }
    }

    function splitNmcliFields(line) {
        const fields = []
        let field = ""
        let escaped = false
        for (const char of line) {
            if (escaped) {
                field += char
                escaped = false
            } else if (char === "\\") {
                escaped = true
            } else if (char === ":") {
                fields.push(field)
                field = ""
            } else {
                field += char
            }
        }
        fields.push(field)
        return fields
    }

    function wifiSignalGlyph(security, signal) {
        const secured = security !== ""
        if (signal >= 100)
            return secured ? "\udb82\udd2a" : "\udb82\udd28"
        if (signal >= 75)
            return secured ? "\udb85\udecd" : "\udb82\udd25"
        if (signal >= 50)
            return secured ? "\udb85\udecc" : "\udb82\udd22"
        if (signal >= 25)
            return secured ? "\udb85\udecb" : "\udb82\udd1f"
        return secured ? "\udb82\udd2c" : "\udb82\udd2f"
    }

    function setWifiNetworkInUse(ssid, inUse) {
        for (let i = 0; i < availableWifiModel.count; ++i) {
            if (availableWifiModel.get(i).ssid !== ssid)
                continue

            availableWifiModel.setProperty(i, "inUse", inUse)
            if (inUse)
                availableWifiModel.setProperty(i, "saved", true)
            return
        }
    }

    function startWifiConnection(ssid, password, savedUuid) {
        if (root.connectingWifiSsid || wifiConnectProcess.running)
            return

        root.pendingWifiSsid = ssid
        root.pendingWifiPassword = password
        root.pendingWifiUuid = savedUuid || ""
        root.pendingWifiDisconnect = false
        root.pendingWifiForget = false
        root.connectingWifiSsid = ssid
        root.wifiStatusSsid = ssid
        root.wifiStatusMessage = ""
        root.wifiStatusError = false
        wifiStatusTimer.stop()

        const newProfileConnectScript = [
            'ssid="$1"',
            'password="$2"',
            'before=$(nmcli -g UUID connection show) || exit $?',
            'before=" $(printf "%s" "$before" | tr "\\n" " ") "',
            'if [ -n "$password" ]; then',
            '  nmcli --ask --wait 10 device wifi connect "$ssid" password "$password" name "$ssid"',
            'else',
            '  nmcli --ask --wait 10 device wifi connect "$ssid" name "$ssid"',
            'fi',
            'status=$?',
            'if [ "$status" -eq 0 ]; then',
            '  after=$(nmcli -g UUID connection show) || exit $?',
            '  for uuid in $after; do',
            '    case " $before " in *" $uuid "*) continue ;; esac',
            '    profile_ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)',
            '    if [ "$profile_ssid" = "$ssid" ]; then',
            '      printf "QUICKSHELL_WIFI_UUID=%s\\n" "$uuid"',
            '      break',
            '    fi',
            '  done',
            'fi',
            'if [ "$status" -ne 0 ]; then',
            '  nmcli -g UUID connection show | while IFS= read -r uuid; do',
            '    case " $before " in *" $uuid "*) continue ;; esac',
            '    profile_ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)',
            '    [ "$profile_ssid" = "$ssid" ] && nmcli connection delete uuid "$uuid" >/dev/null 2>&1',
            '  done',
            'fi',
            'exit "$status"'
        ].join("\n")
        const args = savedUuid
            ? ["nmcli", "--ask", "--wait", "10", "connection", "up", "uuid", savedUuid]
            : ["sh", "-c", newProfileConnectScript, "quickshell-wifi", ssid, password]

        wifiConnectProcess.command = args
        wifiConnectProcess.running = true
    }

    function startWifiDisconnection(ssid, savedUuid) {
        if (root.connectingWifiSsid || wifiConnectProcess.running)
            return

        root.pendingWifiSsid = ssid
        root.pendingWifiPassword = ""
        root.pendingWifiUuid = savedUuid
        root.pendingWifiDisconnect = true
        root.pendingWifiForget = false
        root.connectingWifiSsid = ssid
        root.wifiStatusSsid = ssid
        root.wifiStatusMessage = ""
        root.wifiStatusError = false
        wifiStatusTimer.stop()
        wifiConnectProcess.command = ["nmcli", "--wait", "10", "connection", "down", "uuid", savedUuid]
        wifiConnectProcess.running = true
    }

    function startWifiForget(ssid, savedUuid, disconnectFirst) {
        if (root.connectingWifiSsid || wifiConnectProcess.running)
            return

        root.pendingWifiSsid = ssid
        root.pendingWifiPassword = ""
        root.pendingWifiUuid = savedUuid
        root.pendingWifiDisconnect = false
        root.pendingWifiForget = true
        root.connectingWifiSsid = ssid
        root.wifiStatusSsid = ssid
        root.wifiStatusMessage = ""
        root.wifiStatusError = false
        wifiStatusTimer.stop()

        const forgetScript = [
            'uuid="$1"',
            'if [ "$2" = "1" ]; then',
            '  nmcli --wait 10 connection down uuid "$uuid" || exit $?',
            'fi',
            'nmcli connection delete uuid "$uuid"'
        ].join("\n")
        wifiConnectProcess.command = [
            "sh", "-c", forgetScript, "quickshell-forget-wifi", savedUuid,
            disconnectFirst ? "1" : "0"
        ]
        wifiConnectProcess.running = true
    }

    function finishWifiConnection(exitCode, output) {
        const ssid = root.pendingWifiSsid
        const lowerOutput = String(output || "").toLowerCase()

        if (root.pendingWifiForget) {
            const forgottenUuid = root.pendingWifiUuid
            root.pendingWifiForget = false
            root.connectingWifiSsid = ""
            root.pendingWifiUuid = ""

            if (exitCode === 0) {
                root.savedWifiConnections = root.savedWifiConnections.filter(
                    connection => connection.uuid !== forgottenUuid
                )
                root.setWifiNetworkInUse(ssid, false)
                if (root.activeWifiConnectionUuid === forgottenUuid
                        || root.activeWifiSsid === ssid) {
                    root.activeWifiConnectionUuid = ""
                    root.activeWifiSsid = ""
                }
                root.wifiStatusMessage = ""
                root.wifiStatusError = false
                root.expandedWifiSsid = ""
                root.connectionPoll.running = true
                root.savedWifiPoll.running = true
                root.requestWifiScan()
                wifiStatusTimer.stop()
            } else {
                root.wifiStatusMessage = "Falha ao esquecer rede"
                root.wifiStatusError = true
                root.connectionPoll.running = true
                root.savedWifiPoll.running = true
                root.requestWifiScan()
                wifiStatusTimer.interval = 5000
                wifiStatusTimer.restart()
            }
            return
        }

        if (root.pendingWifiDisconnect) {
            root.pendingWifiDisconnect = false
            root.connectingWifiSsid = ""
            root.pendingWifiUuid = ""
            if (exitCode === 0) {
                root.setWifiNetworkInUse(ssid, false)
                if (root.activeWifiSsid === ssid)
                    root.activeWifiSsid = ""
            }
            root.wifiStatusMessage = exitCode === 0 ? "" : "Falha ao desconectar"
            root.wifiStatusError = exitCode !== 0
            root.connectionPoll.running = true
            root.savedWifiPoll.running = true
            root.requestWifiScan()
            if (exitCode === 0) {
                wifiStatusTimer.stop()
            } else {
                wifiStatusTimer.interval = 5000
                wifiStatusTimer.restart()
            }
            return
        }

        if (exitCode === 0) {
            const uuidMatch = String(output || "").match(/QUICKSHELL_WIFI_UUID=([^\s]+)/)
            const savedUuid = root.pendingWifiUuid || uuidMatch?.[1] || ""
            if (savedUuid) {
                const savedConnections = root.savedWifiConnections.slice()
                const existingIndex = savedConnections.findIndex(connection => connection.ssid === ssid)
                const savedConnection = { uuid: savedUuid, ssid: ssid }
                if (existingIndex >= 0)
                    savedConnections[existingIndex] = savedConnection
                else
                    savedConnections.push(savedConnection)
                root.savedWifiConnections = savedConnections
                root.activeWifiConnectionUuid = savedUuid
            }
            root.setWifiNetworkInUse(ssid, true)
            root.connectingWifiSsid = ""
            root.pendingWifiPassword = ""
            root.pendingWifiUuid = ""
            root.wifiPasswordResetVersion += 1
            root.wifiStatusMessage = ""
            root.wifiStatusError = false
            root.activeWifiSsid = ssid
            root.connectionPoll.running = true
            root.savedWifiPoll.running = true
            root.requestWifiScan()
            wifiStatusTimer.stop()
            return
        }

        const invalidPassword = /(secrets were required|no secrets|authentication failed|wrong password|invalid password|802-11-wireless-security\.psk)/.test(lowerOutput)
        root.wifiStatusMessage = invalidPassword ? "Senha incorreta" : "Falha ao conectar"
        root.wifiStatusError = true
        wifiStatusTimer.interval = 5000
        wifiStatusTimer.restart()

        root.connectingWifiSsid = ""
        root.pendingWifiPassword = ""
        root.pendingWifiUuid = ""
        root.savedWifiPoll.running = true
        root.requestWifiScan()
        root.connectionPoll.running = true
    }

    NumberAnimation {
        id: panelAnimation
        target: root
        property: "panelProgress"
        duration: 280
        easing.type: Easing.OutCubic
        onFinished: {
            if (!root.isOpen) {
                root.visible = false
                root.menuType = ""
                root.previousMenuType = ""
            }
        }
    }

    NumberAnimation {
        id: pageAnimation
        target: root
        property: "pageProgress"
        to: 1
        duration: 340
        easing.type: Easing.OutCubic
        onFinished: root.previousMenuType = ""
    }

    Process {
        id: volumePoll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim()
                const match = output.match(/Volume:\s*([0-9.]+)/)
                if (match && !volumeSliderArea.pressed)
                    root.volume = Math.max(0, Math.min(1, Number(match[1])))
                root.muted = output.includes("[MUTED]") || root.volume <= 0
            }
        }
    }

    Process {
        id: wifiConnectProcess
        command: []
        environment: ({ LANG: "C", LC_ALL: "C" })

        stdout: StdioCollector { id: wifiConnectStdout }
        stderr: StdioCollector { id: wifiConnectStderr }

        onExited: (exitCode, exitStatus) => {
            root.finishWifiConnection(exitCode,
                `${wifiConnectStdout.text}\n${wifiConnectStderr.text}`)
        }
    }

    Timer {
        id: wifiStatusTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (!root.connectingWifiSsid)
                root.wifiStatusMessage = ""
        }
    }

    Timer {
        id: wifiScanDelay
        interval: 15000
        repeat: false
        onTriggered: root.startWifiScanNow()
    }

    Process {
        id: wifiDevicePoll
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiDeviceAvailable = text
                    .split("\n")
                    .some(line => line.trim().endsWith(":wifi"))
            }
        }
    }

    Process {
        id: wifiPoll
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled"
            }
        }
    }

    Process {
        id: connectionPoll
        command: ["nmcli", "-t", "-f", "UUID,NAME,TYPE", "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(line => line.length > 0)
                const connections = lines.map(line => root.splitNmcliFields(line))
                const wifiLine = connections.find(fields => fields[fields.length - 1] === "802-11-wireless")
                const wiredLine = connections.find(fields => fields[fields.length - 1] === "802-3-ethernet")
                const activeLine = wiredLine ?? wifiLine
                root.connectionKind = wiredLine ? "Ethernet" : wifiLine ? "Wi-Fi" : ""
                root.activeConnection = activeLine
                    ? activeLine[1]
                    : "Sem conexão ativa"
                root.activeWifiConnectionUuid = wifiLine ? wifiLine[0] : ""
                const savedWifi = root.savedWifiConnections.find(
                    connection => connection.uuid === root.activeWifiConnectionUuid
                )
                root.activeWifiSsid = wifiLine
                    ? (savedWifi?.ssid || "")
                    : ""
            }
        }
    }

    Process {
        id: availableWifiPoll

        command: [
            "nmcli",
            "-t",
            "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
            "--rescan", "yes"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.wifiScanPaused())
                    return

                const networks = []

                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue

                    const fields = root.splitNmcliFields(line)

                    if (fields.length < 4 || !fields[1].trim())
                        continue

                    networks.push({
                        inUse: fields[0] === "*",
                        ssid: fields[1],
                        signal: Number(fields[2]) || 0,
                        security: fields[3] === "--" ? "" : (fields[3] || "")
                    })
                }

                const activeNetwork = networks.find(network => network.inUse)
                if (activeNetwork)
                    root.activeWifiSsid = activeNetwork.ssid

                root.updateAvailableWifiNetworks(networks)
            }
        }
    }

    Process {
        id: savedWifiPoll

        command: [
            "sh",
            "-c",
            "nmcli -t -f UUID,TYPE connection show | while IFS=: read -r uuid type; do\n" +
            "    [ \"$type\" = \"802-11-wireless\" ] || continue\n" +
            "    ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid \"$uuid\" 2>/dev/null)\n" +
            "    [ -n \"$ssid\" ] || continue\n" +
                    "    printf '%s\\t%s\\n' \"$uuid\" \"$ssid\"\n" +
            "done"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const connections = []

                for (let line of text.split("\n")) {
                    if (!line)
                        continue

                    if (line.endsWith("\r"))
                        line = line.slice(0, -1)

                    const fields = line.split("\t")

                    if (fields.length < 2)
                        continue

                    const ssid = fields.slice(1).join("\t")
                    if (!root.pendingWifiUuid && root.connectingWifiSsid === ssid)
                        continue

                    connections.push({
                        uuid: fields[0],
                        ssid: ssid
                    })
                }

                root.savedWifiConnections = connections
                const activeSavedWifi = connections.find(
                    connection => connection.uuid === root.activeWifiConnectionUuid
                )
                if (activeSavedWifi)
                    root.activeWifiSsid = activeSavedWifi.ssid
            }
        }
    }

    Timer {
        running: root.visible && root.menuType === "sound"
        repeat: true
        interval: 1200
        onTriggered: volumePoll.running = true
    }

    Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: {
            wifiDevicePoll.running = true
            wifiPoll.running = true
            connectionPoll.running = true
            savedWifiPoll.running = true
            root.requestWifiScan()
        }
    }

    Rectangle {
        id: panel
        x: 1
        y: 1 + (1 - root.panelProgress) * -10
        width: root.width - 2
        height: Math.min(root.panelContentHeight * root.panelProgress, root.height - 2)
        radius: 18
        color: "#11111b"
        border.width: 1
        border.color: "#303044"
        opacity: root.panelProgress
        clip: true

        Item {
            id: pageViewport
            anchors.fill: parent
            anchors.margins: 16
            clip: true

            Loader {
                id: outgoingPage
                active: root.previousMenuType !== ""
                sourceComponent: root.componentFor(root.previousMenuType)
                width: pageViewport.width
                height: item?.implicitHeight ?? 0
                z: 0
                opacity: 1 - root.pageProgress
                onLoaded: root.updatePanelContentHeight()
                transform: Translate { x: -root.slideDirection * root.width * root.pageProgress }
            }

            Loader {
                id: currentPage
                sourceComponent: root.componentFor(root.menuType)
                width: pageViewport.width
                height: item?.implicitHeight ?? 0
                z: 1
                opacity: root.previousMenuType !== "" ? root.pageProgress : 1
                onLoaded: root.updatePanelContentHeight()
                transform: Translate {
                    x: root.previousMenuType !== ""
                        ? root.slideDirection * root.width * (1 - root.pageProgress)
                        : 0
                    y: root.previousMenuType === "" ? (1 - root.panelProgress) * -10 : 0
                }
            }

            Connections {
                target: currentPage.item
                function onImplicitHeightChanged() { root.updatePanelContentHeight() }
            }
        }
    }

    Component {
        id: soundPage

        Column {
            id: soundPageRoot
            width: root.width - 34
            spacing: 12
            readonly property var streamNodes: Pipewire.nodes.values.filter(node =>
                node.isStream && node.audio !== null)
            readonly property var appGroups: {
                const groups = Object.create(null)
                for (const node of streamNodes) {
                    const props = node.properties ?? ({})
                    const mediaClass = String(props["media.class"] || node.type || "")
                    if (mediaClass.includes("Input/Audio") || mediaClass.includes("Audio/Source"))
                        continue
                    const name = String(props["application.name"]
                        || props["application.process.binary"]
                        || node.description
                        || node.name
                        || "Aplicativo")
                    if (!groups[name])
                        groups[name] = { name: name, nodes: [] }
                    groups[name].nodes.push(node)
                }
                return Object.values(groups)
            }

            function appIconFor(group) {
                const firstNode = group.nodes[0]
                const props = firstNode?.properties ?? ({})
                const fallback = "application-x-executable"
                const explicitIcon = String(props["application.icon-name"]
                    || props["application.icon"] || "").trim()

                if (explicitIcon) {
                    if (explicitIcon.startsWith("/") || explicitIcon.startsWith("file://"))
                        return explicitIcon
                    return Quickshell.iconPath(explicitIcon, fallback)
                }

                const candidates = [
                    props["application.id"],
                    props["application.process.binary"],
                    group.name
                ]
                for (const candidate of candidates) {
                    const identity = String(candidate || "").trim()
                    if (!identity)
                        continue
                    const entry = DesktopEntries.heuristicLookup(identity)
                    if (entry?.icon)
                        return Quickshell.iconPath(entry.icon, fallback)
                }

                return Utils.getAppIcon(group.name, fallback)
            }

            PwObjectTracker {
                objects: Pipewire.nodes.values.filter(node => node.isStream)
            }

            Text {
                text: "Som"
                color: "#cdd6f4"
                font.family: "Cantarell"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Row {
                width: parent.width
                spacing: 10
                Text {
                    text: root.muted || root.volume === 0 ? "\ueee8" : root.volume < 0.5 ? "\uf027" : "\uefcf"
                    color: "#89b4fa"
                    font.family: "JetBrainsMono Nerd Font Mono"
                    font.weight: Font.Black
                    font.pixelSize: 36
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.muted ? "Silenciado" : `${Math.round(root.volume * 100)}%`
                    color: "#cdd6f4"
                    font.family: "Cantarell"
                    font.pixelSize: 14
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                id: volumeSliderArea
                width: parent.width
                height: 24
                property bool pressed: false

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 7
                    radius: 4
                    color: "#38384d"
                    Rectangle {
                        width: parent.width * root.volume
                        height: parent.height
                        radius: parent.radius
                        color: "#89b4fa"
                    }
                }
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width, parent.width * root.volume - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    radius: 8
                    color: "#cdd6f4"
                    border.color: "#89b4fa"
                    border.width: 2
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    onPressed: mouse => {
                        volumeSliderArea.pressed = true
                        root.setVolume((mouse.x - 5) / (width - 10))
                    }
                    onPositionChanged: mouse => {
                        if (volumeSliderArea.pressed)
                            root.setVolume((mouse.x - 5) / (width - 10))
                    }
                    onReleased: volumeSliderArea.pressed = false
                    onCanceled: volumeSliderArea.pressed = false
                }
            }

            Row {
                width: parent.width
                spacing: 8
                ActionTile {
                    width: (parent.width - parent.spacing) / 2
                    height: 38
                    glyph: root.muted ? "\uefcf" : "\ueee8"
                    label: root.muted ? "Ativar som" : "Silenciar"
                    onClicked: root.toggleMute()
                }
                ActionTile {
                    width: (parent.width - parent.spacing) / 2
                    height: 38
                    glyph: ""
                    label: "Mixer"
                    onClicked: Quickshell.execDetached(["pavucontrol"])
                }
            }

            Row {
                width: parent.width
                spacing: 6
                Repeater {
                    model: [
                        { id: "outputs", label: "Saídas", icon: "" },
                        { id: "applications", label: "Aplicativos", icon: "" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - parent.spacing) / 2
                        height: 34
                        radius: 10
                        color: root.soundTab === modelData.id ? "#313244" : "#1e1e2e"
                        Row {
                            anchors.centerIn: parent
                            spacing: 7
                            Text {
                                text: modelData.icon
                                color: root.soundTab === modelData.id ? "#89b4fa" : "#a6adc8"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 24
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData.label
                                color: "#cdd6f4"
                                font.family: "Cantarell"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.soundTab = modelData.id
                        }
                    }
                }
            }

            Text {
                visible: root.soundTab === "outputs"
                text: "Saída de áudio"
                color: "#a6adc8"
                font.family: "Cantarell"
                font.pixelSize: 12
            }

            Column {
                visible: root.soundTab === "outputs"
                width: parent.width
                height: Math.max(32, root.outputDevices.length * 49 - 5)
                spacing: 5
                Repeater {
                    model: root.outputDevices
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 44
                        radius: 10
                        color: "#1e1e2e"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 11
                            anchors.right: outputAction.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Text {
                                text: "\udb81\udcc3"
                                color: "#89b4fa"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 19
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                width: parent.width - 27
                                text: modelData.description || modelData.nickname || modelData.name
                                color: "#cdd6f4"
                                font.family: "Cantarell"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Rectangle {
                            id: outputAction
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: 9
                            color: Pipewire.defaultAudioSink === modelData ? "#89b4fa" : outputMouse.containsMouse ? "#313244" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: Pipewire.defaultAudioSink === modelData ? "" : ""
                                color: Pipewire.defaultAudioSink === modelData ? "#11111b" : "#cdd6f4"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 24
                            }
                            MouseArea {
                                id: outputMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.setDefaultOutput(modelData)
                            }
                            Behavior on color {
                                ColorAnimation{ duration: 360 }
                            }
                        }
                    }
                }
                Text {
                    visible: root.outputDevices.length === 0
                    text: "Nenhuma saída de áudio encontrada"
                    color: "#6c7086"
                    font.family: "Cantarell"
                    font.pixelSize: 12
                    height: visible ? 32 : 0
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Text {
                visible: root.soundTab === "applications"
                text: "Volume por aplicativo"
                color: "#a6adc8"
                font.family: "Cantarell"
                font.pixelSize: 12
            }

            ListView {
                visible: root.soundTab === "applications"
                width: parent.width
                height: visible
                    ? Math.min(250, Math.max(38, soundPageRoot.appGroups.length * 70))
                    : 0
                clip: true
                spacing: 5
                model: soundPageRoot.appGroups
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    width: ListView.view.width
                    height: 64
                    radius: 10
                    color: "#1e1e2e"
                    property real appVolume: {
                        const streams = modelData.nodes.filter(node => node.audio !== null)
                        if (streams.length === 0)
                            return 0
                        return streams.reduce((sum, node) => sum + node.audio.volume, 0) / streams.length
                    }

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.top: parent.top
                        anchors.topMargin: 8
                        height: 20
                        spacing: 8

                        Image {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            source: soundPageRoot.appIconFor(appRow.modelData)
                            sourceSize: Qt.size(40, 40)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }

                        Text {
                            width: parent.width - 26
                            text: appRow.modelData.name
                            color: "#cdd6f4"
                            font.family: "Cantarell"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Item {
                        id: appVolumeSlider
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.right: appVolumeLabel.left
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        height: 18
                        property real value: Math.min(1.5, appRow.appVolume)
                        property real previewValue: 0
                        property bool pressed: false
                        readonly property real shownValue: pressed ? previewValue : value

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            radius: 3
                            color: "#38384d"
                            Rectangle {
                                width: parent.width * appVolumeSlider.shownValue / 1.5
                                height: parent.height
                                radius: parent.radius
                                color: "#89b4fa"
                            }
                        }
                        Rectangle {
                            x: Math.max(0, Math.min(parent.width - width,
                                parent.width * appVolumeSlider.shownValue / 1.5 - width / 2))
                            anchors.verticalCenter: parent.verticalCenter
                            width: 13
                            height: 13
                            radius: 7
                            color: "#cdd6f4"
                            border.color: "#89b4fa"
                            border.width: 2
                        }
                        MouseArea {
                            anchors.fill: parent
                            function setValueAt(x) {
                                const value = 1.5 * Math.max(0, Math.min(1, x / width))
                                appVolumeSlider.previewValue = value
                                for (const stream of appRow.modelData.nodes) {
                                    if (stream.audio !== null)
                                        stream.audio.volume = value
                                }
                            }
                            onPressed: mouse => {
                                appVolumeSlider.pressed = true
                                setValueAt(mouse.x)
                            }
                            onPositionChanged: mouse => {
                                if (appVolumeSlider.pressed)
                                    setValueAt(mouse.x)
                            }
                            onReleased: appVolumeSlider.pressed = false
                            onCanceled: appVolumeSlider.pressed = false
                        }
                    }

                    Text {
                        id: appVolumeLabel
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9
                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: `${Math.round(appRow.appVolume * 100)}%`
                        color: "#a6adc8"
                        font.family: "Cantarell"
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: soundPageRoot.appGroups.length === 0
                    text: "Nenhum aplicativo reproduzindo áudio"
                    color: "#6c7086"
                    font.family: "Cantarell"
                    font.pixelSize: 12
                }
            }
        }
    }

    Component {
        id: networkPage

        Column {
            width: root.width - 34
            spacing: 11

            Text {
                text: "Rede"
                color: "#cdd6f4"
                font.family: "Cantarell"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Rectangle {
                width: parent.width
                height: 60
                radius: 12
                color: "#1e1e2e"
                Row {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 10
                    Text {
                        text: root.connectionKind === "Ethernet" ? "\udb80\ude00" : root.connectionKind === "Wi-Fi" ? "\uf1eb" : "\udb80\ude02"
                        color: root.connectionKind === "" ? "#6c7086" : "#89b4fa"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 26
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 95
                        spacing: 2
                        Text {
                            text: root.connectionKind || "Desconectado"
                            color: "#cdd6f4"
                            font.family: "Cantarell"
                            font.pixelSize: 14
                        }
                        Text {
                            text: root.activeConnection
                            color: "#a6adc8"
                            font.family: "Cantarell"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 58
                radius: 11
                color: "#1e1e2e"
                Row {
                    id: wifiHeaderContent
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.right: wifiToggle.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text {
                        text: "\uf1eb"
                        color: "#89b4fa"
                        font.family: "JetBrainsMono Nerd Font Mono"
                        font.pixelSize: 26
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 36
                        spacing: 1
                        Text {
                            text: "Wi-Fi"
                            color: "#cdd6f4"
                            font.family: "Cantarell"
                            font.pixelSize: 13
                        }
                        Text {
                            width: parent.width
                            visible: root.activeWifiSsid !== ""
                            text: root.activeWifiSsid
                            color: "#a6adc8"
                            font.family: "Cantarell"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }
                Rectangle {
                    id: wifiToggle
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 24
                    radius: 12
                    opacity: root.wifiDeviceAvailable ? 1.0 : 0.4

                    color: root.wifiDeviceAvailable
                        ? (root.wifiEnabled ? "#89b4fa" : "#45475a")
                        : "#45475a"
                    Rectangle {
                        x: root.wifiDeviceAvailable && root.wifiEnabled ? parent.width - width - 3 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: "#f5f5f7"

                        Behavior on x {
                            NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                        }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.wifiDeviceAvailable && !root.connectingWifiSsid

                        onClicked: {
                            const newState = !root.wifiEnabled
                            root.wifiEnabled = newState
                            if (!newState) {
                                root.expandedWifiSsid = ""
                                wifiScanDelay.stop()
                                availableWifiPoll.running = false
                                root.updateAvailableWifiNetworks([])
                            } else {
                                root.requestWifiScan()
                            }

                            Quickshell.execDetached([
                                "nmcli", "radio", "wifi",
                                newState ? "on" : "off"
                            ])
                        }
                    }
                }
            }

            Text {
                text: "Redes disponíveis"
                color: "#a6adc8"
                font.family: "Cantarell"
                font.pixelSize: 12
                visible: root.wifiDeviceAvailable && root.wifiEnabled
            }

            ListView {
                id: availableWifiList

                width: parent.width
                height: 210
                clip: true
                spacing: 4
                visible: root.wifiDeviceAvailable && root.wifiEnabled

                model: availableWifiModel

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            properties: "scale"
                            from: 0
                            to: 1
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            properties: "opacity"
                            from: 0
                            to: 1
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            properties: "scale"
                            to: 0
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            properties: "opacity"
                            to: 0
                            duration: 180
                            easing.type: Easing.InCubic
                        }
                    }
                }

                delegate: Rectangle {
                    id: wifiNetworkDelegate

                    required property string ssid
                    required property int signal
                    required property string security
                    required property bool inUse

                    readonly property bool expanded:
                        root.expandedWifiSsid === ssid

                    readonly property var savedConnection:
                        root.savedWifiConnections.find(
                            connection => connection.ssid === ssid
                        ) ?? null
                    readonly property bool connectionStatusVisible:
                        root.wifiStatusSsid === ssid && root.wifiStatusMessage !== ""
                    readonly property bool connecting:
                        root.connectingWifiSsid !== ""
                    readonly property string connectionActionLabel:
                        root.connectingWifiSsid === ssid
                            ? (root.pendingWifiForget ? "Esquecendo"
                                : root.pendingWifiDisconnect ? "Desconectando" : "Conectando")
                            : (inUse ? "Desconectar" : "Conectar")

                    width: availableWifiList.width
                    height: expanded ? (connectionStatusVisible ? 101 : 82) : 38
                    scale: 1
                    opacity: 1
                    transformOrigin: Item.Center
                    radius: 9
                    color: networkHeaderMouse.pressed ? "#343449"
                        : networkHeaderMouse.containsMouse ? "#29293b" : "#1e1e2e"
                    clip: true

                    Behavior on color {
                        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }

                    function connectWifi() {
                        if (root.connectingWifiSsid)
                            return

                        const saved = wifiNetworkDelegate.savedConnection
                        const password = saved === null ? wifiPasswordInput.text : ""
                        if (saved === null && wifiNetworkDelegate.security !== "" && !password)
                            return

                        root.startWifiConnection(
                            wifiNetworkDelegate.ssid,
                            password,
                            saved?.uuid ?? ""
                        )
                    }

                    function forgetWifi() {
                        if (savedConnection === null)
                            return
                        const active = wifiNetworkDelegate.inUse
                            || root.activeWifiConnectionUuid === savedConnection.uuid
                            || root.activeWifiSsid === wifiNetworkDelegate.ssid
                        root.startWifiForget(
                            wifiNetworkDelegate.ssid,
                            savedConnection.uuid,
                            active
                        )
                    }

                    function toggleSavedWifi() {
                        if (savedConnection === null)
                            return

                        if (inUse) {
                            root.startWifiDisconnection(
                                wifiNetworkDelegate.ssid,
                                savedConnection.uuid
                            )
                        } else {
                            root.startWifiConnection(
                                wifiNetworkDelegate.ssid,
                                "",
                                savedConnection.uuid
                            )
                        }
                    }

                    Behavior on height {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    // Cabeçalho da rede
                    Row {
                        id: networkHeader

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11

                        height: 38
                        spacing: 9

                        Item {
                            width: 26
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: root.wifiSignalGlyph(
                                    wifiNetworkDelegate.security,
                                    wifiNetworkDelegate.signal
                                )
                                color: wifiNetworkDelegate.inUse ? "#a6e3a1" : "#89b4fa"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 24
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 26 - 24 - 18
                            spacing: 1

                            Text {
                                width: parent.width
                                text: wifiNetworkDelegate.ssid
                                color: "#cdd6f4"
                                font.family: "Cantarell"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: wifiNetworkDelegate.security
                                    ? `${wifiNetworkDelegate.security} · ${wifiNetworkDelegate.signal}%`
                                    : `Aberta · ${wifiNetworkDelegate.signal}%`
                                color: "#6c7086"
                                font.family: "Cantarell"
                                font.pixelSize: 10
                                visible: false
                            }
                        }

                        Item {
                            width: 24
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                text: wifiNetworkDelegate.inUse ? "" : wifiNetworkDelegate.expanded ? "" : ""
                                color: wifiNetworkDelegate.inUse ? "#a6e3a1" : "#6c7086"
                                font.family: "JetBrainsMono Nerd Font Mono"
                                font.pixelSize: 24
                            }
                        }
                    }

                    MouseArea {
                        id: networkHeaderMouse
                        anchors.fill: networkHeader
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (wifiNetworkDelegate.expanded) {
                                root.expandedWifiSsid = ""
                                return
                            }

                            root.expandedWifiSsid = wifiNetworkDelegate.ssid

                            if (
                                wifiNetworkDelegate.savedConnection === null
                                && wifiNetworkDelegate.security !== ""
                            ) {
                                Qt.callLater(() => {
                                    wifiPasswordInput.forceActiveFocus(Qt.MouseFocusReason)
                                })
                            }
                        }
                    }

                    // Área expansível
                    Row {
                        id: wifiActionsRow
                        anchors.top: networkHeader.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 11
                        anchors.rightMargin: 11
                        height: 38
                        spacing: 7
                        visible: wifiNetworkDelegate.expanded

                        // Rede conhecida: esquecer
                        Rectangle {
                            visible: wifiNetworkDelegate.savedConnection !== null
                            width: visible ? (parent.width - parent.spacing) / 2 : 0
                            height: 32
                            radius: 8
                            scale: forgetMouse.pressed ? 0.97
                                : forgetMouse.containsMouse ? 1.02 : 1
                            opacity: forgetMouse.enabled ? 1 : 0.45
                            color: forgetMouse.containsMouse ? "#45475a" : "#313244"

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: ""
                                    color: "#f38ba8"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 17
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.connectingWifiSsid === wifiNetworkDelegate.ssid
                                        && root.pendingWifiForget ? "Esquecendo" : "Esquecer"
                                    color: "#f38ba8"
                                    font.family: "Cantarell"
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.connectingWifiSsid
                                onClicked: wifiNetworkDelegate.forgetWifi()
                            }
                        }

                        // Rede conhecida: conectar ou desconectar
                        Rectangle {
                            visible: wifiNetworkDelegate.savedConnection !== null
                            width: visible ? (parent.width - parent.spacing) / 2 : 0
                            height: 32
                            radius: 8
                            scale: connectionActionMouse.pressed ? 0.97
                                : connectionActionMouse.containsMouse ? 1.02 : 1
                            opacity: connectionActionMouse.enabled ? 1 : 0.45
                            color: connectionActionMouse.containsMouse ? "#45475a" : "#313244"

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: wifiNetworkDelegate.inUse ? "󰖪" : ""
                                    color: "#a6e3a1"
                                    font.family: "JetBrainsMono Nerd Font Mono"
                                    font.pixelSize: 17
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: wifiNetworkDelegate.connectionActionLabel
                                    color: "#a6e3a1"
                                    font.family: "Cantarell"
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: connectionActionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.connectingWifiSsid
                                onClicked: wifiNetworkDelegate.toggleSavedWifi()
                            }
                        }

                        // Rede desconhecida: campo de senha
                        Rectangle {
                            visible: wifiNetworkDelegate.savedConnection === null
                                && wifiNetworkDelegate.security !== ""

                            width: visible ? parent.width - connectWifiButton.width - parent.spacing : 0
                            height: 32
                            radius: 8
                            color: "#313244"

                            TextInput {
                                id: wifiPasswordInput

                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9

                                verticalAlignment: TextInput.AlignVCenter
                                color: "#cdd6f4"
                                font.family: "Cantarell"
                                font.pixelSize: 12

                                echoMode: TextInput.Password
                                passwordCharacter: "•"
                                clip: true
                                enabled: !root.connectingWifiSsid
                                opacity: enabled ? 1 : 0.55
                                property int passwordResetVersion: root.wifiPasswordResetVersion
                                onPasswordResetVersionChanged: text = ""

                                onActiveFocusChanged: {
                                    if (activeFocus)
                                        dismissTimer.stop()
                                }

                                Text {
                                    anchors.fill: parent
                                    enabled: false
                                    verticalAlignment: Text.AlignVCenter
                                    visible: !wifiPasswordInput.text
                                    text: "Digite a senha..."
                                    color: "#6c7086"
                                    font: wifiPasswordInput.font
                                }

                                Keys.onReturnPressed: wifiNetworkDelegate.connectWifi()

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.IBeamCursor
                                }
                            }
                        }

                        // Conectar em rede desconhecida
                        Rectangle {
                            id: connectWifiButton

                            visible: wifiNetworkDelegate.savedConnection === null
                            enabled: !root.connectingWifiSsid
                            opacity: enabled ? 1 : 0.55
                            scale: connectMouse.pressed ? 0.96
                                : connectMouse.containsMouse ? 1.02 : 1
                            width: visible ? 88 : 0
                            height: 32
                            radius: 8
                            color: connectMouse.containsMouse ? "#b4befe" : "#89b4fa"

                            Behavior on opacity {
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                            }
                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: wifiNetworkDelegate.connectionActionLabel
                                color: "#11111b"
                                font.family: "Cantarell"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: connectMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: connectWifiButton.enabled
                                onClicked: wifiNetworkDelegate.connectWifi()
                            }
                        }
                    }

                    Text {
                        anchors.top: wifiActionsRow.bottom
                        anchors.topMargin: 1
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        height: 16
                        visible: wifiNetworkDelegate.expanded
                            && wifiNetworkDelegate.connectionStatusVisible
                        text: root.wifiStatusMessage
                        color: "#f38ba8"
                        font.family: "Cantarell"
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: availableWifiModel.count === 0
                    text: root.wifiEnabled ? "Atualizando lista de redes disponíveis..." :
                        "Wi-Fi desativado"
                    color: "#6c7086"
                    font.family: "Cantarell"
                    font.pixelSize: 12
                }
            }

            ActionTile {
                width: parent.width
                height: 38
                glyph: ""
                label: "Atualizar redes"
                visible: root.wifiDeviceAvailable && root.wifiEnabled
                enabled: availableWifiModel.count > 0
                    && !root.wifiPasswordInputExpanded()
                    && !root.connectingWifiSsid
                    && root.wifiDeviceAvailable
                    && root.wifiEnabled
                    && !availableWifiPoll.running
                    && !wifiScanDelay.running
                onClicked: {
                    if (root.wifiPasswordInputExpanded() || root.connectingWifiSsid
                            || availableWifiPoll.running || wifiScanDelay.running)
                        return
                    savedWifiPoll.running = true
                    root.requestWifiScan()
                }
            }
        }
    }

    Component {
        id: powerPage

        Column {
            width: root.width - 34
            spacing: 8

            Text {
                text: "Energia e sessão"
                color: "#cdd6f4"
                font.family: "Cantarell"
                font.pixelSize: 17
                font.weight: Font.DemiBold
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: 4
                ActionTile { width: parent.width; height: 40; glyph: ""; glyphColor: "#89b4fa"; label: "Bloquear sessão"; onClicked: root.runPowerAction("lock") }
                ActionTile { width: parent.width; height: 40; glyph: ""; glyphColor: "#89b4fa"; label: "Encerrar sessão"; onClicked: root.runPowerAction("logout") }
                ActionTile { width: parent.width; height: 40; glyph: ""; glyphColor: "#f9e2af"; label: "Suspender"; onClicked: root.runPowerAction("suspend") }
                ActionTile { width: parent.width; height: 40; glyph: ""; glyphColor: "#a6e3a1"; label: "Reiniciar…"; onClicked: root.runPowerAction("reboot") }
                ActionTile { width: parent.width; height: 40; glyph: ""; glyphColor: "#f38ba8"; label: "Desligar…"; onClicked: root.runPowerAction("poweroff") }
            }
        }
    }

    component ActionTile: Rectangle {
        id: tile
        required property string glyph
        required property string label
        property color glyphColor: "#89b4fa"
        property bool enabled: true

        signal clicked()

        radius: 11
        opacity: enabled ? 1.0 : 0.45

        color: !enabled ? "#1e1e2e" :
            actionMouse.pressed ? "#45475a" :
            actionMouse.containsMouse ? "#313244" : "#1e1e2e"

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
            Text {
                text: tile.glyph
                color: tile.glyphColor
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 26
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: tile.label
                color: "#cdd6f4"
                font.family: "Cantarell"
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: parent.width - 35
            }
        }
        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: tile.enabled

            onClicked: tile.clicked()
        }
    }

}
