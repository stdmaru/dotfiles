pragma Singleton

import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls

Singleton {
    id: root

    property Item activeTarget: null
    property Item displayTarget: null
    property string activeText: ""
    property int delay: 350

    ToolTip {
        id: popup

        text: root.activeText
        parent: root.displayTarget
        delay: -1
        timeout: -1
        padding: 0
        visible: false
        closePolicy: Popup.NoAutoClose
        x: root.displayTarget ? Math.round((root.displayTarget.width - width) / 2) : 0
        y: root.displayTarget ? root.displayTarget.height + 7 : 0
        implicitWidth: Math.min(320, Math.max(96, textMetrics.advanceWidth + 24))
        implicitHeight: tooltipLabel.implicitHeight + 18
        opacity: 0

        TextMetrics {
            id: textMetrics
            text: root.longestLine(root.activeText)
            font.family: Theme.font_ui
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        background: Rectangle {
            radius: Theme.radius_s
            color: Theme.mantle
            opacity: 0.925
            border.width: 1
            border.color: Theme.outline
        }

        contentItem: Text {
            id: tooltipLabel
            text: root.activeText
            width: popup.width - 24
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 12
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.Wrap
        }
    }

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

            popup.opacity = 0
            popup.visible = true
            showAnimation.restart()
        }
    }

    NumberAnimation {
        id: showAnimation
        target: popup
        property: "opacity"
        to: 1
        duration: 130
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnimation
        target: popup
        property: "opacity"
        to: 0
        duration: 100
        easing.type: Easing.InCubic
        onFinished: {
            if (root.activeTarget)
                return
            popup.visible = false
            root.displayTarget = null
        }
    }

    function show(target, text): void {
        if (!target || !text)
            return

        const sameTarget = root.activeTarget === target
        root.activeTarget = target
        root.activeText = String(text)
        if (sameTarget && (showTimer.running || popup.visible))
            return

        showTimer.stop()
        showAnimation.stop()
        hideAnimation.stop()
        popup.visible = false
        popup.opacity = 0
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
        if (!popup.visible) {
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
