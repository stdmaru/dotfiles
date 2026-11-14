pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import qs.components.common
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
  // Só anima depois que a janela aparece, senão a abertura começa invisível.
  property real openProgress: Launcher.open && isTargetScreen && backingWindowVisible ? 1 : 0
  onBackingWindowVisibleChanged: {
    if (backingWindowVisible) {
      TooltipManager.dismiss()
      listDelay.restart()
    } else {
      listDelay.stop()
      listReady = false
    }
  }
  // A lista só é montada depois que a janela já apareceu, para o clique
  // abrir o lançador na hora; ela surge em seguida com um fade.
  property bool listReady: false
  Timer {
    id: listDelay
    interval: 16
    onTriggered: root.listReady = true
  }
  onOpenProgressChanged: {
    if (isTargetScreen)
      Launcher.progress = openProgress
  }
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
      color: root.attached ? "transparent" : Theme.scrim
      opacity: root.openProgress
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Launcher.close()
      }
    }

    // Preso à barra, o lançador ocupa o canto superior esquerdo: a lateral
    // esquerda se funde à moldura (ou continua reta a borda da barra, cujo
    // canto se endireita) e a direita desce da barra numa rampa.
    ShadowLayer {
      anchors.fill: parent
      visible: root.attached
      clipToWorkArea: true

      DockSilhouette {
        leftEdge: Config.frame_enabled ? "border" : "flush"
        rightEdge: "ramp"
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height
      }
    }

    Rectangle {
      id: panel

      readonly property real targetHeight: Math.min(705, content.height - y - 24)

      width: Math.min(460, content.width - 24)
      x: root.attached
        ? (Config.frame_enabled ? Config.frame_thickness : Config.bar_margin)
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
          onAccepted: root.submitSearch(false)
          Keys.onPressed: event => {
            // Ctrl+Enter: nova instância do item selecionado, mesmo aberto.
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                && (event.modifiers & Qt.ControlModifier)) {
              root.submitSearch(true)
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
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

          // Enquanto a lista é montada, logo após a janela aparecer.
          Text {
            anchors.centerIn: parent
            visible: !root.listReady && !root.commandMode
            text: "Carregando…"
            color: Theme.overlay1
            font.family: Theme.font_ui
            font.pixelSize: 13
          }

          ListView {
            id: appList
            anchors.fill: parent
            clip: true
            spacing: 2
            model: root.visibleApps
            currentIndex: root.selectedIndex
            opacity: root.listReady ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
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
              required property bool newInstance
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

                // Em execução: mostra o workspace; nova instância: selo "+ nova".
                Rectangle {
                  id: badge
                  visible: appRow.running //|| appRow.newInstance
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
                      visible: appRow.running
                      width: 6
                      height: 6
                      radius: 3
                      color: Theme.green
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      visible: appRow.newInstance
                      text: "\uf067"
                      color: Theme.blue
                      font.family: Theme.font_awesome
                      font.weight: Font.Black
                      font.pixelSize: 9
                    }

                    Text {
                      text: appRow.newInstance ? "nova"
                        : appRow.workspace > 0
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
          text: "↑↓ navegar  ·  Enter abrir  ·  Ctrl+Enter nova janela  ·  > comando  ·  Esc fechar"
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
  // Lista do lançador: primeiro as janelas abertas no monitor do lançador,
  // depois os aplicativos instalados (os abertos em algum lugar primeiro).
  // Aplicativos instalados, já com o ícone resolvido. Só muda quando a
  // lista de .desktop muda, então reabrir o lançador não refaz o trabalho.
  readonly property var installedApps: DesktopEntries.applications.values
    .filter(entry => !entry.noDisplay)
    .map(entry => ({
      key: `installed:${entry.id}`,
      name: entry.name,
      subtitle: entry.genericName || entry.comment || "",
      icon: Quickshell.iconPath(entry.icon, "application-x-executable"),
      running: false,
      newInstance: false,
      workspace: 0,
      entry,
      toplevel: null
    }))

  property var visibleApps: {
    if (!root.listReady) return []
    const query = searchField.text.trim().toLocaleLowerCase()
    if (query.startsWith(">")) return []
    const normalize = id => (id ?? "").toLowerCase().replace(/\.desktop$/, "")
    const screenName = root.targetScreen?.name ?? ""
    const windows = Hyprland.toplevels.values.filter(window =>
      (window.monitor?.name ?? window.workspace?.monitor?.name ?? "") === screenName)

    // Agrupa as janelas por aplicativo, uma linha por workspace.
    const groups = new Map()
    for (const window of windows) {
      const appId = window.wayland?.appId ?? ""
      if (!appId) continue
      const entry = DesktopEntries.heuristicLookup(appId)
      const groupId = entry?.id ? normalize(entry.id) : normalize(appId)
      if (!groups.has(groupId))
        groups.set(groupId, { entry, appId, rows: new Map() })
      const workspaceId = window.workspace?.id ?? 0
      const rows = groups.get(groupId).rows
      if (rows.has(workspaceId)) continue
      rows.set(workspaceId, {
        key: `running:${groupId}@${workspaceId}`,
        name: window.title || entry?.name || appId,
        subtitle: entry?.name || entry?.genericName || "Em execução",
        icon: Utils.getAppIcon(appId, "application-x-executable"),
        running: true,
        newInstance: false,
        workspace: workspaceId,
        entry,
        toplevel: window
      })
    }

    const running = []
    const runningEntryIds = new Set()
    const sortedGroups = Array.from(groups.values()).sort((a, b) =>
      (a.entry?.name ?? a.appId).localeCompare(b.entry?.name ?? b.appId))
    for (const group of sortedGroups) {
      running.push(...Array.from(group.rows.values()).sort((a, b) => a.workspace - b.workspace))
      if (group.entry)
        runningEntryIds.add(normalize(group.entry.id))
    }

    // Abertos em outros monitores vêm logo depois, antes dos demais.
    const openElsewhere = new Set(Hyprland.toplevels.values
      .map(window => DesktopEntries.heuristicLookup(window.wayland?.appId ?? "")?.id)
      .filter(id => id)
      .map(normalize))
    const installed = root.installedApps
      .map(app => {
        // Já aberto neste monitor: abrir daqui cria outra janela.
        if (!runningEntryIds.has(normalize(app.entry.id)))
          return app
        return Object.assign({}, app, { newInstance: true })
      })
      .sort((a, b) => {
        const openA = openElsewhere.has(normalize(a.entry.id)) ? 0 : 1
        const openB = openElsewhere.has(normalize(b.entry.id)) ? 0 : 1
        return openA - openB || a.name.localeCompare(b.name)
      })
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
  function activateApp(app: var, forceNew: bool): void {
    Launcher.close()
    if (forceNew && app.entry) {
      launchNewInstance(app.entry)
      return
    }
    if (app.running && app.toplevel) {
      if (app.toplevel.workspace) app.toplevel.workspace.activate()
      Qt.callLater(() => app.toplevel.wayland?.activate())
      return
    }
    if (app.newInstance && app.entry) {
      launchNewInstance(app.entry)
      return
    }
    app.entry?.execute()
  }
  // Prefere a ação "nova janela" do .desktop (Firefox, VS Code...): só
  // executar o aplicativo costuma apenas focar a janela já aberta.
  function launchNewInstance(entry: var): void {
    const action = (entry.actions ?? []).find(candidate =>
      /new.*window|new.*instance/i.test(candidate.id) && !/private|incognito/i.test(candidate.id))
    if (action)
      action.execute()
    else
      entry.execute()
  }
  function activateKey(key: string): void {
    const app = visibleApps.find(candidate => candidate.key === key)
    if (app)
      activateApp(app, false)
  }
  function submitSearch(forceNew: bool): void {
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
      activateApp(selectedApp, forceNew === true)
    }
  }
}
