//@ pragma IconTheme AdwaitaLegacy

pragma ComponentBehavior: Bound

import qs.controllers
import qs.components.topbar.notifications
import qs.components.topbar
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
  Scope {
    id: scope

    Variants {
      model: Quickshell.screens

      // Main screen
      delegate: PanelWindow {
        required property ShellScreen modelData
        id: shellWindow

        screen: modelData
        visible: true
        color: "transparent"
        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }
        
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        //WlrLayershell.layer: WlrLayer.Overlay

        mask: Region {
          x: 0
          y: 0
          width: shellWindow.width
          height: shellWindow.height
          intersection: Intersection.Xor
          regions: regions.instances
        }

        // Topbar exclusive zone
        ExclusionZone {
          anchors { top: true }
          exclusiveZone: topbar.implicitHeight
        }

        // List of clickable regions
        Variants {
          id: regions
          model: widgets.children

          Region {
            required property Item modelData

            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: (modelData.visible) ? modelData.height : 0
            intersection: Intersection.Subtract
          }
        }

        // List of widgets
        Item {
          id: widgets
          anchors.fill: parent
          
          Topbar { id: topbar; parentWindow: shellWindow; trayMenu: trayMenu}
          NotificationPopups { id: notificationDrawer; attachedTo: topbar }
          NotificationTray { id: notificationTray; attachedBar: topbar }
          TrayMenu { id: trayMenu; parentWindow: shellWindow; }
        }
      }

      component ExclusionZone: PanelWindow {
        screen: this.screen
        exclusiveZone: 0
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
        WlrLayershell.namespace: `shell-exclusive-area`
      }
    }
  }

  Component.onCompleted: () => {
    Hypr.init()
    Weather.init()
    Notifications.init()
  }
}