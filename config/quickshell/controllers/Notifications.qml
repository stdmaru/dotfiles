pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
    id: root

    // Linhas { modelData: NotificationEntry }, da mais nova para a mais antiga.
    readonly property ListModel all: ListModel {}
    readonly property ListModel popups: ListModel {}
    // Linhas { key, group: NotificationGroup } exibidas no painel.
    readonly property ListModel tray: ListModel {}
    // Objetos removidos continuam vivos por este intervalo para que os
    // delegates terminem suas animações de saída sem ler dados nulos.
    readonly property int destroyDelayMs: 2000

    readonly property string userdataDir: Quickshell.shellDir + "/userdata"
    readonly property string cacheDir: userdataDir + "/.cache"
    readonly property string historyPath: cacheDir + "/notifications.json"
    readonly property int historyLimit: 200

    // Preferências (userdata/preferences.json, via Preferences).
    readonly property bool doNotDisturb: Preferences.notifications.doNotDisturb
    property bool popupSuppressed: false
    readonly property bool lockScreenFullPrivacy: Preferences.lock.notificationPrivacy
    readonly property bool blurOnLock: Preferences.lock.blur
    readonly property bool emptyWorkspaceOnLock: Preferences.lock.emptyWorkspace
    property bool trayOpen: false
    property bool persistenceStarted: false
    property bool persistenceAvailable: false
    property bool historyLoaded: false
    property bool persistenceReady: false
    property var restoredNotifications: []
    property var pendingImageEncodes: []
    property var activeImageEncode: null
    property var pendingImageCleanup: []
    property int imagePersistenceVersion: 0
    property var historyWriteVersions: []
    property var pendingTempRemovals: []

    onDoNotDisturbChanged: {
        // DND hides active popups without removing their entries from history.
        if (doNotDisturb)
            popups.clear()
    }

    onPopupSuppressedChanged: {
        // Session lock suppresses transient popups but leaves tray history intact.
        if (popupSuppressed)
            popups.clear()
    }

    component NotificationEntry: QtObject {
        id: notificationObject

        property int id
        property string image
        property string imageBase64: ""
        property string imageMimeType: "image/png"
        property string summary
        property string body
        property string appName
        property string appIcon
        property string desktopEntry
        property int urgency
        property bool hasActionIcons
        property bool hasInlineReply
        property bool popupHovered: false
        property string inlineReplyPlaceholder
        property bool lastGeneration
        // Os rótulos das ações ficam como dados simples para que o histórico
        // continue íntegro mesmo depois que o serviço destruir a origem.
        property var actions: []
        property bool resident
        property var hints
        property real expireTimeout
        property double createdAt
        property var sourceNotification

        function remove(): void {
            root.dismissNotification(this)
        }

        readonly property Connections sourceConnections: Connections {
            target: notificationObject.sourceNotification

            function onClosed(reason): void {
                // O painel é dono do histórico; o fechamento da origem apenas
                // desabilita ações que não podem mais ser enviadas ao app.
                notificationObject.sourceNotification = null
            }

            function onActionsChanged(): void {
                const source = notificationObject.sourceNotification
                if (source) {
                    notificationObject.actions = Array.from(source.actions, action => ({
                        identifier: action.identifier,
                        text: action.text,
                    }))
                }
            }
        }
    }

    // Uma linha do painel: uma notificação comum ou várias mensagens do mesmo
    // remetente. As propriedades mudam no lugar, preservando o delegate.
    component NotificationGroup: QtObject {
        property string key
        property var notifications: []
        readonly property var head: notifications.length > 0 ? notifications[0] : null
        property string avatarSource
        property string displayBody
        // O cartão já iniciou a animação de saída por descarte do usuário.
        property bool dismissPending: false
        // "Limpar" pediu que todos os cartões saiam juntos.
        property bool exitRequested: false
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        inlineReplySupported: true
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
                imageBase64: "",
                imageMimeType: "image/png",
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
                actions: Array.from(n.actions, action => ({
                    identifier: action.identifier,
                    text: action.text,
                })),
                resident: n.resident,
                hints: n.hints,
                expireTimeout: n.expireTimeout,
                createdAt: Date.now(),
                sourceNotification: n,
            })

            root.all.insert(0, { modelData: notification })
            root.refreshTray(true)
            if (root.persistenceReady && !root.doNotDisturb && !root.popupSuppressed)
                root.popups.insert(0, { modelData: notification })
            if (root.persistenceReady)
                historySaveTimer.restart()
        }
    }

    Process {
        id: prepareUserdata
        // Remove leftover captures from earlier versions, which kept these
        // one-shot PNG files inside userdata/.cache.
        command: [
            "sh",
            "-c",
            "mkdir -p -- \"$1\" && rm -f -- \"$1\"/notification-image-*.png",
            "sh",
            root.cacheDir
        ]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("Could not create notification userdata directory")
                root.historyLoaded = true
                root.finishPersistenceLoad()
                return
            }

            root.persistenceAvailable = true
            historyFile.path = root.historyPath
        }
    }

    FileView {
        id: historyFile
        path: ""
        printErrors: false
        atomicWrites: true

        onLoaded: root.loadHistory(historyFile.text())
        onLoadFailed: root.loadHistory("")
        onSaveFailed: error => root.onHistorySaveFailed(error)
        onSaved: root.onHistorySaved()
    }

    Timer {
        id: historySaveTimer
        interval: 400
        repeat: false
        onTriggered: root.saveHistory()
    }

    Process {
        id: imageEncoder
        command: []

        stdout: StdioCollector {
            id: imageEncoderOutput
        }

        onExited: (exitCode, exitStatus) => {
            root.finishImageEncode(exitCode, imageEncoderOutput.text.trim())
        }
    }

    Process {
        id: tempImageCleaner
        command: []
        onExited: root.startTempImageCleanup()
    }

    function indexOf(model, notification) {
        for (let i = 0; i < model.count; ++i) {
            if (model.get(i).modelData === notification)
                return i
        }
        return -1
    }

    function loadHistory(contents): void {
        let records = []
        if (contents.trim()) {
            try {
                const data = JSON.parse(contents)
                records = Array.isArray(data) ? data : data.notifications
                if (!Array.isArray(records))
                    records = []
            } catch (error) {
                console.warn("Invalid notification history JSON; starting with an empty history:", error)
            }
        }

        root.restoredNotifications = records.slice(0, root.historyLimit).map(record => {
            if (!record || typeof record !== "object")
                return null

            const savedHints = record.hints ?? ({})
            const imageBase64 = String(record.imageBase64 ?? "")
            const imageMimeType = String(record.imageMimeType ?? "image/png")
            const savedImage = String(record.image ?? "")
            const hints = {
                category: String(savedHints.category ?? ""),
                sender: String(savedHints.sender ?? ""),
                "sender-name": String(savedHints["sender-name"] ?? ""),
                account: String(savedHints.account ?? ""),
                "conversation-id": String(savedHints["conversation-id"] ?? ""),
                "chat-id": String(savedHints["chat-id"] ?? "")
            }
            const createdAt = Number(record.createdAt) || Date.now()
            return notificationModel.createObject(root, {
                id: Number(record.id) || 0,
                image: imageBase64
                    ? `data:${imageMimeType};base64,${imageBase64}`
                    : (savedImage.startsWith("image://qsimage/") ? "" : savedImage),
                imageBase64: imageBase64,
                imageMimeType: imageMimeType,
                summary: String(record.summary ?? ""),
                body: String(record.body ?? ""),
                appName: String(record.appName ?? ""),
                appIcon: String(record.appIcon ?? ""),
                desktopEntry: String(record.desktopEntry ?? ""),
                urgency: Number(record.urgency) || 0,
                hasActionIcons: false,
                hasInlineReply: false,
                inlineReplyPlaceholder: "",
                lastGeneration: false,
                actions: [],
                resident: false,
                hints: hints,
                expireTimeout: 0,
                createdAt: createdAt,
                sourceNotification: null
            })
        }).filter(notification => notification !== null)

        root.historyLoaded = true
        root.finishPersistenceLoad()
    }

    function finishPersistenceLoad(): void {
        if (root.persistenceReady || !root.historyLoaded)
            return

        const notifications = []
        for (let i = 0; i < root.all.count; ++i)
            notifications.push(root.all.get(i).modelData)
        for (const notification of root.restoredNotifications)
            notifications.push(notification)
        notifications.sort((left, right) => right.createdAt - left.createdAt)

        root.all.clear()
        for (const notification of notifications)
            root.all.append({ modelData: notification })

        root.refreshTray(true)
        root.popups.clear()
        if (!root.doNotDisturb && !root.popupSuppressed) {
            for (let i = root.all.count - 1; i >= 0; --i) {
                const notification = root.all.get(i).modelData
                if (notification.sourceNotification)
                    root.popups.insert(0, { modelData: notification })
            }
        }

        root.restoredNotifications = []
        root.persistenceReady = true
        historySaveTimer.restart()
    }

    function notificationSnapshot(notification): var {
        const hints = notification.hints ?? ({})
        return {
            id: notification.id,
            // The data URL can be reconstructed from imageBase64 on load; do
            // not duplicate the PNG payload in the JSON record.
            image: notification.imageBase64 ? "" : notification.image,
            imageBase64: notification.imageBase64,
            imageMimeType: notification.imageMimeType,
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            appIcon: notification.appIcon,
            desktopEntry: notification.desktopEntry,
            urgency: notification.urgency,
            createdAt: notification.createdAt,
            hints: {
                category: String(hints.category ?? ""),
                sender: String(hints.sender ?? ""),
                "sender-name": String(hints["sender-name"] ?? ""),
                account: String(hints.account ?? ""),
                "conversation-id": String(hints["conversation-id"] ?? ""),
                "chat-id": String(hints["chat-id"] ?? "")
            }
        }
    }

    function saveHistory(): void {
        if (!root.persistenceReady || !root.persistenceAvailable)
            return

        const records = []
        for (let i = 0; i < Math.min(root.all.count, root.historyLimit); ++i)
            records.push(root.notificationSnapshot(root.all.get(i).modelData))
        root.historyWriteVersions.push(root.imagePersistenceVersion)
        historyFile.setText(JSON.stringify({ schemaVersion: 1, notifications: records }, null, 2))
    }

    function onHistorySaved(): void {
        historySaveTimer.interval = 400
        const savedImageVersion = root.historyWriteVersions.length > 0
            ? root.historyWriteVersions.shift()
            : 0
        const remaining = []
        for (const image of root.pendingImageCleanup) {
            if (image.version <= savedImageVersion)
                root.pendingTempRemovals.push(image.filePath)
            else
                remaining.push(image)
        }
        root.pendingImageCleanup = remaining
        root.startTempImageCleanup()

        if (root.pendingImageCleanup.length > 0)
            historySaveTimer.restart()
    }

    function onHistorySaveFailed(error): void {
        console.warn("Could not save notification history:", error)
        if (root.historyWriteVersions.length > 0)
            root.historyWriteVersions.shift()
        // Keep temporary images until a later successful write can prove the
        // corresponding base64 payload reached the history file.
        historySaveTimer.interval = 3000
        historySaveTimer.restart()
    }

    function startTempImageCleanup(): void {
        if (tempImageCleaner.running || root.pendingTempRemovals.length === 0)
            return

        const paths = root.pendingTempRemovals.splice(0)
        const command = ["rm", "-f", "--"]
        for (const path of paths)
            command.push(path)
        tempImageCleaner.command = command
        tempImageCleaner.running = true
    }

    function captureNotificationImage(notification, filePath): void {
        if (!filePath)
            return

        if (!notification || notification.imageBase64 || root.indexOf(root.all, notification) < 0) {
            root.queueTempImageRemoval(filePath)
            return
        }

        if (root.activeImageEncode?.notification === notification
                || root.pendingImageEncodes.some(job => job.notification === notification)) {
            root.queueTempImageRemoval(filePath)
            return
        }

        root.pendingImageEncodes.push({ notification: notification, filePath: filePath })
        root.startNextImageEncode()
    }

    function queueTempImageRemoval(filePath): void {
        if (!filePath)
            return
        root.pendingTempRemovals.push(filePath)
        root.startTempImageCleanup()
    }

    function startNextImageEncode(): void {
        if (imageEncoder.running || root.activeImageEncode || root.pendingImageEncodes.length === 0)
            return

        root.activeImageEncode = root.pendingImageEncodes.shift()
        imageEncoder.command = [
            "base64",
            "-w0",
            "--",
            root.activeImageEncode.filePath
        ]
        imageEncoder.running = true
    }

    function finishImageEncode(exitCode, imageBase64): void {
        const job = root.activeImageEncode
        root.activeImageEncode = null
        if (exitCode === 0 && imageBase64 && job
                && root.indexOf(root.all, job.notification) >= 0) {
            const notification = job.notification
            notification.imageBase64 = imageBase64
            notification.imageMimeType = "image/png"
            notification.image = `data:image/png;base64,${imageBase64}`
            root.imagePersistenceVersion += 1
            root.refreshTray(true)
            root.pendingImageCleanup.push({
                filePath: job.filePath,
                version: root.imagePersistenceVersion
            })
            if (persistenceReady)
                historySaveTimer.restart()
        } else {
            if (exitCode !== 0)
                console.warn("Could not encode notification image as base64")
            if (job)
                root.queueTempImageRemoval(job.filePath)
        }

        root.startNextImageEncode()
    }

    function messageGroupKey(notification) {
        const hints = notification.hints ?? ({})
        const category = String(hints.category ?? "").trim().toLowerCase()
        const hasMessageCategory = category.startsWith("im.")
            || category === "message"
            || category === "messages"
        // Some messaging clients omit category and conversation hints. In
        // that case use the repeated sender + app identity requested by the
        // user. An explicit non-message category is kept as an ordinary row.
        if (category && !hasMessageCategory)
            return ""

        const sender = [hints.sender, hints["sender-name"], notification.summary]
            .map(value => String(value ?? "").trim())
            .find(value => value.length > 0)?.toLowerCase() ?? ""
        const app = String(notification.desktopEntry || notification.appName || "").trim().toLowerCase()
        if (!sender || !app)
            return ""

        const origin = [hints.account, hints["conversation-id"], hints["chat-id"]]
            .map(value => String(value ?? "").trim())
            .find(value => value.length > 0)?.toLowerCase() ?? ""
        return `message|${app}|${sender}|${origin}`
    }

    function refreshTray(allowReorder: bool): void {
        const entries = []
        const byKey = new Map()

        // Notificações comuns ficam em linhas individuais; só mensagens do
        // mesmo app, remetente e conversa são agrupadas.
        for (let i = 0; i < all.count; ++i) {
            const notification = all.get(i).modelData
            const key = messageGroupKey(notification)
            let entry = key ? byKey.get(key) : null
            if (!entry) {
                entry = {
                    key: key || `notification:${notification.id}:${notification.createdAt}`,
                    avatarSource: notification.image || "",
                    notifications: [],
                    bodyParts: []
                }
                entries.push(entry)
                if (key)
                    byKey.set(key, entry)
            }
            if (!entry.avatarSource && notification.image)
                entry.avatarSource = notification.image
            entry.notifications.push(notification)
            if (notification.body)
                entry.bodyParts.unshift(notification.body)
        }

        // Sincroniza as linhas por chave em vez de reconstruir o modelo:
        // delegates estáveis preservam as animações em andamento.
        const nextKeys = new Set(entries.map(entry => entry.key))
        for (let row = tray.count - 1; row >= 0; --row) {
            const current = tray.get(row)
            if (nextKeys.has(current.key))
                continue
            const group = current.group
            tray.remove(row)
            group.destroy(root.destroyDelayMs)
        }

        for (let target = 0; target < entries.length; ++target) {
            const entry = entries[target]
            const displayBody = entry.bodyParts.join("\n")
            let row = -1
            for (let i = 0; i < tray.count; ++i) {
                if (tray.get(i).key === entry.key) {
                    row = i
                    break
                }
            }

            if (row < 0) {
                tray.insert(Math.min(target, tray.count), {
                    key: entry.key,
                    group: groupComponent.createObject(root, {
                        key: entry.key,
                        notifications: entry.notifications,
                        avatarSource: entry.avatarSource,
                        displayBody: displayBody
                    })
                })
                continue
            }

            const group = tray.get(row).group
            if (!sameNotifications(group.notifications, entry.notifications))
                group.notifications = entry.notifications
            if (group.avatarSource !== entry.avatarSource)
                group.avatarSource = entry.avatarSource
            if (group.displayBody !== displayBody)
                group.displayBody = displayBody
            if (allowReorder && row !== target)
                tray.move(row, target, 1)
        }
    }

    function sameNotifications(left, right): bool {
        if (!left || left.length !== right.length)
            return false
        for (let i = 0; i < right.length; ++i) {
            if (left[i] !== right[i])
                return false
        }
        return true
    }

    function dismissPopup(notification) {
        const index = indexOf(root.popups, notification)
        if (index >= 0)
            root.popups.remove(index)
    }

    function expirePopup(notification): bool {
        // The view can race with the timer event by a frame. Treat the model's
        // hover state as the source of truth before removing the popup row.
        if (!notification || notification.popupHovered)
            return false

        root.dismissPopup(notification)
        return true
    }

    // Tira a notificação dos modelos e agenda a destruição do objeto.
    function detach(notification, dismissRemote: bool): bool {
        dismissPopup(notification)

        const index = indexOf(root.all, notification)
        if (index < 0)
            return false

        root.all.remove(index)
        const source = notification.sourceNotification
        notification.sourceNotification = null
        if (dismissRemote && source)
            source.dismiss()
        notification.destroy(root.destroyDelayMs)
        return true
    }

    function dismissNotification(notification): void {
        dismissNotificationGroup([notification])
    }

    function dismissNotificationGroup(notifications): void {
        let changed = false
        for (const notification of Array.from(notifications ?? [])) {
            if (notification && detach(notification, true))
                changed = true
        }

        if (changed) {
            root.refreshTray(false)
            if (persistenceReady)
                historySaveTimer.restart()
        }
    }

    function clearAll(): void {
        popups.clear()
        if (all.count === 0)
            return

        // Pede que cada cartão visível anime a saída primeiro; o histórico só
        // é removido depois que os delegates terminam.
        for (let i = 0; i < tray.count; ++i)
            tray.get(i).group.exitRequested = true
        clearAllTimer.restart()
    }

    function finishClearAll(): void {
        const notifications = []
        for (let i = 0; i < all.count; ++i)
            notifications.push(all.get(i).modelData)
        const groups = []
        for (let i = 0; i < tray.count; ++i)
            groups.push(tray.get(i).group)

        // Limpa os modelos e dispensa as notificações remotas para que o
        // servidor não mantenha entradas ativas obsoletas.
        popups.clear()
        all.clear()
        tray.clear()
        for (const group of groups)
            group.destroy(root.destroyDelayMs)
        for (const notification of notifications) {
            const source = notification.sourceNotification
            notification.sourceNotification = null
            if (source)
                source.dismiss()
            notification.destroy(root.destroyDelayMs)
        }
        if (persistenceReady)
            historySaveTimer.restart()
    }

    Timer {
        id: clearAllTimer
        interval: Config.notification_panel_ms + 120
        repeat: false
        onTriggered: root.finishClearAll()
    }

    function activateAction(notification, identifier): bool {
        const source = notification?.sourceNotification
        if (!source)
            return false

        const action = Array.from(source.actions).find(candidate => candidate.identifier === identifier)
        if (!action)
            return false

        action.invoke()
        return true
    }

    function sendInlineReply(notification, replyText): bool {
        const source = notification?.sourceNotification
        if (!source || !notification.hasInlineReply || !replyText.trim())
            return false

        source.sendInlineReply(replyText)
        return true
    }

    function init(): void {
        if (persistenceStarted)
            return
        persistenceStarted = true
        prepareUserdata.running = true
    }

    Component {
        id: notificationModel
        NotificationEntry {}
    }

    Component {
        id: groupComponent
        NotificationGroup {}
    }
}
