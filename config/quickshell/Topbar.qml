import qs.config
import qs.components.common
import qs.controllers
import qs.components.topbar
import qs.components.topbar.notifications
import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root

  required property PanelWindow parentWindow
  required property TrayMenu trayMenu

  color: "transparent"
  implicitWidth: parent.width
  implicitHeight: 50

  // Main rect
  Rectangle {
    id: mainRect
    anchors.fill: parent
    anchors.margins: 5
    color: "#11111b"
    radius: 7

    RowLayout {
      anchors.fill: parent
      anchors.margins: 3

      // LEFT
      Item {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft

        Row {
          spacing: 3
          anchors.verticalCenter: parent.verticalCenter

          // Applications Button
          Button {
            fontSize: 28
            leftPadding: 8
            rightPadding: 8
            height: mainRect.height - 6
            text: "󰣇"
            tooltip: "Aplicativos"
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
              spacing: 5

              Label {
                font.family: "Font Awesome 7 Free"
                font.pixelSize: 16
                color: btn.active ? "#ffffff" : "#b1b1b5"
                text: (Weather.hasData) ? `${Weather.glyph}` : ""
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
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          
          SystemResources{}

          SystemTray { parentWindow: root.parentWindow; trayMenu: root.trayMenu }

          // System tray button
          Button {
            height: mainRect.height - 6
            contentItem: Label {
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            onClicked: {
              Quickshell.execDetached(["notify-send", "Não implementado."])
            }
          }

          // Network button
          Button {
            height: mainRect.height - 6
            contentItem: Label {
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            onClicked: {
              Quickshell.execDetached(["notify-send", "Não implementado."])
            }
          }
          
          // Sound button
          Button {
            height: mainRect.height - 6
            contentItem: Label {
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            onClicked: {
              Quickshell.execDetached(["notify-send", "Não implementado."])
            }
          }

          // Turn off button
          Button {
            height: mainRect.height - 6
            contentItem: Label {
              font.family: "Font Awesome 7 Free"
              font.pixelSize: 16
              color: "#ffffff"
              text: ""
            }
            onClicked: {
              Quickshell.execDetached(["notify-send", "Não implementado."])
            }
          }
        }
      }
    }
  }
}