import qs.config
import qs.components.common
import qs.controllers
import qs.components.topbar
import qs.components.topbar.notifications
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes

Rectangle {
  id: root

  required property PanelWindow parentWindow
  required property TrayMenu trayMenu
  required property var launcherController

  property bool systemTrayCollapsed: false
  property real systemTrayProgress: systemTrayCollapsed ? 0 : 1
  readonly property real barBottom: mainRect.y + mainRect.height + (Config.frame_enabled ? Config.frame_thickness : 0)

  anchors {
    top: parent.top
    left: parent.left
    right: parent.right
  }
  color: "transparent"
  implicitWidth: parent.width
  implicitHeight: Config.frame_enabled ? (Config.topbar_height - 10) : Config.topbar_height
  height: implicitHeight

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
    sessionController: root.launcherController
  }

  Connections {
    target: root.launcherController
    function onLockedChanged(): void {
      if (!root.launcherController.locked)
        return
      systemMenu.closeMenu()
      root.trayMenu.isOpen = false
    }
  }

  // Main rect
  Rectangle {
    id: mainRect
    anchors.fill: parent
    anchors.margins: Config.frame_enabled ? 0 : 5
    color: "#11111b"
    radius: Config.frame_enabled ? 0 : Config.topbar_corner_radius

    RowLayout {
      anchors.fill: parent
      anchors.margins: 3
      anchors.leftMargin: Config.frame_enabled ? (Config.frame_thickness + 3) : 3
      anchors.rightMargin: Config.frame_enabled ? (Config.frame_thickness + 3) : 3

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
              font.family: "JetBrainsMono Nerd Font Mono"
              font.pixelSize: 32
              color: "#ffffff"
              //text: "\ue795" // terminal
              text: "\udb82\udcc7" // arch-icon
              //text: "\uf40e" // Apps icon
            }
            tooltip: "Aplicativos"
            onClicked: {
              root.launcherController.toggleLauncher()
            }
          }

          // Workspaces
          Workspaces {}

          // Focused window
          Button {
            visible: Hyprland.focusedWorkspace?.toplevels?.values.length > 0 ? true : false
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
            onClicked: function() {
              Quickshell.execDetached(["xdg-open", `https://www.google.com/search?q=weather ${Weather.region} ${Weather.state} ${Weather.country}`])
            }

            contentItem: Row {
              spacing: 10

              Label {
                font.family: "JetBrainsMono Nerd Font Mono"
                font.pixelSize: 30
                color: btn.active ? "#ffffff" : "#b1b1b5"
                text: (Weather.hasData) ? `${Weather.glyph}` : "\ue347"
              }

              Label {
                font.family: Config.main_font
                font.pixelSize: btn.fontSize
                color: btn.active ? "#ffffff" : "#b1b1b5"
                text: (Weather.hasData) ? `${Weather.tempCurrent}${Config.temperature_metric}` : ""
              }
            }
          }
          
          // Date
          Button {
              height: mainRect.height - 6

              property var now: new Date()

              text: {
                  const day = Qt.formatDateTime(now, "dd")
                  const time = Qt.formatDateTime(now, "HH:mm")

                  const months = [
                      "jan", "fev", "mar", "abr", "mai", "jun",
                      "jul", "ago", "set", "out", "nov", "dez"
                  ]

                  const month = months[now.getMonth()]

                  return `${day} de ${month} ${time}`
              }

              onClicked: function() {
                Notifications.trayOpen = !Notifications.trayOpen
              }

              // Atualiza a cada minuto
              Timer {
                  interval: 1_000
                  running: true
                  repeat: true
                  onTriggered: parent.now = new Date()
              }
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
              font.family: "JetBrainsMono Nerd Font Mono"
              font.pixelSize: 24
              color: "#ffffff"
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
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            tooltip: "Rede"
            onPressedChanged: systemMenu.noteToggleButtonPress(pressed)
            onClicked: systemMenu.toggle("network")
          }
          
          // Sound button
          Button {
            id: soundButton
            height: mainRect.height - 6
            contentItem: Label {
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            tooltip: "Som"
            onPressedChanged: systemMenu.noteToggleButtonPress(pressed)
            onClicked: systemMenu.toggle("sound")
          }

          // Turn off button
          Button {
            id: powerButton
            height: mainRect.height - 6
            contentItem: Label {
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            tooltip: "Energia e sessão"
            onPressedChanged: systemMenu.noteToggleButtonPress(pressed)
            onClicked: systemMenu.toggle("power")
          }
        }
      }
    }
  }

}
