pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Controls
import qs.config

import qs.components.common

// Menu de contexto dos ícones da bandeja. Desce da barra como os demais
// painéis: uma silhueta com rampas dos dois lados, centrada no ícone.
Item {
    id: root

    required property PanelWindow parentWindow
    property bool isOpen: false
    property real openX: 0
    // 0 = recolhido na barra, 1 = aberto.
    property real progress: 0
    // Altura do conteúdo, animada quando um submenu troca de tamanho.
    property real contentHeight: menuStack.currentItem ? menuStack.currentItem.implicitHeight : 0
    readonly property real contentWidth: Math.max(
        menuStack.currentItem ? menuStack.currentItem.implicitWidth : 0, 150)

    width: parentWindow.screen.width
    height: parentWindow.screen.height
    visible: false
    z: 1

    Behavior on contentHeight {
        enabled: root.progress === 1
        NumberAnimation {
            duration: Config.motion_spatial_ms
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Config.motion_spatial_curve
        }
    }

    // Alguns aplicativos (o Steam, por exemplo) entregam os itens do menu aos
    // poucos. A abertura espera a altura parar de mudar por um instante, até
    // um limite, para não começar animando um menu vazio.
    Timer {
        id: settleTimer
        interval: 60
        onTriggered: root.startOpening()
    }
    Timer {
        id: settleLimit
        interval: 400
        onTriggered: root.startOpening()
    }
    onContentHeightChanged: {
        if (settleLimit.running)
            settleTimer.restart()
    }

    NumberAnimation {
        id: progressAnimation
        target: root
        property: "progress"
        duration: 280
        easing.type: Easing.OutCubic
        onFinished: {
            if (!root.isOpen) {
                root.visible = false
                menuStack.clear()
            }
        }
    }

    // Clique fora fecha; com botão direito, volta um nível do submenu.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.isOpen

        onClicked: (mouseEvent) => {
            if (mouseEvent.button === Qt.RightButton && menuStack.depth > 1)
                menuStack.pop()
            else
                root.close()
        }
    }

    DockSilhouette {
        x: menuContainer.x
        y: menuContainer.y
        width: menuContainer.width
        height: menuContainer.height
    }

    Item {
        id: menuContainer

        // As rampas saem para fora do painel; ele fica dentro da barra com
        // folga para elas.
        readonly property real edge: (Config.frame_enabled ? Config.frame_thickness : Config.bar_margin)
            + Config.panel_curve * 2

        width: root.contentWidth
        height: root.contentHeight * root.progress
        x: Math.max(edge, Math.min(root.width - width - edge, root.openX - width / 2))
        y: Config.bar_bottom
        clip: true
        z: 2

        // Consome cliques em áreas vazias do menu.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            hoverEnabled: true
            onClicked: (mouseEvent) => {
                if (mouseEvent.button === Qt.RightButton && menuStack.depth > 1)
                    menuStack.pop()
            }
        }

        StackView {
            id: menuStack
            initialItem: null
            // O conteúdo fica no tamanho final enquanto o painel recortado cresce.
            width: root.contentWidth
            height: root.contentHeight
            opacity: root.progress

            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: menuContainer.width; to: 0; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

            pushExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 0; to: -menuContainer.width; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: -menuContainer.width; to: 0; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 0; to: menuContainer.width; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

        }

        component MenuView: Column {
            id: menuView
            property bool isSubmenu
            required property QsMenuHandle handle
            spacing: 5
            padding: 10

            QsMenuOpener {
                id: menuOpener
                menu: menuView.handle
            }

            // BOTÃO VOLTAR
            Rectangle {
                visible: menuView.isSubmenu
                implicitHeight: 25
                implicitWidth: implicitHeight * 2
                radius: implicitHeight
                color: Theme.outline

                Text {
                    anchors.centerIn: parent
                    text: "\uf060"
                    font.family: Theme.font_awesome
                    font.pixelSize: 14
                    color: Theme.text
                }

                MouseArea {
                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: menuStack.pop()

                    onEntered: parent.color = Theme.surface0Hover
                    onExited: parent.color = Theme.outline
                }
            }

            Repeater {
                id: menuRepeater
                model: menuOpener.children
                delegate: Rectangle {
                    // MenuItem
                    id: item
                    required property QsMenuEntry modelData

                    property bool isEnabled: item.modelData?.enabled ?? false
                    property bool isSeparator: item.modelData?.isSeparator ?? false
                    property bool hasChildren: item.modelData?.hasChildren ?? false
                    property string icon: item.modelData?.icon ?? ""
                    property bool buttonType: item.modelData?.buttonType ?? false
                    property bool checked: item.modelData?.checkState ?? false

                    implicitWidth: 250
                    radius: 4
                    height: !isSeparator ? 25 : 1
                    color: "transparent"

                    Row {
                        padding: 5
                        spacing: 5
                        visible: !item.isSeparator
                        anchors.verticalCenter: parent.verticalCenter

                        // Checkboxes if applicable
                        Text {
                            visible: item.buttonType > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: (item.checked) ? "\uf14a" : "\uf0c8"
                            font.family: Theme.font_awesome
                            font.pixelSize: 14
                            color: Theme.text
                        }

                        // Icon if applicable
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            id: icon
                            visible: item.icon !== ""
                            source: item.icon
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }

                        // Label if applicable
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            id: label
                            visible: !item.isSeparator
                            text: !item.isSeparator ? item.modelData.text : "------------------"
                            font.family: Theme.font_display
                            color: item.isEnabled ? Theme.text : Theme.overlay0
                        }
                    }

                    // Submenu Arrow  if applicable
                    Text {
                        visible: item.hasChildren
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 5
                        text: "\uf0da"
                        font.family: Theme.font_awesome
                        font.pixelSize: 8
                        color: Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !item.isSeparator
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        onClicked: (mouseEvent) => {
                            const entry = item.modelData;
                            if(!item.modelData.enabled) return;

                            if(item.hasChildren) {
                                // Open submenu
                                // Criado pelo StackView, que o destrói ao sair.
                                menuStack.push(menuComponent, {
                                    handle: entry,
                                    isSubmenu: true
                                });
                            } else {
                                item.modelData.triggered()
                                root.close()
                            }
                        }
                        onEntered: () => {
                            if(!item.isEnabled) return
                            item.color = Theme.surface0
                        }
                        onExited: () => {
                            item.color = "transparent"
                        }
                    }

                    // Separator if applicable
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: item.modelData?.isSeparator
                        height: 1
                        color: Theme.outline
                    }
                }
            }
        }
    }

    Component {
        id: menuComponent
        MenuView {}
    }

    function animateTo(target: real): void {
        progressAnimation.stop()
        progressAnimation.from = root.progress
        progressAnimation.to = target
        progressAnimation.start()
    }

    function open(defaultMenuHandle: QsMenuHandle, x: int, y: int): void {
        root.openX = x
        menuStack.clear()
        menuStack.push(menuComponent, {
            handle: defaultMenuHandle,
            isSubmenu: false
        })
        root.visible = true
        root.isOpen = true
        progressAnimation.stop()
        settleTimer.restart()
        settleLimit.restart()
    }

    function startOpening(): void {
        settleTimer.stop()
        settleLimit.stop()
        if (root.isOpen)
            animateTo(1)
    }

    function close(): void {
        if (!root.isOpen)
            return
        root.isOpen = false
        settleTimer.stop()
        settleLimit.stop()
        animateTo(0)
    }

}
