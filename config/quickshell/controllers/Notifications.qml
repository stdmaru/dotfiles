pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    readonly property ListModel all: ListModel {}
    
    property bool doNotDisturb: false
    property bool trayOpen: false

    component NotificationModel: QtObject {
        id: notificationObject

        property int id
        property string image
        property string summary
        property string body
        property string appName
        property string appIcon
        property string desktopEntry
        property int urgency
        property bool hasActionIcons
        property bool hasInlineReply
        property string inlineReplyPlaceholder
        property bool lastGeneration
        property list<var> actions
        property bool resident
        property var hints
        property real expireTimeout
        property double createdAt
        
        property bool isPopup: true
        property bool isDeleted: false
        
        function remove(): void {
            for (let i = 0; i < root.all.count; i++) {
                if (root.all.get(i).modelData === this) {
                    root.all.remove(i)
                    break
                }
            }
        }
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: (n) => {
            n.tracked = true
            const notification = notificationModel.createObject(root, {
                id: n.id,
                image: n.image,
                summary: n.summary,
                body: n.body,
                appName: n.appName,
                appIcon: n.appIcon,
                desktopEntry: n.desktopEntry,
                urgency: n.urgency,
                hasActionIcons: n.hasActionIcons,
                hasInlineReply: n.hasInlineReply,
                inlineReplyPlaceholder: n.inlineReplyPlaceholder,
                lastGeneration: n.lastGeneration,
                actions: n.actions,
                resident: n.resident,
                hints: n.hints,
                expireTimeout: n.expireTimeout,
                createdAt: Date.now(),
            })
            
            root.all.insert(0, { "modelData": notification })
        }
    }

    function init(): void {
        console.info("Notification daemon started")
    }

    function hasPopup(): bool {
        for (let i = 0; i < root.all.count; ++i) {
            if (all.get(i).modelData.isPopup)
                return true
        }
        return false
    }

    function hasUnread(): bool {
        for (let i = 0; i < root.all.count; ++i) {
            if (all.get(i).modelData.isDeleted === false)
                return true
        }
        return false
    }

    Component {
        id: notificationModel
        NotificationModel{}
    }
}