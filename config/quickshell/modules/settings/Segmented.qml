pragma ComponentBehavior: Bound

import qs.config
import QtQuick

// Escolha única entre poucas opções ({ value, label }), lado a lado.
Rectangle {
    id: root

    property var options: []
    property string value: ""

    signal selected(string value)

    implicitWidth: row.implicitWidth + 6
    implicitHeight: 32
    radius: Theme.radius_s
    color: Theme.surface0
    opacity: enabled ? 1 : 0.45

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: option

                required property var modelData
                readonly property bool current: modelData.value === root.value

                width: Math.max(56, label.implicitWidth + 22)
                height: row.height
                radius: Theme.radius_s - 2
                color: current ? Theme.surface2
                    : optionMouse.containsMouse ? Theme.surface1 : "transparent"

                Behavior on color { ColorAnimation { duration: Config.ui_color_ms } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: option.modelData.label
                    color: option.current ? Theme.white : Theme.subtext0
                    font.family: Theme.font_ui
                    font.pixelSize: 12
                    font.weight: option.current ? Font.DemiBold : Font.Normal
                }

                MouseArea {
                    id: optionMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!option.current)
                            root.selected(option.modelData.value)
                    }
                }
            }
        }
    }
}
