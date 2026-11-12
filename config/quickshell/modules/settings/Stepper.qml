pragma ComponentBehavior: Bound

import qs.config
import QtQuick

// Valor inteiro com botões − e +; a roda do mouse também ajusta.
Rectangle {
    id: root

    property int value: 0
    property int from: 0
    property int to: 100
    property int stepSize: 1
    property string unit: ""

    signal moved(int value)

    function nudge(direction: int): void {
        const next = Math.max(root.from, Math.min(root.to, root.value + direction * root.stepSize))
        if (next !== root.value)
            root.moved(next)
    }

    implicitWidth: 132
    implicitHeight: 32
    radius: Theme.radius_s
    color: Theme.surface0
    opacity: enabled ? 1 : 0.45

    component StepButton: Rectangle {
        id: stepButton

        required property string glyph
        required property int direction
        readonly property bool available: stepButton.direction < 0
            ? root.value > root.from : root.value < root.to

        width: 32
        height: root.height
        radius: Theme.radius_s
        color: stepMouse.pressed && available ? Theme.surface2
            : stepMouse.containsMouse && available ? Theme.surface1 : "transparent"

        Behavior on color { ColorAnimation { duration: Config.ui_color_ms } }

        Text {
            anchors.centerIn: parent
            text: stepButton.glyph
            color: stepButton.available ? Theme.text : Theme.overlay0
            font.family: Theme.font_ui
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: stepMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: stepButton.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.nudge(stepButton.direction)
            // Segurar repete o passo.
            onPressAndHold: repeat.start()
            onReleased: repeat.stop()
            onCanceled: repeat.stop()
        }

        Timer {
            id: repeat
            interval: 70
            repeat: true
            onTriggered: root.nudge(stepButton.direction)
        }
    }

    StepButton {
        anchors.left: parent.left
        glyph: "−"
        direction: -1
    }

    Text {
        anchors.centerIn: parent
        text: root.unit ? `${root.value} ${root.unit}` : String(root.value)
        color: Theme.text
        font.family: Theme.font_ui
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    StepButton {
        anchors.right: parent.right
        glyph: "+"
        direction: 1
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.nudge(event.angleDelta.y > 0 ? 1 : -1)
    }
}
