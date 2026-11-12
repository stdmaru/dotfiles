pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell
import QtQuick
import Qt5Compat.GraphicalEffects

// Faixa de avatares/ícones acima do cartão de login, resumindo as notificações
// pendentes. Em privacidade total agrupa por aplicativo; senão, por remetente.
Item {
  id: root

  readonly property bool hasNotifications: groups.count > 0

  height: iconSize

  ListModel {
    id: groups
  }

  // Sincroniza o modelo por chave, sem recriá-lo, para preservar as animações
  // dos itens que permanecem.
  function rebuild(): void {
    const byKey = new Map()
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
      const group = byKey.get(key) ?? {
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
      byKey.set(key, group)
    }

    const sorted = Array.from(byKey.values())
      .sort((left, right) => right.newestAt - left.newestAt)
    const nextKeys = sorted.map(group => group.key)

    for (let i = groups.count - 1; i >= 0; --i) {
      if (!nextKeys.includes(groups.get(i).key))
        groups.remove(i)
    }

    for (let target = 0; target < sorted.length; ++target) {
      const group = sorted[target]
      let current = -1
      for (let i = target; i < groups.count; ++i) {
        if (groups.get(i).key === group.key) {
          current = i
          break
        }
      }

      if (current < 0) {
        groups.insert(target, group)
      } else {
        if (current !== target)
          groups.move(current, target, 1)
        groups.set(target, group)
      }
    }
  }

  Connections {
    target: Notifications.all
    function onCountChanged(): void { root.rebuild() }
  }

  Connections {
    target: Notifications
    function onLockScreenFullPrivacyChanged(): void { root.rebuild() }
    function onImagePersistenceVersionChanged(): void { root.rebuild() }
  }

  Component.onCompleted: rebuild()

  property int iconSize: 46
  property int iconSpacing: 8
  readonly property int maxApps: Math.max(1,
    Math.floor((width + iconSpacing) / (iconSize + iconSpacing)))
  readonly property bool hasOverflow: groups.count > maxApps
  readonly property int shownAppCount: hasOverflow ? maxApps - 1 : maxApps

  Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

  Row {
    anchors.centerIn: parent
    spacing: root.iconSpacing

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
      model: groups

      delegate: Item {
        id: lockNotificationItem
        required property int index
        required property string key
        required property string appName
        required property string icon
        required property string avatar
        required property int count
        property string displayedGroupKey: ""
        visible: index < root.shownAppCount
        width: visible ? root.iconSize : 0
        height: root.iconSize
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
          border.color: Theme.outline
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
            text: "\uf0f3"
            color: Theme.text
            font.family: Theme.font_awesome
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
          color: Theme.surface0
          border.width: 1
          border.color: Theme.crust
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
          color: Theme.blue
          border.width: 1
          border.color: Theme.crust
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
              color: Theme.crust
              font.family: Theme.font_ui
              font.pixelSize: 9
              font.weight: Font.Bold
            }

            Text {
              id: countIncoming
              anchors.horizontalCenter: parent.horizontalCenter
              y: -appCountRoller.height
              opacity: 0
              text: appCountRoller.incomingLabel
              color: Theme.crust
              font.family: Theme.font_ui
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
      visible: root.hasOverflow
      width: visible ? root.iconSize : 0
      height: root.iconSize

      Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "#ee181825"
        border.width: 1
        border.color: Theme.outline

        Text {
          anchors.centerIn: parent
          text: `+${groups.count - root.shownAppCount}`
          color: Theme.text
          font.family: Theme.font_ui
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
        color: Theme.blue
        border.width: 2
        border.color: Theme.crust
        visible: false
        Text {
          id: overflowCountText
          anchors.centerIn: parent
          text: `+${groups.count - root.shownAppCount}`
          color: Theme.crust
          font.family: Theme.font_ui
          font.pixelSize: 9
          font.weight: Font.Bold
        }
      }
    }
  }
}
