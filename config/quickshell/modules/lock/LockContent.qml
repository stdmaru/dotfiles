pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Qt5Compat.GraphicalEffects
import Quickshell
import QtQuick
import QtQuick.Controls

// Conteúdo da tela de bloqueio: relógio e data em todos os monitores; no
// principal, também as notificações pendentes e o cartão de login.
Item {
  id: root

  // Mostra o cartão de login e o resumo de notificações.
  property bool showLogin: true
  // Sessão coberta e pronta para receber a senha.
  property bool ready: Session.ready

  readonly property var weekdays: ["domingo", "segunda-feira", "terça-feira", "quarta-feira",
                                   "quinta-feira", "sexta-feira", "sábado"]
  readonly property var months: ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
                                 "agosto", "setembro", "outubro", "novembro", "dezembro"]

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Column {
    id: clockColumn
    anchors.horizontalCenter: parent.horizontalCenter
    y: Math.round(parent.height * 0.09)
    spacing: 2
    opacity: root.ready ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatDateTime(clock.date, "HH:mm")
      color: Theme.white
      font.family: Theme.font_display
      font.pixelSize: 104
      style: Text.Raised
      styleColor: "#55000000"
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: {
        const now = clock.date
        return `${root.weekdays[now.getDay()]}, ${now.getDate()} de ${root.months[now.getMonth()]}`
      }
      color: Theme.text
      font.family: Theme.font_ui
      font.pixelSize: 20
      font.weight: Font.DemiBold
      style: Text.Raised
      styleColor: "#55000000"
    }
  }

  // Cartão de login no centro da tela, com as notificações logo acima.
  Loader {
    anchors.fill: parent
    active: root.showLogin

    sourceComponent: Item {
      LockNotificationStrip {
        id: strip
        width: loginCard.width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: loginCard.top
        anchors.bottomMargin: 18
        visible: root.ready && hasNotifications
        opacity: root.ready ? 1 : 0
      }

      Rectangle {
        id: loginCard

        property real shakeOffset: 0

        enabled: root.ready
        width: 360
        height: cardColumn.implicitHeight + 48
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: shakeOffset
        anchors.verticalCenter: parent.verticalCenter
        radius: Theme.radius_l
        color: "#e611111b"
        border.width: 1
        border.color: Theme.outline
        opacity: root.ready ? 1 : 0
        scale: root.ready ? 1 : 0.96

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

        function submit(): void {
          if (passwordField.text.length === 0)
            return
          Session.authenticate(passwordField.text)
          passwordField.clear()
        }

        // Senha recusada: o cartão balança.
        Connections {
          target: Session
          function onErrorChanged(): void {
            if (Session.error)
              shake.restart()
          }
        }

        SequentialAnimation {
          id: shake
          NumberAnimation { target: loginCard; property: "shakeOffset"; to: -10; duration: 50 }
          NumberAnimation { target: loginCard; property: "shakeOffset"; to: 10; duration: 80 }
          NumberAnimation { target: loginCard; property: "shakeOffset"; to: -6; duration: 70 }
          NumberAnimation { target: loginCard; property: "shakeOffset"; to: 0; duration: 60 }
        }

        Column {
          id: cardColumn
          x: 24
          y: 24
          width: parent.width - 48
          spacing: 12

          Rectangle {
            id: avatar
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76
            height: 76
            radius: 38
            color: Theme.surface0
            border.width: 2
            border.color: Theme.blue

            Image {
              id: avatarImage
              anchors.fill: parent
              anchors.margins: 3
              source: Preferences.user.avatar
                ? (Preferences.user.avatar.startsWith("file://") ? Preferences.user.avatar : `file://${Preferences.user.avatar}`)
                : `file:///var/lib/AccountsService/icons/${Quickshell.env("USER")}`
              sourceSize: Qt.size(160, 160)
              fillMode: Image.PreserveAspectCrop
              visible: status === Image.Ready
              layer.enabled: visible
              layer.effect: OpacityMask {
                maskSource: Rectangle {
                  width: avatarImage.width
                  height: avatarImage.height
                  radius: width / 2
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: avatarImage.status !== Image.Ready
              text: ""
              color: Theme.subtext0
              font.family: Theme.font_awesome
              font.weight: Font.Black
              font.pixelSize: 30
            }
          }

          Text {
            width: parent.width
            text: Preferences.user.displayName || Quickshell.env("USER")
            color: Theme.text
            font.family: Theme.font_display
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
          }

          TextField {
            id: passwordField
            width: parent.width
            height: 44
            placeholderText: "Senha"
            placeholderTextColor: Theme.overlay0
            echoMode: TextInput.Password
            enabled: root.ready && !Session.authenticating
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 15
            leftPadding: 14
            rightPadding: 48
            background: Rectangle {
              radius: Theme.radius_m
              color: Theme.base
              border.width: 1
              border.color: Session.error && !Session.authenticating ? Theme.red
                : passwordField.activeFocus ? Theme.blue : Theme.outline
            }
            onAccepted: loginCard.submit()
            // O campo é desabilitado durante a validação e perde o foco;
            // devolva-o para a próxima tentativa.
            onEnabledChanged: {
              if (enabled)
                Qt.callLater(passwordField.forceActiveFocus)
            }

            Rectangle {
              id: submitButton
              readonly property bool active: passwordField.enabled && passwordField.text.length > 0
              width: 32
              height: 32
              radius: Theme.radius_s
              anchors.right: parent.right
              anchors.rightMargin: 6
              anchors.verticalCenter: parent.verticalCenter
              color: !active ? Theme.surface0 : submitArea.pressed ? Theme.sapphire : Theme.blue

              Text {
                anchors.centerIn: parent
                text: ""
                color: submitButton.active ? Theme.crust : Theme.overlay0
                font.family: Theme.font_awesome
                font.weight: Font.Black
                font.pixelSize: 13
              }

              MouseArea {
                id: submitArea
                anchors.fill: parent
                enabled: submitButton.active
                onClicked: loginCard.submit()
              }
            }
          }

          Text {
            width: parent.width
            height: 16
            text: Session.authenticating ? "Validando…" : Session.error
            color: Session.error && !Session.authenticating ? Theme.red : Theme.subtext0
            font.family: Theme.font_ui
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
