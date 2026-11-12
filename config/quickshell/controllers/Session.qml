pragma Singleton

import qs.config
import qs.controllers
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pam
import QtQuick

// Máquina de estados do bloqueio de sessão.
//
//   lock() ─▶ locked ─▶ (compositor confirma) surfaceSecure
//          ─▶ monitores vão para as workspaces vazias ─▶ ready (aceita senha)
//   senha correta ─▶ workspaces restauradas ─▶ desbloqueado
//
// As superfícies ficam em modules/lock; este singleton guarda apenas o estado
// e conversa com o PAM e o Hyprland.
Singleton {
    id: root

    // Estado público
    readonly property alias locked: state.locked
    readonly property alias ready: state.ready
    readonly property alias error: state.error
    readonly property alias blurVisible: state.blurVisible
    readonly property bool authenticating: pam.active
    // Definido pelo WlSessionLock quando o compositor garante o bloqueio.
    property bool surfaceSecure: false

    // Com workspaces vazias e sem blur, a barra pode continuar visível.
    readonly property bool barVisibleWhileLocked:
        Notifications.emptyWorkspaceOnLock && !Notifications.blurOnLock

    // Emitido quando a sessão está bloqueada e pronta para receber a senha.
    signal lockedAndReady()

    QtObject {
        id: state

        property bool locked: false
        property bool ready: false
        property string error: ""
        property bool blurVisible: false

        property bool workspacesApplied: false
        property int lockAttempts: 0
        property int restoreAttempts: 0
        property var savedWorkspaces: []      // [{ monitor, workspace }]
        property string previousMonitor: ""
        property string pendingPassword: ""
        property bool suspendPending: false
    }

    onSurfaceSecureChanged: {
        if (surfaceSecure)
            moveToLockWorkspaces()
    }

    function lockWorkspaceFor(monitorName: string): int {
        return Number(Config.lock_workspaces[monitorName] ?? 0)
    }

    function activeWorkspaceOf(monitorName: string): int {
        const monitor = Hyprland.monitors.values.find(item => item.name === monitorName)
        return monitor?.activeWorkspace?.id ?? 0
    }

    function lock(): void {
        if (state.locked)
            return

        Hyprland.refreshMonitors()
        const monitors = Hyprland.monitors.values
        state.savedWorkspaces = monitors.map(monitor => {
            const current = monitor.activeWorkspace?.id ?? 1
            // Nunca "restaure" para uma workspace reservada do bloqueio.
            const stuckOnLockWorkspace = current === root.lockWorkspaceFor(monitor.name)
            return {
                monitor: monitor.name,
                workspace: stuckOnLockWorkspace
                    ? Number(Config.home_workspaces[monitor.name] ?? 1)
                    : current
            }
        })
        state.previousMonitor = monitors.find(monitor => monitor.focused)?.name ?? Screens.primaryName
        state.workspacesApplied = false
        state.ready = false
        state.blurVisible = true
        state.error = ""
        Launcher.close()
        Notifications.trayOpen = false
        Notifications.popupSuppressed = true
        state.locked = true
    }

    // Bloqueia e suspende somente depois que a tela já está coberta.
    function suspend(): void {
        if (state.locked && state.ready) {
            Quickshell.execDetached(["systemctl", "suspend"])
            return
        }
        state.suspendPending = true
        lock()
    }

    function moveToLockWorkspaces(): void {
        if (!state.locked || !root.surfaceSecure || state.workspacesApplied)
            return

        if (!Notifications.emptyWorkspaceOnLock) {
            // Mantém as workspaces atuais; o blur em tela cheia permanece
            // durante todo o bloqueio para esconder o conteúdo.
            revealTimer.start()
            return
        }

        state.lockAttempts = 0
        lockPoll.start()
    }

    function applyLockWorkspaces(): void {
        if (!state.locked || !root.surfaceSecure)
            return

        // Cada monitor conhecido vai para a sua workspace vazia e persistente.
        // O blur só sai depois que o Hyprland confirma todas as trocas.
        const targets = state.savedWorkspaces
            .map(entry => ({ monitor: entry.monitor, workspace: root.lockWorkspaceFor(entry.monitor) }))
            .filter(target => target.workspace > 0)

        const retryDispatch = state.lockAttempts % 5 === 0
        Hyprland.refreshMonitors()
        if (retryDispatch) {
            for (const target of targets) {
                if (root.activeWorkspaceOf(target.monitor) === target.workspace)
                    continue
                Hypr.focusMonitor(target.monitor)
                Hypr.focusWorkspace(target.workspace)
            }
            Hyprland.refreshMonitors()
        }

        const allReady = targets.length > 0 && targets.every(target =>
            root.activeWorkspaceOf(target.monitor) === target.workspace)
        state.lockAttempts += 1

        if (allReady) {
            lockPoll.stop()
            revealTimer.start()
        } else if (state.lockAttempts >= 20) {
            // Continua coberto e permite autenticar mesmo que algum monitor
            // não tenha trocado; nunca revela um aplicativo como alternativa.
            lockPoll.stop()
            state.error = "Não foi possível preparar as áreas vazias."
            root.markReady()
        }
    }

    function reveal(): void {
        if (!state.locked || !root.surfaceSecure)
            return

        state.workspacesApplied = true
        // O blur só pode sair se todo monitor conectado estiver em uma
        // workspace vazia; um monitor sem workspace reservada ficaria exposto.
        const everyMonitorCovered = state.savedWorkspaces.every(entry =>
            root.lockWorkspaceFor(entry.monitor) > 0)
        if (root.barVisibleWhileLocked && everyMonitorCovered)
            state.blurVisible = false
        root.markReady()
    }

    function markReady(): void {
        state.ready = true
        root.lockedAndReady()
        if (state.suspendPending) {
            state.suspendPending = false
            Quickshell.execDetached(["systemctl", "suspend"])
        }
    }

    function authenticate(password: string): void {
        if (!state.locked || !state.ready || pam.active || password.length === 0)
            return

        state.error = ""
        state.pendingPassword = password
        if (!pam.start()) {
            state.pendingPassword = ""
            state.error = "Não foi possível iniciar a autenticação."
        }
    }

    function unlock(): void {
        if (!state.locked)
            return

        state.ready = false
        unlockDelay.restart()
    }

    function applyRestoreWorkspaces(): void {
        if (!state.locked)
            return

        Hyprland.refreshMonitors()
        const connected = Hyprland.monitors.values.map(monitor => monitor.name)
        const targets = state.savedWorkspaces.filter(entry => connected.includes(entry.monitor))

        if (state.restoreAttempts % 4 === 0) {
            for (const entry of targets) {
                if (root.activeWorkspaceOf(entry.monitor) === entry.workspace)
                    continue
                Hypr.focusMonitor(entry.monitor)
                Hypr.focusWorkspace(entry.workspace)
            }
            Hyprland.refreshMonitors()
        }

        const allRestored = targets.every(entry =>
            root.activeWorkspaceOf(entry.monitor) === entry.workspace)

        state.restoreAttempts += 1
        if (!allRestored && state.restoreAttempts < 60)
            return

        restorePoll.stop()
        if (connected.includes(state.previousMonitor))
            Hypr.focusMonitor(state.previousMonitor)

        state.workspacesApplied = false
        state.blurVisible = false
        state.savedWorkspaces = []
        state.previousMonitor = ""
        state.locked = false
        Notifications.popupSuppressed = false
    }

    PamContext {
        id: pam
        config: "login"
        user: Quickshell.env("USER")

        onResponseRequiredChanged: {
            if (pam.responseRequired && state.pendingPassword.length > 0) {
                const password = state.pendingPassword
                state.pendingPassword = ""
                pam.respond(password)
            }
        }

        onCompleted: result => {
            state.pendingPassword = ""
            if (result === PamResult.Success)
                root.unlock()
            else if (result === PamResult.Failed || result === PamResult.MaxTries)
                state.error = "Senha incorreta. Tente novamente."
            else
                state.error = "Falha ao validar a senha."
        }
    }

    Timer {
        id: unlockDelay
        interval: 220
        onTriggered: {
            state.restoreAttempts = 0
            restorePoll.start()
        }
    }

    Timer {
        id: lockPoll
        interval: 35
        repeat: true
        onTriggered: root.applyLockWorkspaces()
    }

    Timer {
        id: restorePoll
        interval: 35
        repeat: true
        onTriggered: root.applyRestoreWorkspaces()
    }

    Timer {
        id: revealTimer
        interval: 520
        onTriggered: root.reveal()
    }
}
