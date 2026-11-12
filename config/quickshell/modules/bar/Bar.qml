import qs.config
import qs.components.common
import qs.controllers
import qs.modules.systemmenu
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
  id: root

  required property PanelWindow parentWindow
  required property TrayMenu trayMenu

  property bool systemTrayCollapsed: false
  property real systemTrayProgress: systemTrayCollapsed ? 0 : 1
  readonly property real barBottom: Config.bar_bottom

  anchors {
    top: parent.top
    left: parent.left
    right: parent.right
  }
  color: "transparent"
  implicitWidth: parent.width
  // Flutuante, a barra tem margem em volta; no modo moldura ela é a faixa
  // superior da moldura, que desenha o fundo (ScreenFrame).
  implicitHeight: Config.frame_enabled ? Config.bar_thickness : Config.topbar_height
  height: implicitHeight

  // Painel encaixado à direita além do menu do sistema (popups de
  // notificação); definido por quem monta a barra.
  property bool rightDocked: false

  // Lançador aberto e preso a esta barra (canto esquerdo).
  readonly property bool launcherDocked: Launcher.progress > 0 && Launcher.attached
    && Launcher.screen === parentWindow.screen

  // Cantos inferiores da barra flutuante: ficam retos enquanto há um painel
  // encaixado embaixo deles, para a lateral do painel continuar a borda da
  // barra.
  DockedCorner {
    id: leftCorner
    docked: root.launcherDocked
    radius: mainRect.radius
  }

  DockedCorner {
    id: rightCorner
    // O menu continua encaixado até terminar de recolher; os popups, até a
    // pilha sumir.
    docked: systemMenu.panelProgress > 0 || root.rightDocked
    radius: mainRect.radius
  }

  Behavior on systemTrayProgress {
    NumberAnimation {
      // Width is clipped during this transition; avoid the spatial curve's
      // overshoot so the tray never stretches past its final size and snaps back.
      duration: 360
      easing.type: Easing.OutCubic
    }
  }

  SystemMenu {
    id: systemMenu
    parentWindow: root.parentWindow
    barBottom: root.barBottom
    toggleButtons: [networkButton, soundButton, powerButton]
  }

  Connections {
    target: Session
    function onLockedChanged(): void {
      if (Session.locked)
        root.trayMenu.close()
    }
  }

  // Relógio da barra; só acorda na virada do minuto.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // Main rect
  Rectangle {
    id: mainRect
    anchors.fill: parent
    anchors.margins: Config.frame_enabled ? 0 : Config.bar_margin
    color: Config.frame_enabled ? "transparent" : Theme.crust
    radius: Config.frame_enabled ? 0 : Config.topbar_corner_radius
    // Cantos inferiores retos enquanto há um painel encaixado embaixo deles
    // (lançador à esquerda; menu do sistema ou popups à direita), para a
    // lateral do painel continuar a borda da barra. Viram 90° assim que o
    // painel começa a abrir e só se arredondam depois que ele fecha.
    bottomLeftRadius: leftCorner.value
    bottomRightRadius: rightCorner.value

    RowLayout {
      anchors.fill: parent
      anchors.margins: Config.bar_padding
      // Na moldura, os controles se alinham à borda do recorte.
      anchors.leftMargin: Config.frame_enabled ? Config.frame_thickness : Config.bar_padding
      anchors.rightMargin: Config.frame_enabled ? Config.frame_thickness : Config.bar_padding

      // LEFT
      Item {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter

          Button {
            height: mainRect.height - 6
            contentItem: Label {
              font.family: Theme.font_nerd
              font.pixelSize: 26
              color: Theme.white
              //text: "\ue795" // terminal
              text: "\udb82\udcc7" // arch-icon
              //text: "\uf40e" // Apps icon
            }
            tooltip: "Aplicativos"
            onClicked: {
              Launcher.toggle()
            }
          }

          // Workspaces
          Workspaces {}

          // Focused window
          Button {
            visible: (Hyprland.focusedWorkspace?.toplevels?.values.length ?? 0) > 0
            iconSource: Utils.getAppIcon(Hyprland.activeToplevel?.wayland?.appId ?? "", "application-x-executable")
            height: mainRect.height - 6
            text: Hyprland.activeToplevel?.title ? (Hyprland.activeToplevel.title.length > 60 ?
                  Hyprland.activeToplevel.title.substring(0, 60) + "…" :
                  Hyprland.activeToplevel.title) : ""
            tooltip: Hyprland.activeToplevel?.title ?? ""
          }
        }
      }

      // CENTER
      Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true

        Row {
          spacing: 3
          anchors.centerIn: parent

          // Weather
          Button {
            id: btn
            height: mainRect.height - 6
            tooltip: (Weather.hasData) ? `${Weather.region}, ${Weather.state} - ${Weather.country}\nSensação Térmica — ${Weather.tempFeelsLike}${Config.temperature_metric}\n▲${Weather.tempMax}${Config.temperature_metric} ▼${Weather.tempMin}${Config.temperature_metric}\n\n${Weather.description}` : ""
            onClicked: Weather.openInBrowser()

            contentItem: Row {
              spacing: 10

              Label {
                font.family: Theme.font_nerd
                font.pixelSize: 28
                color: btn.active ? Theme.white : Theme.barText
                text: (Weather.hasData) ? `${Weather.glyph}` : "\ue347"
              }

              Label {
                font.family: Theme.font_display
                font.pixelSize: btn.fontSize
                color: btn.active ? Theme.white : Theme.barText
                text: (Weather.hasData) ? `${Weather.tempCurrent}${Config.temperature_metric}` : "\uf141"
              }
            }
          }
          
          // Data e hora; abre o painel de notificações
          Button {
            height: mainRect.height - 6
            active: Notifications.trayOpen
            text: {
              const months = ["jan", "fev", "mar", "abr", "mai", "jun",
                              "jul", "ago", "set", "out", "nov", "dez"]
              const now = clock.date
              return `${Qt.formatDateTime(now, "dd")} de ${months[now.getMonth()]} ${Qt.formatDateTime(now, "HH:mm")}`
            }
            onClicked: Notifications.trayOpen = !Notifications.trayOpen
          }
        }
      }

      // RIGHT
      Item {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignRight

        Row {
          // Keep every control in the right group on the same vertical axis.
          // SystemResources derives its height from this row, so an explicit
          // height also prevents the system tray from changing the row's geometry.
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          height: mainRect.height - 6
          spacing: 3
          
          SystemResources{}

          Item {
            id: systemTrayClip
            width: systemTrayContent.implicitWidth * root.systemTrayProgress
            height: mainRect.height - 6
            clip: true

            SystemTray {
              id: systemTrayContent
              parentWindow: root.parentWindow
              trayMenu: root.trayMenu
              width: implicitWidth
              height: implicitHeight
              x: -implicitWidth * (1 - root.systemTrayProgress)
              opacity: root.systemTrayProgress
            }
          }

          // Collapse the application icons in the system tray.
          Button {
            height: mainRect.height - 6
            contentItem: Label {
              font.family: Theme.font_nerd
              font.pixelSize: 18
              color: Theme.white
              text: root.systemTrayCollapsed ? "\uf053" : "\uf054"
            }
            tooltip: root.systemTrayCollapsed ? "Expandir ícones da bandeja" : "Recolher ícones da bandeja"
            onClicked: root.systemTrayCollapsed = !root.systemTrayCollapsed
          }

          // Network button
          Button {
            id: networkButton
            height: mainRect.height - 6
            contentItem: Label {
              font.family: Theme.font_awesome
              font.pixelSize: 16
              color: Theme.white
              text: "\uf6ff"
            }
            tooltip: Network.online ? `Rede (${Network.activeConnection})` : "Rede (desconectado)"
            onClicked: systemMenu.toggle("network")
          }
          
          // Sound button
          Button {
            id: soundButton
            height: mainRect.height - 6
            contentItem: Label {
              font.family: Theme.font_awesome
              font.pixelSize: 16
              color: Theme.white
              text: Audio.muted || Audio.volume <= 0 ? "\uf6a9"
                : Audio.volume < 0.5 ? "\uf027" : "\uf028"
            }
            tooltip: Audio.muted ? "Som (silenciado)" : `Som (${Math.round(Audio.volume * 100)}%)`
            onClicked: systemMenu.toggle("sound")
          }

          // Turn off button
          Button {
            id: powerButton
            height: mainRect.height - 6
            contentItem: Label {
              font.family: Theme.font_awesome
              font.pixelSize: 16
              color: Theme.white
              text: "\uf011"
            }
            tooltip: "Energia e sessão"
            onClicked: systemMenu.toggle("power")
          }
        }
      }
    }
  }
}
