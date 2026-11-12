pragma Singleton

import Quickshell
import QtQuick
import Qt.labs.folderlistmodel

Singleton {
    id: root

    FolderListModel {
        id: steamFiles
        showFiles: true
        showDirs: false
        nameFilters: ["*.jpg"]
        sortField: FolderListModel.Size
        sortReversed: true
    }

    function formatRelativeTime(ms: double): string {
        const seconds = Math.floor(ms / 1000)
        const minutes = Math.floor(seconds / 60)
        const hours   = Math.floor(minutes / 60)
        const days    = Math.floor(hours / 24)

        if (seconds < 30) return "agora mesmo"
        if (seconds < 60) return `há ${seconds}s`
        if (minutes === 1) return "há 1 minuto"
        if (minutes < 60) return `há ${minutes} minutos`
        if (hours === 1) return "há 1 hora"
        if (hours < 24) return `há ${hours}h`
        if (days === 1) return "ontem"
        if (days < 7) return `há ${days}d`

        return new Date(Date.now() - ms).toLocaleDateString("pt-BR")
    }

    function getAppIcon(name: string, fallback: string): string {
        const fallbackIcon = fallback || "application-x-executable"
        if (!name)
            return Quickshell.iconPath(fallbackIcon)
        if (name.startsWith("steam_app_"))
            return steamIconFromAppId(name)

        const icon = DesktopEntries.heuristicLookup(name)?.icon
        return Quickshell.iconPath(icon || name, fallbackIcon)
    }

    function steamIconFromAppId(appId: string): string {
        if (!appId.startsWith("steam_app_"))
            return ""

        const id = appId.slice("steam_app_".length)
        const basePath = `file://${Quickshell.env("HOME")}/.steam/steam/appcache/librarycache/${id}`
        steamFiles.folder = basePath
        
        if (steamFiles.count > 0) {
            return `file://${steamFiles.get(0, "filePath")}`
        }

        return Quickshell.iconPath("application-x-executable");
    }

    // GET/POST assíncrono. `success` recebe o corpo (JSON já decodificado
    // quando possível); `error` recebe o corpo e o status HTTP (0 = sem rede).
    function fetch(options: var): void {
        const xhr = new XMLHttpRequest()
        xhr.open(options.method || "GET", options.url)

        const headers = options.headers || {}
        if (options.body && !headers["Content-Type"])
            xhr.setRequestHeader("Content-Type", "application/json")
        for (const key in headers)
            xhr.setRequestHeader(key, headers[key])

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            let response = xhr.responseText
            try { response = JSON.parse(response) } catch (e) {}

            if (xhr.status >= 200 && xhr.status < 300)
                options.success?.(response)
            else
                options.error?.(response, xhr.status)
        }

        xhr.send(options.body ? JSON.stringify(options.body) : null)
    }
}
