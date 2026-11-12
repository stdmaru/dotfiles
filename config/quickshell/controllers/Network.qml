pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Estado de rede via NetworkManager (nmcli): conexão ativa, rádio Wi-Fi,
// redes disponíveis e perfis salvos, além de conectar/desconectar/esquecer.
//
// O estado geral é atualizado por eventos do `nmcli monitor`; a varredura de
// redes Wi-Fi (cara, e que atrapalha a conexão em uso) só roda enquanto a
// interface pede, via `scanWanted`.
Singleton {
    id: root

    // Ligado pela página de rede enquanto ela está visível.
    property bool scanWanted: false
    readonly property alias availableWifi: availableWifiModel
    readonly property bool scanPending: availableWifiPoll.running || wifiScanDelay.running
    readonly property bool online: connectionKind !== ""

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

    onScanWantedChanged: {
        if (root.scanWanted) {
            root.refresh()
            root.requestWifiScan()
        } else {
            wifiScanDelay.stop()
            root.expandedWifiSsid = ""
        }
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

    function init(): void {
        root.refresh()
    }

    // Relê o estado barato: dispositivos, rádio, conexão ativa e perfis.
    function refresh(): void {
        wifiDevicePoll.running = true
        wifiPoll.running = true
        connectionPoll.running = true
        savedWifiPoll.running = true
    }

    function setWifiEnabled(enabled: bool): void {
        root.wifiEnabled = enabled
        if (!enabled) {
            root.expandedWifiSsid = ""
            wifiScanDelay.stop()
            availableWifiPoll.running = false
            root.updateAvailableWifiNetworks([])
        } else {
            root.requestWifiScan()
        }

        Quickshell.execDetached(["nmcli", "radio", "wifi", enabled ? "on" : "off"])
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
        if (!root.scanWanted || !root.wifiEnabled || !root.wifiDeviceAvailable
                || root.wifiScanPaused()) {
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
        if (!root.scanWanted || !root.wifiEnabled || !root.wifiDeviceAvailable
                || root.wifiScanPaused() || availableWifiPoll.running)
            return

        root.lastWifiScanAt = Date.now()
        availableWifiPoll.running = true
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
                connectionPoll.running = true
                savedWifiPoll.running = true
                root.requestWifiScan()
                wifiStatusTimer.stop()
            } else {
                root.wifiStatusMessage = "Falha ao esquecer rede"
                root.wifiStatusError = true
                connectionPoll.running = true
                savedWifiPoll.running = true
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
            connectionPoll.running = true
            savedWifiPoll.running = true
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
            connectionPoll.running = true
            savedWifiPoll.running = true
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
        savedWifiPoll.running = true
        root.requestWifiScan()
        connectionPoll.running = true
    }

    // Qualquer linha do monitor indica mudança; agrupa rajadas de eventos.
    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 400
        onTriggered: root.refresh()
    }

    // Rede de segurança caso o monitor morra ou perca algum evento.
    Timer {
        running: true
        repeat: true
        interval: 60000
        onTriggered: {
            if (!monitor.running)
                monitor.running = true
            root.refresh()
            root.requestWifiScan()
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
}
