pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell
import Quickshell.Wayland
import QtQuick

// Desenha o menu contextual (ContextMenu) acima de tudo no monitor onde foi
// aberto. Cobre a tela inteira para que um clique fora feche o menu.
PanelWindow {
  id: win

  required property ShellScreen targetScreen
  readonly property bool active: ContextMenu.open && ContextMenu.screen === targetScreen

  screen: targetScreen
  visible: active || menu.opacity > 0
  color: "transparent"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "quickshell-contextmenu"
  WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // Fechando: só a animação de saída, sem bloquear cliques.
  mask: Region { item: win.active ? fullArea : null }

  Item {
    id: fullArea
    anchors.fill: parent
    focus: win.active
    Keys.onEscapePressed: ContextMenu.close()
  }

  // Clique fora (qualquer botão) fecha.
  MouseArea {
    anchors.fill: parent
    enabled: win.active
    acceptedButtons: Qt.AllButtons
    onPressed: ContextMenu.close()
  }

  Rectangle {
    id: menu

    readonly property int margin: 6

    // Abre para baixo e à direita do cursor; vira para não sair da tela.
    x: Math.max(margin, ContextMenu.x + width > win.width - margin ? ContextMenu.x - width : ContextMenu.x)
    y: Math.max(margin, ContextMenu.y + height > win.height - margin ? ContextMenu.y - height : ContextMenu.y)
    width: Math.max(180, column.implicitWidth + 8)
    height: column.implicitHeight + 8
    radius: Theme.radius_m
    color: Theme.mantle
    border.width: 1
    border.color: Theme.outline
    opacity: win.active ? 1 : 0
    scale: win.active ? 1 : 0.96
    transformOrigin: Item.TopLeft

    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // O menu em si absorve os cliques para não fechar por "clique fora".
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Column {
      id: column
      x: 4
      y: 4
      width: parent.width - 8

      Repeater {
        model: ContextMenu.items

        delegate: Loader {
          id: entry
          required property var modelData
          required property int index
          width: column.width
          sourceComponent: modelData.separator ? separatorComponent : itemComponent

          Component {
            id: separatorComponent
            Item {
              implicitHeight: 9
              Rectangle {
                anchors.centerIn: parent
                width: parent.width - 12
                height: 1
                color: Theme.outline
              }
            }
          }

          Component {
            id: itemComponent
            Rectangle {
              readonly property bool enabledItem: entry.modelData.enabled !== false
              readonly property color tint: entry.modelData.danger ? Theme.red : Theme.text
              implicitWidth: row.implicitWidth + 24
              implicitHeight: 32
              radius: Theme.radius_s
              color: !enabledItem ? "transparent"
                : itemArea.pressed ? Theme.surface1
                : itemArea.containsMouse ? Theme.surface0 : "transparent"

              Behavior on color { ColorAnimation { duration: 100 } }

              Row {
                id: row
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 16
                  horizontalAlignment: Text.AlignHCenter
                  visible: !!entry.modelData.icon
                  text: entry.modelData.icon ?? ""
                  color: parent.parent.enabledItem ? parent.parent.tint : Theme.overlay0
                  font.family: Theme.font_awesome
                  font.weight: Font.Black
                  font.pixelSize: 12
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: entry.modelData.text ?? ""
                  color: parent.parent.enabledItem ? parent.parent.tint : Theme.overlay0
                  font.family: Theme.font_ui
                  font.pixelSize: 13
                }
              }

              MouseArea {
                id: itemArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: parent.enabledItem
                onClicked: ContextMenu.trigger(entry.index)
              }
            }
          }
        }
      }
    }
  }
}
