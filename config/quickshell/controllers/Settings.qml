pragma Singleton

import Quickshell

// Estado da janela de configurações do shell: aberta/fechada e a categoria
// exibida. As preferências em si vivem em Preferences.
Singleton {
    id: root

    property bool open: false
    // Id de uma categoria de Preferences.categories.
    property string category: "user"

    function show(category: string): void {
        if (category)
            root.category = category
        root.open = true
    }

    function toggle(): void {
        root.open = !root.open
    }

    function close(): void {
        root.open = false
    }
}
