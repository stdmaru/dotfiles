pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.config
import qs.controllers

// Menu suspenso do canto direito da barra, com as páginas de rede, som e
// energia. Este arquivo cuida apenas da janela: abrir/fechar, foco e a
// transição entre páginas; o conteúdo fica em *Page.qml.
PopupWindow {
    id: root

    required property PanelWindow parentWindow
    // Distância do topo da janela até a borda inferior da barra.
    required property real barBottom

    readonly property int panelWidth: 360
    // "network", "sound", "power" ou "" (fechado).
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
    property string soundTab: "outputs"

    implicitWidth: panelWidth
    // A superfície Wayland do popup tem tamanho fixo: redimensionar a janela a
    // cada quadro de animação gera ciclos de configure/commit. Só o painel
    // desenhado dentro dela cresce e encolhe.
    implicitHeight: 540
    visible: false
    color: "transparent"
    grabFocus: false
    mask: Region { item: panel }

    anchor.window: parentWindow
    anchor.rect.x: parentWindow.width - width - 8
    anchor.rect.y: barBottom + 3

    Behavior on panelContentHeight {
        enabled: root.isOpen
        NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
    }

    // A varredura de Wi-Fi só roda com a página de rede na tela.
    Binding {
        target: Network
        property: "scanWanted"
        value: root.visible && root.menuType === "network"
    }

    IpcHandler {
        target: "systemmenu"
        function toggle(page: string): void {
            if (["network", "sound", "power"].includes(page))
                root.toggle(page)
        }
        function close(): void { root.closeMenu() }
    }

    HyprlandFocusGrab {
        active: root.isOpen && root.focusGrabEnabled

        windows: [root]

        onCleared: {
            root.focusGrabEnabled = false

            // O clique que desfez o grab foi em um dos botões da barra que
            // alternam o menu: rearme e deixe o toggle() decidir.
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

    // Chamado pelos botões da barra em onPressedChanged, antes do clique.
    function noteToggleButtonPress(pressed: bool): void {
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

    function rearmFocusGrab(): void {
        if (!root.isOpen)
            return
        root.focusGrabEnabled = false
        Qt.callLater(() => {
            if (root.isOpen)
                root.focusGrabEnabled = true
        })
    }

    function pageIndex(type: string): int {
        return type === "power" ? 0 : type === "sound" ? 1 : 2
    }

    function componentFor(type: string): Component {
        if (type === "sound") return soundPage
        if (type === "network") return networkPage
        if (type === "power") return powerPage
        return null
    }

    function updatePanelContentHeight(): void {
        if (currentPage.item)
            panelContentHeight = Math.min(currentPage.item.implicitHeight + 36, height - 4)
    }

    function toggle(type: string): void {
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
            }
            previousMenuType = menuType
            slideDirection = pageIndex(type) > pageIndex(menuType) ? 1 : -1
            menuType = type
            pageProgress = 0
            pageAnimation.restart()
            Qt.callLater(root.updatePanelContentHeight)
        }
    }

    function closeMenu(): void {
        if (!isOpen)
            return
        dismissTimer.stop()
        pressRecoveryTimer.stop()
        isOpen = false
        panelAnimation.to = 0
        panelAnimation.restart()
    }

    function confirm(title: string, confirmLabel: string, icon: string, iconColor: color, onConfirm: var): void {
        Dialogs.showPrompt(
            "Os aplicativos serão encerrados e a sessão será finalizada.",
            [
                { text: "Cancelar", value: "cancel", role: "normal" },
                { text: confirmLabel, value: "confirm", role: "primary" }
            ],
            title,
            icon,
            iconColor,
            value => {
                if (value === "confirm")
                    onConfirm()
            }
        )
    }

    function runPowerAction(action: string): void {
        closeMenu()

        if (action === "lock")
            Session.lock()
        else if (action === "suspend")
            Session.suspend()
        else if (action === "logout")
            confirm("Encerrar a sessão?", "Encerrar", "", Theme.blue,
                () => Hypr.exitSession())
        else if (action === "reboot")
            confirm("Reiniciar o computador?", "Reiniciar", "", Theme.green,
                () => Quickshell.execDetached(["systemctl", "reboot"]))
        else if (action === "poweroff")
            confirm("Desligar o computador?", "Desligar", "", Theme.red,
                () => Quickshell.execDetached(["systemctl", "poweroff"]))
    }

    Connections {
        target: Session
        function onLockedChanged(): void {
            if (Session.locked)
                root.closeMenu()
        }
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

    Rectangle {
        id: panel
        x: 1
        y: 1 + (1 - root.panelProgress) * -10
        width: root.width - 2
        height: Math.min(root.panelContentHeight * root.panelProgress, root.height - 2)
        radius: 18
        color: Theme.crust
        border.width: 1
        border.color: "#303044"
        opacity: root.panelProgress
        clip: true

        Item {
            id: pageViewport
            anchors.fill: parent
            anchors.margins: 16
            clip: true

            // Página que está saindo durante a troca de aba.
            Loader {
                id: outgoingPage
                active: root.previousMenuType !== ""
                sourceComponent: root.componentFor(root.previousMenuType)
                width: pageViewport.width
                height: item?.implicitHeight ?? 0
                z: 0
                opacity: 1 - root.pageProgress
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
                function onImplicitHeightChanged(): void { root.updatePanelContentHeight() }
            }
        }
    }

    Component {
        id: soundPage

        SoundPage {
            tab: root.soundTab
            onTabChanged: root.soundTab = tab
        }
    }

    Component {
        id: networkPage

        NetworkPage {
            // Digitar a senha não pode disparar o fechamento por perda de foco.
            onInputFocused: dismissTimer.stop()
        }
    }

    Component {
        id: powerPage

        PowerPage {
            onActionRequested: action => root.runPowerAction(action)
        }
    }
}
