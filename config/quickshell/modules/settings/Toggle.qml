import qs.config
import QtQuick

// Interruptor liga/desliga das configurações.
Item {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    implicitWidth: 42
    implicitHeight: 24
    opacity: enabled ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.blue
            : mouse.containsMouse ? Theme.surface2 : Theme.surface1

        Behavior on color { ColorAnimation { duration: Config.ui_color_ms } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.crust : Theme.text

            Behavior on x {
                NumberAnimation { duration: Config.motion_fast_effect_ms; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: Config.ui_color_ms } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
