pragma Singleton

import qs.config
import Quickshell
import QtQuick

Singleton {
    id: root

    property Item activeTarget: null
    property Item displayTarget: null
    property string activeText: ""
    property int delay: 350

    // Posição do alvo na tela, capturada ao mostrar. A dica é desenhada pela
    // TooltipLayer (modules/screen).
    property rect anchorRect: Qt.rect(0, 0, 0, 0)
    property bool shown: false

    // Um painel que surge depois da dica fica por cima dela (camadas da mesma
    // altura empilham por ordem de criação). Em vez de recriá-la por cima,
    // a dica atual some de vez; a próxima aparece quando o cursor entrar em
    // outro controle (ou sair e voltar), já acima do painel. Chamado pelos
    // painéis quando terminam de aparecer.
    function dismiss(): void {
        showTimer.stop()
        showAnimation.stop()
        hideAnimation.stop()
        root.activeTarget = null
        root.displayTarget = null
        root.shown = false
        root.opacity = 0
    }

    // Opacidade da dica, animada aqui e aplicada pela TooltipLayer.
    property real opacity: 0

    Timer {
        id: showTimer
        interval: root.delay
        repeat: false
        onTriggered: {
            if (!root.activeTarget || !root.activeText || !root.targetStillHovered(root.activeTarget)) {
                root.activeTarget = null
                root.displayTarget = null
                return
            }

            const target = root.activeTarget
            const p = target.mapToItem(null, 0, 0)
            root.anchorRect = Qt.rect(p.x, p.y, target.width, target.height)
            root.opacity = 0
            root.shown = true
            showAnimation.restart()
        }
    }

    NumberAnimation {
        id: showAnimation
        target: root
        property: "opacity"
        to: 1
        duration: 130
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnimation
        target: root
        property: "opacity"
        to: 0
        duration: 100
        easing.type: Easing.InCubic
        onFinished: {
            if (root.activeTarget)
                return
            root.shown = false
            root.displayTarget = null
        }
    }

    function show(target, text): void {
        if (!target || !text)
            return

        const sameTarget = root.activeTarget === target
        root.activeTarget = target
        root.activeText = String(text)
        if (sameTarget && (showTimer.running || root.shown))
            return

        showTimer.stop()
        showAnimation.stop()
        hideAnimation.stop()
        root.shown = false
        root.opacity = 0
        root.displayTarget = target
        showTimer.restart()
    }

    function hide(target): void {
        // A late exit event from the previous control must not affect the
        // tooltip already requested by the next hovered control.
        if (!target || root.activeTarget !== target)
            return

        root.activeTarget = null
        showTimer.stop()
        showAnimation.stop()
        if (!root.shown) {
            root.displayTarget = null
            return
        }
        hideAnimation.restart()
    }

    function targetStillHovered(target): bool {
        if (!target)
            return false
        if (target.hovered !== undefined)
            return Boolean(target.hovered)
        if (target.containsMouse !== undefined)
            return Boolean(target.containsMouse)
        return false
    }

    function longestLine(value): string {
        const lines = String(value || "").split(/\r?\n/)
        let longest = ""
        for (const line of lines) {
            if (line.length > longest.length)
                longest = line
        }
        return longest
    }
}
