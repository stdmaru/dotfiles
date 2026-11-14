pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.config
import qs.controllers
import qs.components.common

// Menu suspenso do canto direito da barra, com as páginas de rede, som e
// energia. Este arquivo cuida apenas da janela: abrir/fechar, foco e a
// transição entre páginas; o conteúdo fica em *Page.qml.
//
// A janela é uma camada em tela cheia: enquanto o menu está aberto, qualquer
// clique fora do painel cai nela e fecha o menu. A máscara de entrada tem
// furos sobre os botões que alternam as páginas, então esses cliques chegam à
// barra e o toggle() decide. O teclado só é pedido quando o campo de senha do
// Wi-Fi recebe foco: uma superfície focada sem campo de texto faz o
// text-input-v3 do Qt emitir avisos a cada troca de foco.
PanelWindow {
    id: root

    required property PanelWindow parentWindow
    // Distância do topo da janela até a borda inferior da barra.
    required property real barBottom
    // Botões da barra que abrem/alternam o menu; cliques neles atravessam a
    // camada.
    property list<Item> toggleButtons

    readonly property int panelWidth: 360
    readonly property int maxPanelHeight: 538
    // "network", "sound", "power" ou "" (fechado).
    property string menuType: ""
    property string previousMenuType: ""
    property bool isOpen: false
    // Um campo de texto do painel pediu o teclado.
    property bool keyboardWanted: false
    property int slideDirection: -1
    property real panelProgress: 0
    property real pageProgress: 1
    property real panelContentHeight: 0
    property string soundTab: "outputs"

    screen: parentWindow.screen
    visible: false
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-systemmenu"
    WlrLayershell.keyboardFocus: keyboardWanted && isOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Fechando, a máscara fica vazia para os cliques atravessarem durante a
    // animação de saída.
    mask: Region {
        width: root.isOpen ? root.width : 0
        height: root.isOpen ? root.height : 0

        Region { item: root.toggleButtons[0] ?? null; intersection: Intersection.Subtract }
        Region { item: root.toggleButtons[1] ?? null; intersection: Intersection.Subtract }
        Region { item: root.toggleButtons[2] ?? null; intersection: Intersection.Subtract }
    }

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

    // Nos demais monitores, um clique em qualquer lugar também fecha o menu.
    Variants {
        model: Quickshell.screens.filter(s => s !== root.screen)

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            visible: root.isOpen
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-systemmenu-shield"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.closeMenu()
            }
        }
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
            panelContentHeight = Math.min(currentPage.item.implicitHeight + 36, maxPanelHeight)
    }

    function toggle(type: string): void {
        if (isOpen && menuType === type) {
            closeMenu()
            return
        }

        if (!isOpen) {
            menuType = type
            previousMenuType = ""
            isOpen = true
            visible = true

            panelProgress = 0
            // A janela leva alguns ms para aparecer na primeira vez; animar
            // antes disso deixaria o canto da barra reto sobre o nada.
            if (backingWindowVisible)
                startOpening()
            else
                openPending = true

            Qt.callLater(root.updatePanelContentHeight)
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

    property bool openPending: false

    function startOpening(): void {
        openPending = false
        panelAnimation.to = 1
        panelAnimation.restart()
    }

    onBackingWindowVisibleChanged: {
        if (backingWindowVisible)
            TooltipManager.dismiss()
        if (backingWindowVisible && openPending && isOpen)
            startOpening()
    }

    function closeMenu(): void {
        if (!isOpen)
            return
        isOpen = false
        openPending = false
        keyboardWanted = false
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

    Item {
        anchors.fill: parent

        // Clique fora do painel fecha.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.closeMenu()
        }
    }

    // O menu ocupa o canto superior direito: a lateral direita se funde à
    // moldura (ou continua reta a borda da barra, cujo canto se endireita) e
    // a esquerda desce da barra numa rampa.
    ShadowLayer {
        anchors.fill: parent
        clipToWorkArea: true

        DockSilhouette {
            x: panel.x
            y: panel.y
            width: panel.width
            height: panel.height
            leftEdge: "ramp"
            rightEdge: Config.frame_enabled ? "border" : "flush"
        }
    }

    Rectangle {
        id: panel
        x: root.width - root.panelWidth
            - (Config.frame_enabled ? Config.frame_thickness : Config.bar_margin)
        y: root.barBottom
        width: root.panelWidth
        height: Math.min(root.panelContentHeight * root.panelProgress, root.maxPanelHeight)
        // Só recorta o conteúdo; o fundo é a silhueta desenhada atrás.
        color: "transparent"
        clip: true
        Keys.onEscapePressed: root.closeMenu()

        // Cliques no próprio painel não chegam à área que fecha o menu.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Item {
            id: pageViewport
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            opacity: root.panelProgress

            // Página que está saindo durante a troca de aba.
            Loader {
                id: outgoingPage
                active: root.previousMenuType !== ""
                sourceComponent: root.componentFor(root.previousMenuType)
                width: pageViewport.width
                height: item?.implicitHeight ?? 0
                z: 0
                opacity: 1 - root.pageProgress
                transform: Translate { x: -root.slideDirection * root.panelWidth * root.pageProgress }
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
                        ? root.slideDirection * root.panelWidth * (1 - root.pageProgress)
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

    // Abre a janela de configurações do shell; fica no canto do cabeçalho de
    // todas as páginas.
    Rectangle {
        id: settingsButton

        x: panel.x + panel.width - width - 12
        y: panel.y + 12
        width: 30
        height: 30
        radius: Theme.radius_s
        opacity: root.panelProgress
        visible: panel.height > height + 24
        color: settingsMouse.pressed ? Theme.surface1
            : settingsMouse.containsMouse ? Theme.surface0 : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "\uf013"
            color: settingsMouse.containsMouse ? Theme.text : Theme.overlay1
            font.family: Theme.font_awesome
            font.weight: Font.Black
            font.pixelSize: 14
        }

        MouseArea {
            id: settingsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.closeMenu()
                Settings.show("")
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
            // Só agora a camada pede o teclado, já com o campo focado.
            onInputFocused: root.keyboardWanted = true
        }
    }

    Component {
        id: powerPage

        PowerPage {
            onActionRequested: action => root.runPowerAction(action)
        }
    }
}
