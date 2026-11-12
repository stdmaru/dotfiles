pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

// Superfície de bloqueio de um monitor. Todas cobrem a tela; apenas a do
// monitor principal mostra o cartão de login e o resumo de notificações.
WlSessionLockSurface {
  id: root

  readonly property bool isPrimary: Screens.isPrimary(root.screen)

  color: "transparent"

  Loader {
    anchors.fill: parent
    active: root.isPrimary
    sourceComponent: Item {
      Rectangle {
        id: loginCard
        enabled: Session.ready
        width: 390
        height: contentColumn.implicitHeight + contentColumn.anchors.margins * 2
        anchors.centerIn: parent
        radius: Theme.radius_l
        color: "#ee181825"
        border.width: 1
        border.color: Theme.outline
        opacity: Session.ready ? 1 : 0
        scale: Session.ready ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

        function submit(): void {
          Session.authenticate(passwordField.text)
          passwordField.clear()
          passwordField.forceActiveFocus()
        }

        Column {
          id: contentColumn
          anchors.fill: parent
          anchors.margins: 28
          spacing: 5

          Text {
            width: parent.width
            text: "Sessão bloqueada"
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 23
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
          }

          Item { width: 1; height: 5 }

          TextField {
            id: passwordField
            width: parent.width
            height: 46
            placeholderText: "Digite sua senha"
            placeholderTextColor: Theme.overlay0
            echoMode: TextInput.Password
            enabled: Session.ready && !Session.authenticating
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 15
            leftPadding: 14
            rightPadding: 14
            background: Rectangle {
              radius: Theme.radius_s
              color: Theme.crust
              border.width: passwordField.activeFocus ? 2 : 1
              border.color: passwordField.activeFocus ? Theme.blue : Theme.outline
            }
            onAccepted: loginCard.submit()
            // O campo é desabilitado durante a validação e perde o foco;
            // devolva-o para a próxima tentativa.
            onEnabledChanged: {
              if (enabled)
                Qt.callLater(passwordField.forceActiveFocus)
            }
          }

          Text {
            width: parent.width
            height: 18
            text: Session.authenticating ? "Validando…" : Session.error
            color: Session.error && !Session.authenticating ? Theme.red : Theme.subtext0
            font.family: Theme.font_ui
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }

          Button {
            id: unlockButton
            width: parent.width
            height: 42
            text: "Desbloquear"
            enabled: Session.ready && !Session.authenticating && passwordField.text.length > 0
            onClicked: loginCard.submit()
            contentItem: Text {
              text: unlockButton.text
              color: Theme.crust
              font.family: Theme.font_ui
              font.pixelSize: 14
              font.weight: Font.DemiBold
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: Theme.radius_s
              color: unlockButton.enabled ? (unlockButton.down ? Theme.sapphire : Theme.blue) : Theme.surface1
            }
          }
        }
      }

      LockNotificationStrip {
        width: loginCard.width
        anchors.horizontalCenter: loginCard.horizontalCenter
        anchors.bottom: loginCard.top
        anchors.bottomMargin: 16
        visible: Session.ready && hasNotifications
        opacity: Session.ready ? 1 : 0
      }
    }
  }
}
