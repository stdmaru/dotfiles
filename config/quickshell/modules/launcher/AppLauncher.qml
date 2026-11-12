pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import qs.modules.notifications
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

// Lançador de aplicativos. No monitor principal ele brota da barra, como o
// painel de notificações; nos demais, ou sobre um aplicativo em tela cheia,
// aparece como um cartão flutuante.
PanelWindow {
  id: root

  required property ShellScreen targetScreen
  readonly property bool isTargetScreen: Launcher.screen === targetScreen
  // Preso à barra, ou flutuante onde não há barra à vista (outros monitores
  // ou aplicativo em tela cheia).
  readonly property bool attached: Launcher.attached
  property int selectedIndex: 0
  property real openProgress: Launcher.open && isTargetScreen ? 1 : 0
  readonly property string query: searchField.text.trim()
  readonly property bool commandMode: query.startsWith(">")

  screen: targetScreen
  visible: (Launcher.open || openProgress > 0) && isTargetScreen
  color: "transparent"
  focusable: Launcher.open && isTargetScreen
  aboveWindows: true
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell-launcher"
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  Behavior on openProgress {
    NumberAnimation {
      duration: Config.motion_fast_spatial_ms
      easing.type: Easing.OutCubic
    }
  }

  Item {
    id: content
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: Launcher.close()

    // Clique fora fecha. Só o cartão flutuante escurece o fundo; preso à
    // barra, o lançador se comporta como os demais painéis.
    Rectangle {
      anchors.fill: parent
      color: root.attached ? "transparent" : "#72090a12"
      opacity: root.openProgress
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Launcher.close()
      }
    }

    DockSilhouette {
      visible: root.attached && height > 0.5
      x: panel.x
      y: panel.y
      width: panel.width
      height: panel.height
    }

    Rectangle {
      id: panel

      readonly property real targetHeight: Math.min(620, content.height - y - 24)

      width: Math.min(460, content.width - 24)
      // Preso à barra, fica no canto esquerdo com folga para a rampa da
      // silhueta não encostar no canto da barra (ou do recorte da moldura).
      x: root.attached
        ? (Config.frame_enabled
            ? Config.frame_thickness + Config.frame_corner_radius
            : Config.topbar_corner_radius)
          + Config.notification_panel_emergence + 5
        : (content.width - width) / 2
      y: root.attached ? Config.bar_bottom : Math.round(content.height * 0.14)
      height: root.attached ? targetHeight * root.openProgress : targetHeight
      opacity: root.attached ? 1 : root.openProgress
      scale: root.attached ? 1 : 0.97 + 0.03 * root.openProgress
      // Preso à barra, o fundo é a silhueta desenhada atrás.
      color: root.attached ? "transparent" : Theme.crust
      radius: Theme.radius_l
      border.width: root.attached ? 0 : 1
      border.color: Theme.outline
      clip: true

      // Cliques no painel não chegam ao fechamento por clique externo.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      // O conteúdo mantém o tamanho final enquanto o painel cresce.
      Column {
        x: 14
        y: 14
        width: panel.width - 28
        height: panel.targetHeight - 28
        spacing: 10
        opacity: root.openProgress

        TextField {
          id: searchField
          width: parent.width
          height: 44
          placeholderText: "Pesquisar aplicativos…"
          selectByMouse: true
          color: Theme.text
          placeholderTextColor: Theme.overlay0
          font.family: Theme.font_ui
          font.pixelSize: 14
          leftPadding: 40
          rightPadding: 12
          background: Rectangle {
            radius: Theme.radius_m
            color: Theme.base
            border.width: 1
            border.color: searchField.activeFocus ? Theme.blue : Theme.outline

            Text {
              x: 14
              anchors.verticalCenter: parent.verticalCenter
              text: root.commandMode ? "\uf120" : "\uf002"
              color: root.commandMode ? Theme.green : Theme.overlay1
              font.family: Theme.font_awesome
              font.weight: Font.Black
              font.pixelSize: 14
            }
          }
          onAccepted: root.submitSearch()
          Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
              root.moveSelection(1)
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
              root.moveSelection(-1)
              event.accepted = true
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - searchField.height - footer.height - parent.spacing * 2

          Column {
            anchors.centerIn: parent
            spacing: 10
            visible: root.commandMode || (root.query.length > 0 && root.visibleApps.length === 0)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.commandMode ? "\uf120" : "\uf002"
              color: Theme.surface2
              font.family: Theme.font_awesome
              font.weight: Font.Black
              font.pixelSize: 26
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: !root.commandMode ? "Nenhum aplicativo encontrado"
                : root.query.length > 1 ? "Enter executa o comando no terminal"
                : "Digite um comando para executar no terminal"
              color: Theme.subtext0
              font.family: Theme.font_ui
              font.pixelSize: 13
            }
          }

          ListView {
            id: appList
            anchors.fill: parent
            clip: true
            spacing: 2
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
              height: 48

              Rectangle {
                anchors.fill: parent
                radius: Theme.radius_s
                color: root.selectedIndex === appRow.index ? Theme.surface0
                  : mouse.containsMouse ? Theme.baseHover : "transparent"
              }

              Row {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 12

                Image {
                  anchors.verticalCenter: parent.verticalCenter
                  width: 32
                  height: 32
                  source: appRow.icon
                  sourceSize: Qt.size(64, 64)
                  fillMode: Image.PreserveAspectFit
                  smooth: true
                  mipmap: true
                  asynchronous: true
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 32 - parent.spacing
                    - (badge.visible ? badge.width + parent.spacing : 0)
                  spacing: 1

                  Text {
                    width: parent.width
                    text: appRow.name
                    color: Theme.text
                    font.family: Theme.font_ui
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: appRow.subtitle
                    color: Theme.overlay1
                    font.family: Theme.font_ui
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    visible: text.length > 0
                  }
                }

                // Aplicativo em execução: mostra em qual workspace está.
                Rectangle {
                  id: badge
                  visible: appRow.running
                  anchors.verticalCenter: parent.verticalCenter
                  width: badgeRow.implicitWidth + 14
                  height: 22
                  radius: height / 2
                  color: Theme.surface1

                  Row {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: 6
                      height: 6
                      radius: 3
                      color: Theme.green
                    }

                    Text {
                      text: appRow.workspace > 0
                        ? (Config.workspaces_labels[appRow.workspace] ?? String(appRow.workspace))
                        : "ativo"
                      color: Theme.text
                      font.family: Theme.font_ui
                      font.pixelSize: 11
                      font.weight: Font.DemiBold
                    }
                  }
                }
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.activateKey(appRow.key)
              }
            }
          }
        }

        Text {
          id: footer
          width: parent.width
          height: 16
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: "↑↓ navegar  ·  Enter abrir  ·  > executar comando  ·  Esc fechar"
          color: Theme.overlay0
          font.family: Theme.font_ui
          font.pixelSize: 10
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
