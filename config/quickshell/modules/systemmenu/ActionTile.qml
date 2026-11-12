import qs.config
import QtQuick

// Botão em faixa com ícone e rótulo, usado nas páginas do menu do sistema.
Rectangle {
    id: tile
    required property string glyph
    required property string label
    property color glyphColor: Theme.blue

    signal clicked()

    radius: 11
    opacity: enabled ? 1.0 : 0.45

    color: !enabled ? Theme.base :
        actionMouse.pressed ? Theme.surface1 :
        actionMouse.containsMouse ? Theme.surface0 : Theme.base

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10
        Text {
            text: tile.glyph
            color: tile.glyphColor
            font.family: Theme.font_nerd
            font.pixelSize: 26
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: tile.label
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: parent.width - 35
        }
    }
    MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.enabled

        onClicked: tile.clicked()
    }
}
