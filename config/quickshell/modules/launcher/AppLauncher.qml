import qs.config
import qs.controllers
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
PanelWindow {
  id: root
  required property ShellScreen targetScreen
  property int selectedIndex: 0
  property real openProgress: Launcher.open && isTargetScreen ? 1 : 0
  property bool isTargetScreen: Launcher.screen === targetScreen
  screen: targetScreen
  visible: (Launcher.open || openProgress > 0) && isTargetScreen
  color: "transparent"
  focusable: Launcher.open && isTargetScreen
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  Behavior on openProgress {
    NumberAnimation {
      duration: 120
      easing.type: Easing.OutCubic
    }
  }
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  Item {
    id: content
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: Launcher.close()
    Rectangle {
      anchors.fill: parent
      color: "#72090a12"
      opacity: 1
      MouseArea {
        anchors.fill: parent
        onClicked: Launcher.close()
      }
    }
    Rectangle {
      id: launcherCard
      width: Math.min(455, parent.width - 10)
      x: 5 - (width + 20) * (1 - root.openProgress)
      anchors.top: parent.top
      //anchors.topMargin: (Config.frame_enabled ? (Config.topbar_height - 10 + Config.frame_thickness) : Config.topbar_height) + Config.app_launcher_top_gap
      anchors.margins: 5
      anchors.bottom: parent.bottom
      //anchors.bottomMargin: 5
      opacity: 1
      radius: Config.topbar_corner_radius
      color: "#191923"
      border.width: 1
      border.color: "#343443"
      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        Row {
          width: parent.width
          spacing: 10
          Rectangle {
            width: 36
            height: 36
            radius: 12
            color: "#29293a"
            Grid {
              anchors.centerIn: parent
              width: 17
              height: 17
              columns: 2
              spacing: 3
              Repeater {
                model: 4
                Rectangle {
                  required property int index
                  width: 7
                  height: 7
                  radius: 2
                  color: Theme.blue
                }
              }
            }
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
              text: "Aplicativos"
              color: "#e6e6f0"
              font.family: Theme.font_display
              font.pixelSize: 15
            }
            Text {
              text: "> comando  ·  digite para pesquisar"
              color: "#88889b"
              font.pixelSize: 10
            }
          }
        }
        TextField {
          id: searchField
          width: parent.width
          height: 43
          placeholderText: "Pesquisar aplicativos ou digitar > comando"
          selectByMouse: true
          color: "#eeeeF6"
          placeholderTextColor: "#858597"
          font.pixelSize: 13
          leftPadding: 12
          rightPadding: 12
          background: Rectangle {
            radius: 13
            color: Theme.crust
            border.width: searchField.activeFocus ? 1 : 0
            border.color: Theme.blue
          }
          onAccepted: root.submitSearch()
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
              root.moveSelection(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up) {
              root.moveSelection(-1)
              event.accepted = true
            }
          }
        }
        Item {
          width: parent.width
          height: parent.height - y
          Text {
            anchors.centerIn: parent
            visible: searchField.text.trim().length > 0
              && !searchField.text.trim().startsWith(">")
              && root.visibleApps.length === 0
            text: "Nenhum aplicativo encontrado"
            color: "#9292a5"
            font.pixelSize: 13
          }
          Text {
            anchors.centerIn: parent
            visible: searchField.text.trim().startsWith(">")
            text: searchField.text.trim().length > 1
              ? "Pressione Enter para executar no terminal"
              : "Digite um comando para executar no terminal"
            color: "#9292a5"
            font.pixelSize: 13
          }
          ListView {
            id: appList
            anchors.fill: parent
            clip: true
            spacing: 5
            model: root.visibleApps
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
            }
            delegate: Item {
              id: appRow
              required property int index
              required property string key
              required property string name
              required property string subtitle
              required property string icon
              required property bool running
              required property int workspace
              width: appList.width
              height: 46
              Rectangle {
                id: rowSurface
                anchors.fill: parent
                radius: 13
                color: (root.selectedIndex >= 0 && root.selectedIndex === appRow.index)
                  || mouse.containsMouse ? "#2b2b3c" : "transparent"
                Row {
                  anchors.fill: parent
                  anchors.leftMargin: 10
                  anchors.rightMargin: 10
                  spacing: 10
                  Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    source: appRow.icon
                    sourceSize: Qt.size(68, 68)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                  }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 135
                    spacing: 2
                    Text {
                      width: parent.width
                      text: appRow.name
                      color: "#e6e6f0"
                      font.pixelSize: 13
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: appRow.subtitle
                      color: "#9292a5"
                      font.pixelSize: 10
                      elide: Text.ElideRight
                      visible: text.length > 0
                    }
                  }
                  Rectangle {
                    visible: appRow.running
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(28, workspaceLabel.implicitWidth + 13)
                    height: 21
                    radius: 8
                    color: "#343449"
                    Text {
                      id: workspaceLabel
                      anchors.centerIn: parent
                      text: appRow.workspace > 0
                        ? `WORKSPACE ${appRow.workspace}` : "Ativo"
                      color: Theme.lavender
                      font.pixelSize: 9
                      font.weight: Font.DemiBold
                    }
                  }
                }
                MouseArea {
                  id: mouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onEntered: root.selectItem(appRow.index)
                  onClicked: root.activateKey(appRow.key)
                }
              }
            }
          }
        }
      }
    }
  }
  Connections {
    target: Launcher

    function onOpenChanged(): void {
      if (Launcher.open && root.isTargetScreen) {
        searchField.text = ""
        root.selectedIndex = 0

        Qt.callLater(() => {
          appList.positionViewAtBeginning()
          searchField.forceActiveFocus()
        })
      } else {
        Qt.callLater(() => appList.positionViewAtBeginning())
      }
    }
  }
  property var visibleApps: {
    const query = searchField.text.trim().toLocaleLowerCase()
    if (query.startsWith(">")) return []
    const entries = DesktopEntries.applications.values
    const windows = Hyprland.toplevels.values
    const running = []
    const runningKeys = new Set()
    const runningIds = new Set()
    for (const window of windows) {
      const appId = window.wayland?.appId ?? ""
      if (!appId) continue
      const workspaceId = window.workspace?.id ?? 0
      const key = `${appId.toLowerCase()}@${workspaceId}`
      if (runningKeys.has(key)) continue
      runningKeys.add(key)
      const entry = DesktopEntries.heuristicLookup(appId)
      const normalizedId = appId.toLowerCase().replace(/\.desktop$/, "")
      runningIds.add(normalizedId)
      if (entry?.id)
        runningIds.add(entry.id.toLowerCase().replace(/\.desktop$/, ""))
      running.push({
        key: `running:${key}`,
        name: entry?.name ?? window.title ?? appId,
        subtitle: entry?.genericName ?? window.title ?? "Em execução",
        icon: Utils.getAppIcon(appId, "application-x-executable"),
        running: true,
        workspace: workspaceId,
        entry,
        toplevel: window
      })
    }
    running.sort((a, b) => a.name.localeCompare(b.name))
    const installed = entries
      .filter(entry => !entry.noDisplay)
      .filter(entry => !runningIds.has(entry.id.toLowerCase().replace(/\.desktop$/, "")))
      .map(entry => ({
        key: `installed:${entry.id}`,
        name: entry.name,
        subtitle: entry.genericName || entry.comment || "",
        icon: Quickshell.iconPath(entry.icon, "application-x-executable"),
        running: false,
        workspace: 0,
        entry,
        toplevel: null
      }))
      .sort((a, b) => a.name.localeCompare(b.name))
    const allApps = running.concat(installed)
    if (!query) return allApps
    return allApps.filter(app =>
      `${app.name} ${app.subtitle} ${app.entry?.id ?? ""} ${(app.entry?.keywords ?? []).join(" ")}`
        .toLocaleLowerCase()
        .includes(query)
    )
  }
  onVisibleAppsChanged: {
      selectedIndex = visibleApps.length > 0 ? 0 : -1
      Qt.callLater(() => appList.positionViewAtBeginning())
  }
  function selectItem(index: int): void {
    if (index < 0 || index >= visibleApps.length)
      return
    selectedIndex = index
    appList.currentIndex = index
  }
  function moveSelection(direction: int): void {
    if (visibleApps.length === 0)
      return
    const next = selectedIndex < 0
      ? (direction > 0 ? 0 : visibleApps.length - 1)
      : (selectedIndex + direction + visibleApps.length) % visibleApps.length
    selectedIndex = next
    appList.currentIndex = next
    appList.positionViewAtIndex(next, ListView.Contain)
  }
  function activateApp(app: var): void {
    Launcher.close()
    if (app.running && app.toplevel) {
      if (app.toplevel.workspace) app.toplevel.workspace.activate()
      Qt.callLater(() => app.toplevel.wayland?.activate())
      return
    }
    app.entry?.execute()
  }
  function activateKey(key: string): void {
    const app = visibleApps.find(candidate => candidate.key === key)
    if (app)
      activateApp(app)
  }
  function submitSearch(): void {
    const query = searchField.text.trim()
    if (query.startsWith(">")) {
      const command = query.slice(1).trim()
      if (!command) return
      Launcher.close()
      Quickshell.execDetached([
          Config.terminal,
          "-e",
          "sh",
          "-lc",
          `${command};`
      ])
      return
    }
    if (visibleApps.length > 0) {
      const selectedApp = selectedIndex >= 0 && selectedIndex < visibleApps.length
        ? visibleApps[selectedIndex]
        : visibleApps[0]
      activateApp(selectedApp)
    }
  }
}
