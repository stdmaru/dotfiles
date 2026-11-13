pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick

// Preferências do usuário, persistidas em userdata/preferences.json.
//
// Cada categoria é um objeto com propriedades reais, então o resto do shell
// simplesmente faz binding nelas (ex.: `Preferences.bar.height`). O esquema em
// `categories` descreve as mesmas chaves para a janela de configurações:
// rótulo, tipo de controle e limites. Os valores padrão são os declarados nos
// objetos abaixo.
//
// Qualquer mudança é gravada no arquivo; editar o arquivo à mão também é
// refletido no shell em tempo real.
Singleton {
    id: root

    readonly property string path: Quickshell.shellDir + "/userdata/preferences.json"
    readonly property int schemaVersion: 2

    readonly property QtObject user: QtObject {
        // Vazio = nome de login ($USER).
        property string displayName: ""
        // Vazio = ícone do AccountsService.
        property string avatar: ""
        property string terminal: "alacritty"
    }

    readonly property QtObject bar: QtObject {
        property int height: 50
        property int cornerRadius: 12
        // Modo moldura: a barra vira a faixa de cima de uma moldura em volta
        // da tela. Desligado, a barra flutua.
        property bool frameEnabled: false
        property int frameThickness: 8
        property int frameCornerRadius: 16
        // Raio das curvas da silhueta dos painéis que brotam da barra.
        property int panelCurve: 30
        property bool workspacesShowAll: true
        property int workspacesMax: 7
        // "numbers", "roman" ou "japanese".
        property string workspaceLabels: "japanese"
        // "auto", "NVIDIA", "GENERIC" ou "NONE".
        property string gpuType: "NVIDIA"
    }

    readonly property QtObject behavior: QtObject {
        property string primaryScreen: "DP-2"
        property bool focusUrgentWindows: true
    }

    readonly property QtObject lock: QtObject {
        property bool blur: true
        // Ao bloquear, cada monitor vai para uma workspace vazia. Desligado, a
        // workspace atual fica atrás do bloqueio, o que exige o desfoque.
        property bool hideWorkspace: true
        // Esconde a barra e a moldura enquanto bloqueado. Só vale com
        // "Ocultar workspace" (sem ela, a interface sempre aparece).
        property bool hideInterface: true
        // Nome e foto do usuário no cartão de login.
        property bool showUser: true
        // Notificações na tela de bloqueio só mostram o aplicativo.
        property bool notificationPrivacy: false

        // Regras entre as opções: sem desfoque, a workspace tem de ser
        // ocultada (os aplicativos ficariam à mostra); com a workspace à
        // mostra, "Ocultar interface" não se aplica. Rodam a cada mudança e
        // depois de ler o arquivo.
        function enforceRules(): void {
            if (!blur)
                hideWorkspace = true
            if (!hideWorkspace)
                hideInterface = false
        }

        onBlurChanged: enforceRules()
        onHideWorkspaceChanged: enforceRules()
    }

    readonly property QtObject notifications: QtObject {
        property bool doNotDisturb: false
        // "center" ou "right".
        property string popupPosition: "center"
        property int popupWidth: 470
    }

    readonly property var groups: ({
        user: root.user,
        bar: root.bar,
        behavior: root.behavior,
        lock: root.lock,
        notifications: root.notifications
    })

    // Esquema exibido pela janela de configurações. Tipos: "bool", "int",
    // "choice" e "text". `enabledWhen` e `visibleWhen` nomeiam uma chave
    // booleana da mesma categoria; `optionsFrom: "screens"` lista os monitores.
    readonly property var categories: [
        {
            id: "user",
            label: "Usuário",
            glyph: "",
            description: "Como você aparece no shell e os aplicativos que ele abre.",
            sections: [
                {
                    title: "Perfil",
                    settings: [
                        { key: "displayName", type: "text", label: "Nome exibido",
                          description: "Mostrado na tela de bloqueio.",
                          placeholder: Quickshell.env("USER") ?? "" },
                        { key: "avatar", type: "text", label: "Foto",
                          description: "Caminho de uma imagem. Vazio usa a foto da conta do sistema.",
                          placeholder: "/var/lib/AccountsService/icons/" + (Quickshell.env("USER") ?? "") }
                    ]
                },
                {
                    title: "Aplicativos",
                    settings: [
                        { key: "terminal", type: "text", label: "Terminal",
                          description: "Comando usado pelo lançador para apps de terminal.",
                          placeholder: "alacritty" }
                    ]
                }
            ]
        },
        {
            id: "bar",
            label: "Barra de navegação",
            glyph: "",
            description: "Estilo da barra superior (flutuante ou moldura), workspaces e recursos.",
            sections: [
                {
                    title: "Estilo",
                    settings: [
                        { key: "frameEnabled", type: "bool", label: "Modo moldura",
                          description: "A barra vira a faixa de cima de uma moldura em volta da tela, e as janelas ficam no recorte arredondado do meio. Desligado, a barra flutua." },
                        { key: "frameThickness", type: "int", label: "Espessura da moldura", unit: "px",
                          description: "Laterais e base; o topo é a própria barra.",
                          min: 0, max: 24, step: 1, enabledWhen: "frameEnabled" },
                        { key: "frameCornerRadius", type: "int", label: "Curvatura da moldura", unit: "px",
                          description: "Cantos do recorte onde ficam as janelas.",
                          min: 0, max: 48, step: 1, enabledWhen: "frameEnabled" },
                        { key: "panelCurve", type: "int", label: "Curvatura dos painéis", unit: "px",
                          description: "Curvas da silhueta dos painéis que brotam da barra (menus, lançador, bandeja e notificações): a rampa até a barra, os cantos de baixo e o encaixe na moldura.",
                          min: 8, max: 48, step: 1 }
                    ]
                },
                {
                    title: "Barra",
                    settings: [
                        { key: "height", type: "int", label: "Altura", unit: "px",
                          min: 36, max: 72, step: 2 },
                        { key: "cornerRadius", type: "int", label: "Arredondamento", unit: "px",
                          description: "Cantos da barra flutuante.",
                          min: 0, max: 24, step: 1, enabledWhen: "!frameEnabled" }
                    ]
                },
                {
                    title: "Workspaces",
                    settings: [
                        { key: "workspacesShowAll", type: "bool", label: "Mostrar todas",
                          description: "Exibe também as workspaces vazias." },
                        { key: "workspacesMax", type: "int", label: "Quantidade",
                          min: 1, max: 9, step: 1 },
                        { key: "workspaceLabels", type: "choice", label: "Rótulos",
                          options: [
                              { value: "numbers", label: "1 2 3" },
                              { value: "roman", label: "I II III" },
                              { value: "japanese", label: "一 二 三" }
                          ] }
                    ]
                },
                {
                    title: "Recursos do sistema",
                    settings: [
                        { key: "gpuType", type: "choice", label: "Monitorar GPU",
                          options: [
                              { value: "auto", label: "Detectar" },
                              { value: "NVIDIA", label: "NVIDIA" },
                              { value: "GENERIC", label: "AMD/Intel" },
                              { value: "NONE", label: "Nenhuma" }
                          ] }
                    ]
                }
            ]
        },
        {
            id: "behavior",
            label: "Comportamento",
            glyph: "",
            description: "Onde o shell aparece e como ele reage às janelas.",
            sections: [
                {
                    title: "Monitores",
                    settings: [
                        { key: "primaryScreen", type: "choice", optionsFrom: "screens",
                          label: "Monitor principal",
                          description: "Recebe a barra, as notificações e o cartão de login." }
                    ]
                },
                {
                    title: "Janelas",
                    settings: [
                        { key: "focusUrgentWindows", type: "bool", label: "Focar janelas urgentes",
                          description: "Vai até a janela que pede atenção (ex.: um link aberto no navegador)." }
                    ]
                }
            ]
        },
        {
            id: "lock",
            label: "Tela de bloqueio",
            glyph: "",
            description: "O que fica visível enquanto a sessão está bloqueada.",
            sections: [
                {
                    title: "Fundo",
                    settings: [
                        { key: "blur", type: "bool", label: "Desfocar o fundo",
                          description: "Desfoca o que fica atrás do bloqueio." },
                        { key: "hideWorkspace", type: "bool", label: "Ocultar workspace",
                          description: "Ao bloquear, cada monitor vai para uma workspace vazia. Desligado, os aplicativos da workspace atual ficam atrás do bloqueio, desfocados.",
                          enabledWhen: "blur" },
                        { key: "hideInterface", type: "bool", label: "Ocultar interface",
                          description: "Some com a barra e a moldura enquanto a sessão está bloqueada.",
                          enabledWhen: "hideWorkspace" }
                    ]
                },
                {
                    title: "Login",
                    settings: [
                        { key: "showUser", type: "bool", label: "Exibir usuário",
                          description: "Mostra o nome e a foto do usuário no cartão de login." }
                    ]
                },
                {
                    title: "Notificações",
                    settings: [
                        { key: "notificationPrivacy", type: "bool", label: "Ocultar conteúdo",
                          description: "Mostra só o aplicativo de cada notificação, sem título nem texto." }
                    ]
                }
            ]
        },
        {
            id: "notifications",
            label: "Notificações",
            glyph: "",
            description: "Avisos que aparecem sobre a área de trabalho.",
            sections: [
                {
                    title: "Avisos",
                    settings: [
                        { key: "doNotDisturb", type: "bool", label: "Não perturbe",
                          description: "Guarda as notificações no painel sem exibir popups." }
                    ]
                },
                {
                    title: "Popups",
                    settings: [
                        { key: "popupPosition", type: "choice", label: "Posição",
                          description: "Os popups descem da barra no centro ou encaixados no canto direito.",
                          options: [
                              { value: "center", label: "Centro" },
                              { value: "right", label: "Direita" }
                          ] },
                        { key: "popupWidth", type: "int", label: "Largura", unit: "px",
                          min: 320, max: 760, step: 10 }
                    ]
                }
            ]
        }
    ]

    // Valores declarados acima, capturados antes do primeiro carregamento.
    property var defaults: ({})
    // Chaves do arquivo que este esquema não conhece; são preservadas.
    property var unknownKeys: ({})
    property bool applying: false

    function settingsOf(categoryId: string): var {
        const category = root.categories.find(c => c.id === categoryId)
        const settings = []
        for (const section of category?.sections ?? [])
            settings.push(...section.settings)
        return settings
    }

    function defaultOf(categoryId: string, key: string): var {
        return root.defaults[categoryId]?.[key]
    }

    function set(categoryId: string, key: string, value: var): void {
        const group = root.groups[categoryId]
        const setting = root.settingsOf(categoryId).find(s => s.key === key)
        if (!group || !setting)
            return
        group[key] = root.coerce(setting, value, group[key])
    }

    function reset(categoryId: string, key: string): void {
        root.set(categoryId, key, root.defaultOf(categoryId, key))
    }

    function resetCategory(categoryId: string): void {
        for (const setting of root.settingsOf(categoryId))
            root.reset(categoryId, setting.key)
    }

    function isDefault(categoryId: string, key: string): bool {
        return root.groups[categoryId]?.[key] === root.defaultOf(categoryId, key)
    }

    // Converte um valor vindo do arquivo ou da interface para o tipo da
    // chave; valores inválidos mantêm `fallback`.
    function coerce(setting: var, value: var, fallback: var): var {
        switch (setting.type) {
        case "bool":
            return typeof value === "boolean" ? value : fallback
        case "int": {
            const number = Number(value)
            if (value === null || value === "" || !Number.isFinite(number))
                return fallback
            return Math.max(setting.min, Math.min(setting.max, Math.round(number)))
        }
        case "choice":
            if (typeof value !== "string")
                return fallback
            if (setting.options && !setting.options.some(o => o.value === value))
                return fallback
            return value
        default:
            return typeof value === "string" ? value : fallback
        }
    }

    // Formato 1 (gravado pelo controller de notificações): chaves soltas.
    function migrate(data: var): var {
        if ((data.schemaVersion ?? 1) >= 2)
            return data

        const legacyNotifications = data.notifications ?? ({})
        const migrated = {
            lock: {
                emptyWorkspace: data.empty_workspace_on_lock,
                blur: data.blur_on_lock,
                notificationPrivacy: legacyNotifications.notifications_lockscreen_full_privacy
            },
            notifications: {
                doNotDisturb: legacyNotifications.doNotDisturb ?? data.doNotDisturb
            }
        }
        for (const key of Object.keys(data)) {
            if (!["schemaVersion", "notifications", "doNotDisturb",
                  "blur_on_lock", "empty_workspace_on_lock"].includes(key))
                migrated[key] = data[key]
        }
        return migrated
    }

    function apply(contents: string): void {
        let data = {}
        let rewrite = false
        if (contents.trim()) {
            try {
                data = JSON.parse(contents)
            } catch (error) {
                console.warn("preferences.json inválido; mantendo os valores atuais:", error)
                return
            }
        } else {
            rewrite = true
        }
        if (!data || typeof data !== "object" || Array.isArray(data))
            data = {}
        if ((data.schemaVersion ?? 1) < root.schemaVersion)
            rewrite = true
        data = root.migrate(data)

        // Nomes antigos da opção de workspace: "emptyWorkspace" (mesmo
        // sentido) e "showWorkspace" (sentido inverso).
        const lockData = data.lock
        if (lockData && typeof lockData === "object" && lockData.hideWorkspace === undefined) {
            if (typeof lockData.emptyWorkspace === "boolean")
                lockData.hideWorkspace = lockData.emptyWorkspace
            else if (typeof lockData.showWorkspace === "boolean")
                lockData.hideWorkspace = !lockData.showWorkspace
            // Grava já com o nome novo.
            rewrite = true
        }

        const unknown = {}
        for (const key of Object.keys(data)) {
            if (key !== "schemaVersion" && !(key in root.groups))
                unknown[key] = data[key]
        }
        root.unknownKeys = unknown

        root.applying = true
        for (const category of root.categories) {
            const stored = data[category.id] ?? ({})
            const group = root.groups[category.id]
            for (const setting of root.settingsOf(category.id)) {
                const value = stored[setting.key]
                // Chave ausente volta ao padrão.
                group[setting.key] = value === undefined
                    ? root.defaultOf(category.id, setting.key)
                    : root.coerce(setting, value, group[setting.key])
            }
        }
        // Valores lidos do arquivo podem violar as regras entre opções.
        root.lock.enforceRules()
        root.applying = false

        // Regrava se algo lido foi corrigido (tipo, limite ou regra).
        for (const category of root.categories) {
            const stored = data[category.id] ?? ({})
            for (const setting of root.settingsOf(category.id)) {
                if (stored[setting.key] !== root.groups[category.id][setting.key])
                    rewrite = true
            }
        }

        if (rewrite)
            saveTimer.restart()
    }

    function save(): void {
        const data = Object.assign({}, root.unknownKeys, { schemaVersion: root.schemaVersion })
        for (const category of root.categories) {
            const values = {}
            for (const setting of root.settingsOf(category.id))
                values[setting.key] = root.groups[category.id][setting.key]
            data[category.id] = values
        }
        file.setText(JSON.stringify(data, null, 2) + "\n")
    }

    FileView {
        id: file
        path: root.path
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false

        onLoaded: root.apply(file.text())
        onFileChanged: file.reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.apply("")
            else
                console.warn("Não foi possível ler preferences.json:", FileViewError.toString(error))
        }
        onSaveFailed: error => console.warn("Não foi possível gravar preferences.json:", FileViewError.toString(error))
    }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: root.save()
    }

    function scheduleSave(): void {
        if (!root.applying)
            saveTimer.restart()
    }

    Component.onCompleted: {
        const defaults = {}
        for (const category of root.categories) {
            const group = root.groups[category.id]
            defaults[category.id] = {}
            for (const setting of root.settingsOf(category.id)) {
                defaults[category.id][setting.key] = group[setting.key]
                group[setting.key + "Changed"].connect(root.scheduleSave)
            }
        }
        root.defaults = defaults
        // Com blockLoading, text() já devolve o conteúdo do disco.
        root.apply(file.text())
    }
}
