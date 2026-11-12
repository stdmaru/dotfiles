//@ pragma IconTheme AdwaitaLegacy

pragma ComponentBehavior: Bound

import qs.controllers
import qs.config
import qs.components.common
import qs.components.topbar.notifications
import qs.components.topbar
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

ShellRoot {
  Scope {
    id: scope

    property bool launcherOpen: false
    property bool locked: false
    property bool lockReady: false
    property bool lockWorkspacesApplied: false
    property bool blurOverlayVisible: false
    property bool lockSurfaceSecure: false
    property int lockWorkspaceAttempts: 0
    property bool liveWallpaperVisible: false
    property var lockWorkspaceTargets: []
    property string lockError: ""
    property string pendingPassword: ""
    property var savedWorkspaces: []
    property string previouslyFocusedMonitor: ""
    property int restoreWorkspaceAttempts: 0
    readonly property var lockNotificationGroups: lockNotificationGroupModel

    ListModel {
      id: lockNotificationGroupModel
    }

    function rebuildLockNotificationGroups(): void {
      const groups = new Map()
      const fullPrivacy = Notifications.lockScreenFullPrivacy

      for (let i = 0; i < Notifications.all.count; ++i) {
        const notification = Notifications.all.get(i).modelData
        const desktopEntry = String(notification.desktopEntry || "").trim()
        const entry = desktopEntry ? DesktopEntries.heuristicLookup(desktopEntry) : null
        const appName = String(notification.appName || entry?.name || desktopEntry || "Aplicativo").trim()
        const appKey = String(desktopEntry || entry?.id || appName).toLocaleLowerCase()
        const sourceKey = Notifications.messageGroupKey(notification)
        const key = fullPrivacy
          ? `app|${appKey}`
          : (sourceKey || `notification|${notification.id}|${notification.createdAt}`)
        const group = groups.get(key) ?? {
          key,
          appName,
          icon: Utils.getAppIcon(desktopEntry || appName, "application-x-executable"),
          avatar: notification.image || "",
          count: 0,
          newestAt: Number(notification.createdAt || 0)
        }
        group.count += 1
        group.newestAt = Math.max(group.newestAt, Number(notification.createdAt || 0))
        if (!group.avatar && notification.image)
          group.avatar = notification.image
        groups.set(key, group)
      }

      const sortedGroups = Array.from(groups.values())
        .sort((left, right) => right.newestAt - left.newestAt)
      const nextKeys = sortedGroups.map(group => group.key)

      for (let i = lockNotificationGroupModel.count - 1; i >= 0; --i) {
        if (!nextKeys.includes(lockNotificationGroupModel.get(i).key))
          lockNotificationGroupModel.remove(i)
      }

      for (let target = 0; target < sortedGroups.length; ++target) {
        const group = sortedGroups[target]
        let current = -1
        for (let i = target; i < lockNotificationGroupModel.count; ++i) {
          if (lockNotificationGroupModel.get(i).key === group.key) {
            current = i
            break
          }
        }

        if (current < 0) {
          lockNotificationGroupModel.insert(target, group)
        } else {
          if (current !== target)
            lockNotificationGroupModel.move(current, target, 1)
          lockNotificationGroupModel.set(target, group)
        }
      }
    }

    Connections {
      target: Notifications.all
      function onCountChanged(): void { scope.rebuildLockNotificationGroups() }
    }

    Connections {
      target: Notifications
      function onLockScreenFullPrivacyChanged(): void { scope.rebuildLockNotificationGroups() }
      function onImagePersistenceVersionChanged(): void { scope.rebuildLockNotificationGroups() }
    }

    Component.onCompleted: rebuildLockNotificationGroups()

    property ShellScreen launcherScreen: null

    function toggleLauncher(): void {
        if (launcherOpen) {
            closeLauncher()
            return
        }

        const monitor = Hyprland.focusedMonitor
        if (!monitor)
            return

        launcherScreen = Quickshell.screens.find(
            screen => screen.name === monitor.name
        ) ?? null

        if (launcherScreen)
            launcherOpen = true
    }

    function closeLauncher(): void {
      launcherOpen = false
    }

    function focusMonitor(name: string): void {
      const request = Hyprland.usingLua
        ? `hl.dsp.focus({ monitor = "${name}" })`
        : `focusmonitor ${name}`
      Hyprland.dispatch(request)
    }

    function focusWorkspace(id: int): void {
      const request = Hyprland.usingLua
        ? `hl.dsp.focus({ workspace = ${id} })`
        : `workspace ${id}`
      Hyprland.dispatch(request)
    }

    function lockSession(): void {
      if (locked)
        return

      Hyprland.refreshMonitors()
      const monitors = Hyprland.monitors.values.filter(monitor => ["DP-1", "DP-2"].includes(monitor.name))
      savedWorkspaces = monitors.map(monitor => ({
        monitor: monitor.name,
        workspace: Notifications.emptyWorkspaceOnLock && monitor.name === "DP-1"
          ? 10 : (monitor.activeWorkspace?.id ?? 1)
      }))
      previouslyFocusedMonitor = monitors.find(monitor => monitor.focused)?.name ?? "DP-2"
      lockWorkspacesApplied = false
      lockReady = false
      liveWallpaperVisible = false
      blurOverlayVisible = true
      lockSurfaceSecure = false
      lockWorkspaceTargets = []
      lockError = ""
      launcherOpen = false
      Notifications.trayOpen = false
      Notifications.popupSuppressed = true
      locked = true
    }

    function moveToLockWorkspaces(): void {
      if (!locked || !sessionLock.secure || lockWorkspacesApplied)
        return

      if (!Notifications.emptyWorkspaceOnLock) {
        // Keep the current workspaces, but leave the full-screen blur in place
        // for the entire locked session to hide their contents.
        lockWorkspaceTargets = savedWorkspaces.map(entry => entry.monitor)
        lockWorkspaceReveal.start()
        return
      }

      lockWorkspaceAttempts = 0
      lockWorkspacePoll.start()
    }

    function applyLockWorkspaces(): void {
      if (!locked || !sessionLock.secure)
        return

      // Keep every connected display on its own empty, persistent workspace.
      // The blur overlay remains until Hyprland confirms both switches.
      const targets = [
        { monitor: "DP-2", workspace: 99 },
        { monitor: "DP-1", workspace: 98 }
      ].filter(target => savedWorkspaces.some(entry => entry.monitor === target.monitor))

      const retryDispatch = lockWorkspaceAttempts % 5 === 0
      Hyprland.refreshMonitors()
      const monitors = Hyprland.monitors.values
      for (const target of targets) {
        const monitor = monitors.find(item => item.name === target.monitor)
        if (monitor?.activeWorkspace?.id === target.workspace)
          continue
        if (!retryDispatch)
          continue
        focusMonitor(target.monitor)
        focusWorkspace(target.workspace)
      }
      Hyprland.refreshMonitors()

      const allReady = targets.length > 0 && targets.every(target => {
        const monitor = Hyprland.monitors.values.find(item => item.name === target.monitor)
        return monitor?.activeWorkspace?.id === target.workspace
      })
      lockWorkspaceAttempts += 1

      if (allReady) {
        lockWorkspacePoll.stop()
        lockWorkspaceTargets = targets.map(target => target.monitor)
        lockWorkspaceReveal.start()
      } else if (lockWorkspaceAttempts >= 20) {
        // Stay covered and allow authentication even if a monitor/workspace
        // could not be switched; never reveal an application as a fallback.
        lockWorkspacePoll.stop()
        lockError = "Não foi possível preparar as áreas vazias."
        lockReady = true
      }
    }

    function authenticate(password: string): void {
      if (!locked || !lockReady || pam.active || password.length === 0)
        return

      lockError = ""
      pendingPassword = password
      if (!pam.start()) {
        pendingPassword = ""
        lockError = "Não foi possível iniciar a autenticação."
      }
    }

    function unlockSession(): void {
      if (!locked)
        return

      lockReady = false
      unlockDelay.restart()
    }

    function restoreWorkspacesAndUnlock(): void {
      liveWallpaperVisible = false
      restoreWorkspaceAttempts = 0
      restoreWorkspacePoll.start()
    }

    function applyRestoreWorkspaces(): void {
      if (!locked)
        return

      Hyprland.refreshMonitors()
      const connectedMonitors = Hyprland.monitors.values
      const targets = savedWorkspaces.filter(entry =>
        connectedMonitors.some(monitor => monitor.name === entry.monitor)
      )
      const retryDispatch = restoreWorkspaceAttempts % 4 === 0

      for (const entry of targets) {
        const monitor = connectedMonitors.find(item => item.name === entry.monitor)
        if (monitor?.activeWorkspace?.id === entry.workspace || !retryDispatch)
          continue
        focusMonitor(entry.monitor)
        focusWorkspace(entry.workspace)
      }

      Hyprland.refreshMonitors()
      const allRestored = targets.every(entry => {
        const monitor = Hyprland.monitors.values.find(item => item.name === entry.monitor)
        return monitor?.activeWorkspace?.id === entry.workspace
      })

      restoreWorkspaceAttempts += 1
      if (allRestored || restoreWorkspaceAttempts >= 60) {
        restoreWorkspacePoll.stop()
        if (previouslyFocusedMonitor)
          focusMonitor(previouslyFocusedMonitor)

        lockWorkspacesApplied = false
        lockWorkspaceTargets = []
        blurOverlayVisible = false
        lockSurfaceSecure = false
        savedWorkspaces = []
        previouslyFocusedMonitor = ""
        locked = false
        Notifications.popupSuppressed = false
      }
    }

    IpcHandler {
      target: "launcher"
      function toggle(): void { scope.toggleLauncher() }
      function close(): void { scope.closeLauncher() }
    }

    IpcHandler {
      target: "notifications"
      function toggle(): void { Notifications.trayOpen = !Notifications.trayOpen }
    }

    IpcHandler {
      target: "session"
      function lock(): void { scope.lockSession() }
    }

    PamContext {
      id: pam
      config: "login"
      user: Quickshell.env("USER")
    }

    Connections {
      target: pam

      function onResponseRequiredChanged(): void {
        if (pam.responseRequired && scope.pendingPassword.length > 0) {
          const password = scope.pendingPassword
          scope.pendingPassword = ""
          pam.respond(password)
        }
      }

      function onCompleted(result): void {
        if (result === PamResult.Success) {
          scope.unlockSession()
        } else if (result === PamResult.Failed || result === PamResult.MaxTries) {
          scope.lockError = "Senha incorreta. Tente novamente."
        } else {
          scope.lockError = "Falha ao validar a senha."
        }
      }
    }

    Timer {
      id: unlockDelay
      interval: 220
      onTriggered: scope.restoreWorkspacesAndUnlock()
    }

    Timer {
      id: lockWorkspacePoll
      interval: 35
      repeat: true
      onTriggered: scope.applyLockWorkspaces()
    }

    Timer {
      id: restoreWorkspacePoll
      interval: 35
      repeat: true
      onTriggered: scope.applyRestoreWorkspaces()
    }

    Timer {
      id: lockWorkspaceReveal
      interval: 520
      onTriggered: {
        if (!scope.locked || !sessionLock.secure)
          return
        scope.lockWorkspacesApplied = true
        scope.liveWallpaperVisible = true
        if (Notifications.emptyWorkspaceOnLock && !Notifications.blurOnLock)
          scope.blurOverlayVisible = false
        scope.lockReady = true
      }
    }

    // A session-lock surface is not a regular QsWindow, so the compositor
    // blur request belongs on a normal fullscreen layer surface underneath it.
    Variants {
      model: Quickshell.screens

      delegate: PanelWindow {
        required property ShellScreen modelData
        id: lockBlurWindow

        screen: modelData
        visible: scope.locked && scope.blurOverlayVisible && scope.lockSurfaceSecure
        color: "transparent"
        focusable: false
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        anchors {
          top: true
          bottom: true
          left: true
          right: true
        }
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-lock-blur"
        BackgroundEffect.blurRegion: backdropRegion

        Region {
          id: backdropRegion
          item: lockBlurTint
        }

        Rectangle {
          id: lockBlurTint
          anchors.fill: parent
          color: '#00ffffff'
          //color: "#9911111b"
        }
      }
    }

    WlSessionLock {
      id: sessionLock
      locked: scope.locked

      onSecureChanged: {
        scope.lockSurfaceSecure = secure
        if (secure)
          scope.moveToLockWorkspaces()
      }

      surface: Component {
        WlSessionLockSurface {
          id: lockSurface
          color: "transparent"
          Rectangle {
            id: loginCard
            visible: lockSurface.screen?.name === "DP-2"
            enabled: scope.lockReady
            width: 390
            implicitHeight: contentColumn.implicitHeight + (contentColumn.anchors.margins * 2)
            height: implicitHeight
            anchors.centerIn: parent
            radius: 22
            color: "#ee181825"
            border.width: 1
            border.color: "#38384d"
            opacity: scope.lockReady ? 1 : 0
            scale: scope.lockReady ? 1 : 0.96

            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

            Column {
              id: contentColumn
              anchors.fill: parent
              anchors.margins: 28
              spacing: 5

              Text {
                width: parent.width
                text: "Sessão bloqueada"
                color: "#f4f4f8"
                font.pixelSize: 23
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
              }

              // Show user
/*               Text {
                width: parent.width
                text: Quickshell.env("USER")
                color: "#a7a7bc"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
              } */

              Item { width: 1; height: 5 }

              TextField {
                id: passwordField
                width: parent.width
                height: 46
                placeholderText: "Digite sua senha"
                placeholderTextColor: "#6c7086"
                echoMode: TextInput.Password
                enabled: scope.lockReady && !pam.active
                color: "#f4f4f8"
                font.pixelSize: 15
                leftPadding: 14
                rightPadding: 14
                background: Rectangle {
                  radius: 11
                  color: "#11111b"
                  border.width: passwordField.activeFocus ? 2 : 1
                  border.color: passwordField.activeFocus ? "#89b4fa" : "#38384d"
                }
                onAccepted: {
                  scope.authenticate(text)
                  text = ""
                }
                Connections {
                  target: scope
                  function onLockReadyChanged(): void {
                    if (scope.lockReady)
                      Qt.callLater(passwordField.forceActiveFocus)
                  }
                }
              }

              Text {
                width: parent.width
                height: 18
                text: pam.active ? "Validando…" : scope.lockError
                color: scope.lockError ? "#f38ba8" : "#a7a7bc"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }

              Button {
                id: unlockButton
                width: parent.width
                height: 42
                text: "Desbloquear"
                enabled: scope.lockReady && !pam.active && passwordField.text.length > 0
                onClicked: {
                  scope.authenticate(passwordField.text)
                  passwordField.clear()
                  passwordField.forceActiveFocus()
                }
                contentItem: Text {
                  text: unlockButton.text
                  color: "#11111b"
                  font.pixelSize: 14
                  font.weight: Font.DemiBold
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                  radius: 11
                  color: unlockButton.enabled ? (unlockButton.down ? "#74a8f5" : "#89b4fa") : "#4c5368"
                }
              }
            }
          }

          Item {
            id: lockNotificationStrip
            visible: lockSurface.screen?.name === "DP-2"
              && scope.lockReady && scope.lockNotificationGroups.count > 0
            width: loginCard.width
            height: iconSize
            anchors.horizontalCenter: loginCard.horizontalCenter
            anchors.bottom: loginCard.top
            anchors.bottomMargin: 16
            opacity: scope.lockReady ? 1 : 0

            property int iconSize: 46
            property int iconSpacing: 8
            readonly property int maxApps: Math.max(1,
              Math.floor((width + iconSpacing) / (iconSize + iconSpacing)))
            readonly property bool hasOverflow: scope.lockNotificationGroups.count > maxApps
            readonly property int shownAppCount: hasOverflow ? maxApps - 1 : maxApps

            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Row {
              anchors.centerIn: parent
              spacing: lockNotificationStrip.iconSpacing

              Behavior on x {
                NumberAnimation {
                  duration: Config.motion_spatial_ms
                  easing.type: Easing.BezierSpline
                  easing.bezierCurve: Config.motion_spatial_curve
                }
              }

              move: Transition {
                NumberAnimation {
                  properties: "x"
                  duration: Config.motion_spatial_ms
                  easing.type: Easing.BezierSpline
                  easing.bezierCurve: Config.motion_spatial_curve
                }
              }

              Repeater {
                model: scope.lockNotificationGroups

                delegate: Item {
                  id: lockNotificationItem
                  required property int index
                  required property string key
                  required property string appName
                  required property string icon
                  required property string avatar
                  required property int count
                  property string displayedGroupKey: ""
                  visible: index < lockNotificationStrip.shownAppCount
                  width: visible ? lockNotificationStrip.iconSize : 0
                  height: lockNotificationStrip.iconSize
                  scale: 0.84
                  opacity: 0

                  Component.onCompleted: {
                    displayedGroupKey = key
                    appCountRoller.resetCount(count)
                    notificationEntryAnimation.start()
                  }

                  onKeyChanged: {
                    if (!displayedGroupKey) {
                      displayedGroupKey = key
                      return
                    }
                    if (key !== displayedGroupKey) {
                      displayedGroupKey = key
                      appCountRoller.resetCount(count)
                      notificationEntryAnimation.restart()
                    } else
                      appCountRoller.showCount(count)
                  }

                  onCountChanged: {
                    if (displayedGroupKey === key)
                      appCountRoller.showCount(count)
                  }

                  SequentialAnimation {
                    id: notificationEntryAnimation
                    ParallelAnimation {
                      NumberAnimation {
                        target: lockNotificationItem
                        property: "scale"
                        to: 1.04
                        duration: 260
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Config.motion_spatial_curve
                      }
                      NumberAnimation {
                        target: lockNotificationItem
                        property: "opacity"
                        to: 1
                        duration: 220
                        easing.type: Easing.OutCubic
                      }
                    }
                    NumberAnimation {
                      target: lockNotificationItem
                      property: "scale"
                      to: 1
                      duration: 150
                      easing.type: Easing.OutCubic
                    }
                  }

                  Rectangle {
                    id: notificationAvatar
                    anchors.fill: parent
                    radius: width / 2
                    color: "#ee181825"
                    border.width: 1
                    border.color: "#38384d"
                    clip: true

                    Image {
                      id: notificationAvatarImage
                      anchors.fill: parent
                      anchors.margins: 2
                      source: lockNotificationItem.avatar
                      visible: !Notifications.lockScreenFullPrivacy && !!source
                      fillMode: Image.PreserveAspectCrop
                      smooth: true
                      sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                      mipmap: true

                      layer.enabled: visible
                      layer.effect: OpacityMask {
                        maskSource: Rectangle {
                          width: notificationAvatarImage.width
                          height: notificationAvatarImage.height
                          radius: width / 2
                          color: "white"
                        }
                      }
                    }

                    Image {
                      anchors.centerIn: parent
                      width: 25
                      height: 25
                      source: lockNotificationItem.icon
                      visible: Notifications.lockScreenFullPrivacy
                      fillMode: Image.PreserveAspectFit
                      sourceSize: Qt.size(50, 50)
                      smooth: true
                      mipmap: true
                      asynchronous: true
                    }

                    Text {
                      anchors.centerIn: parent
                      text: ""
                      color: "#cdd6f4"
                      font.family: "Font Awesome 7 Free"
                      font.pixelSize: 23
                      visible: !Notifications.lockScreenFullPrivacy
                        && !lockNotificationItem.avatar
                    }
                  }

                  Rectangle {
                    id: notificationAppBadge
                    width: 20
                    height: 20
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    radius: 7
                    color: "#313244"
                    border.width: 1
                    border.color: "#11111b"
                    visible: !Notifications.lockScreenFullPrivacy

                    Image {
                      anchors.fill: parent
                      anchors.margins: 3
                      source: lockNotificationItem.icon
                      fillMode: Image.PreserveAspectFit
                      sourceSize: Qt.size(28, 28)
                      smooth: true
                      mipmap: true
                      asynchronous: true
                    }
                  }

                  Rectangle {
                    id: appCountBadge
                    width: Math.max(19, appCountRoller.width + 8)
                    height: 19
                    anchors.right: parent.right
                    anchors.top: parent.top
                    radius: height / 2
                    color: "#89b4fa"
                    border.width: 1
                    border.color: "#11111b"
                    visible: lockNotificationItem.count > 1

                    Item {
                      id: appCountRoller
                      property int displayedCount: 0
                      property int incomingCount: 0
                      readonly property string displayedLabel: displayedCount > 99 ? "99+" : String(displayedCount)
                      readonly property string incomingLabel: incomingCount > 99 ? "99+" : String(incomingCount)
                      width: Math.max(countCurrent.implicitWidth, countIncoming.implicitWidth)
                      height: 12
                      anchors.centerIn: parent
                      clip: true

                      function resetCount(value) {
                        countRollAnimation.stop()
                        displayedCount = value
                        incomingCount = value
                        countCurrent.y = 0
                        countCurrent.opacity = 1
                        countIncoming.y = -height
                        countIncoming.opacity = 0
                      }

                      function showCount(value) {
                        if (value === displayedCount)
                          return
                        incomingCount = value
                        countRollAnimation.restart()
                      }

                      Text {
                        id: countCurrent
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        text: appCountRoller.displayedLabel
                        color: "#11111b"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                      }

                      Text {
                        id: countIncoming
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -appCountRoller.height
                        opacity: 0
                        text: appCountRoller.incomingLabel
                        color: "#11111b"
                        font.pixelSize: 9
                        font.weight: Font.Bold
                      }

                      ParallelAnimation {
                        id: countRollAnimation
                        NumberAnimation {
                          target: countCurrent
                          property: "y"
                          to: appCountRoller.height
                          duration: 190
                          easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                          target: countCurrent
                          property: "opacity"
                          to: 0
                          duration: 150
                        }
                        NumberAnimation {
                          target: countIncoming
                          property: "y"
                          to: 0
                          duration: 220
                          easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                          target: countIncoming
                          property: "opacity"
                          to: 1
                          duration: 150
                        }
                        onFinished: {
                          appCountRoller.displayedCount = appCountRoller.incomingCount
                          countCurrent.y = 0
                          countCurrent.opacity = 1
                          countIncoming.y = -appCountRoller.height
                          countIncoming.opacity = 0
                        }
                      }
                    }

                  }
                }
              }

              Item {
                visible: lockNotificationStrip.hasOverflow
                width: visible ? lockNotificationStrip.iconSize : 0
                height: lockNotificationStrip.iconSize

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: "#ee181825"
                  border.width: 1
                  border.color: "#38384d"

                  Text {
                    anchors.centerIn: parent
                    text: "…"
                    color: "#cdd6f4"
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                  }
                }

                Rectangle {
                  width: Math.max(19, overflowCountText.implicitWidth + 8)
                  height: 19
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  radius: height / 2
                  color: "#89b4fa"
                  border.width: 2
                  border.color: "#11111b"

                  Text {
                    id: overflowCountText
                    anchors.centerIn: parent
                    text: `+${scope.lockNotificationGroups.count - lockNotificationStrip.shownAppCount}`
                    color: "#11111b"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                  }
                }
              }
            }
          }
        }
      }
    }

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

        // Topbar exclusive zone
        ExclusionZone {
          screen: shellWindow.screen
          visible: shellWindow.screen.name === "DP-2"
          anchors {
            top: true
            left: true
            right: true
          }
          WlrLayershell.exclusionMode: ExclusionMode.Normal
          exclusiveZone: topbar.y + topbar.height
        }

        Item {
          id: screenFrame
          anchors.fill: parent
          visible: Config.frame_enabled

          readonly property bool hasTopbar: topbar.visible
          readonly property int topFrameY: hasTopbar ? topbar.height : 0
          readonly property int windowTopY: hasTopbar ? (topbar.height + Config.frame_thickness) : Config.frame_thickness

          // Top border (drawn at y=0 on secondary screen, and under the topbar at y=topbar.height on primary)
          Rectangle {
            x: 0
            y: screenFrame.topFrameY
            width: screenFrame.width
            height: Config.frame_thickness
            color: Config.frame_color
          }

          // Left border
          Rectangle {
            x: 0
            y: screenFrame.windowTopY
            width: Config.frame_thickness
            height: Math.max(0, screenFrame.height - screenFrame.windowTopY - Config.frame_thickness)
            color: Config.frame_color
          }

          // Right border
          Rectangle {
            x: screenFrame.width - Config.frame_thickness
            y: screenFrame.windowTopY
            width: Config.frame_thickness
            height: Math.max(0, screenFrame.height - screenFrame.windowTopY - Config.frame_thickness)
            color: Config.frame_color
          }

          // Bottom border
          Rectangle {
            x: 0
            y: screenFrame.height - Config.frame_thickness
            width: screenFrame.width
            height: Config.frame_thickness
            color: Config.frame_color
          }

          // Top-left interior corner
          FrameCorner {
            x: Config.frame_thickness
            y: screenFrame.windowTopY
          }

          // Top-right interior corner
          FrameCorner {
            x: screenFrame.width - Config.frame_thickness - width
            y: screenFrame.windowTopY
            flipHorizontal: true
          }

          // Bottom-left interior corner
          FrameCorner {
            x: Config.frame_thickness
            y: screenFrame.height - Config.frame_thickness - height
            flipVertical: true
          }

          // Bottom-right interior corner
          FrameCorner {
            x: screenFrame.width - Config.frame_thickness - width
            y: screenFrame.height - Config.frame_thickness - height
            flipHorizontal: true
            flipVertical: true
          }
        }

        mask: Region {
          x: 0
          y: 0
          width: shellWindow.width
          height: shellWindow.height
          intersection: Intersection.Xor
          regions: regions.instances
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
          
          Topbar {
            id: topbar
            parentWindow: shellWindow
            trayMenu: trayMenu
            launcherController: scope
            visible: parentWindow.screen.name === "DP-2"
                && (!scope.locked || (Notifications.emptyWorkspaceOnLock && !Notifications.blurOnLock))
          }
          NotificationPopups {
            id: notificationDrawer
            attachedTo: topbar
            isPrimaryScreen: shellWindow.screen.name === "DP-2"
          }
          NotificationTray {
            id: notificationTray
            attachedBar: topbar
            isPrimaryScreen: shellWindow.screen.name === "DP-2"
          }
          TrayMenu { id: trayMenu; parentWindow: shellWindow; }
        }

      }
    }

    Variants {
      model: Quickshell.screens

      delegate: Component {
        AppLauncher {
          required property ShellScreen modelData
          targetScreen: modelData
          launcherController: scope
        }
      }
    }

    // One shared dialog state, with a fullscreen input shield on every output.
    Variants {
      model: Quickshell.screens

      delegate: Component {
        DialogBox {
          required property ShellScreen modelData
          targetScreen: modelData
        }
      }
    }

    component ExclusionZone: PanelWindow {
      implicitWidth: 1
      implicitHeight: 1
      mask: Region {}
      WlrLayershell.namespace: `shell-exclusive-area`
    }

    component FrameCorner: Shape {
      id: corner

      property bool flipHorizontal: false
      property bool flipVertical: false

      width: Config.frame_corner_radius
      height: Config.frame_corner_radius
      antialiasing: true
      transform: Scale {
        xScale: corner.flipHorizontal ? -1 : 1
        yScale: corner.flipVertical ? -1 : 1
        origin.x: corner.width / 2
        origin.y: corner.height / 2
      }

      ShapePath {
        fillColor: Config.frame_color
        strokeColor: "transparent"
        startX: 0
        startY: corner.height
        PathLine { x: 0; y: 0 }
        PathLine { x: corner.width; y: 0 }
        PathCubic {
          x: 0
          y: corner.height
          control1X: corner.width * 0.4477
          control1Y: 0
          control2X: 0
          control2Y: corner.height * 0.4477
        }
      }
    }
  }

  Component.onCompleted: {
    Hypr.init()
    Weather.init()
    Notifications.init()
  }
}
