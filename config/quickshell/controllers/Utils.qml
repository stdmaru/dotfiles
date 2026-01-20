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
        const icon = DesktopEntries.heuristicLookup(name)?.icon;
        if (name.startsWith("steam_app_")) {
            return steamIconFromAppId(name)
        }
        else if (fallback !== "undefined") {
            return Quickshell.iconPath(icon, fallback);
        }
        return Quickshell.iconPath(icon);
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

    function fetch(options: var): void {
        var xhr = new XMLHttpRequest()
        xhr.open(options.method || "GET", options.url)

        var headers = options.headers || {}
        if (!headers["Content-Type"]) {
            xhr.setRequestHeader("Content-Type", "application/json")
        }

        for (var key in headers) {
            xhr.setRequestHeader(key, headers[key])
        }

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                var response = xhr.responseText
                try { response = JSON.parse(response) } catch (e) {}

                if (xhr.status >= 200 && xhr.status < 300) {
                    if (options.success) {
                        options.success(response)
                    }
                } else {
                    if (options.error) {
                        options.error(response)
                    }
                }
            }
        }

        xhr.send(options.body ? JSON.stringify(options.body) : null)
    }
}