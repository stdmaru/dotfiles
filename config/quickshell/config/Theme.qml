pragma Singleton

import Quickshell
import QtQuick

// Paleta e tipografia compartilhadas por todo o shell. As cores vêm do tema
// escolhido em Preferences.appearance.theme (lista em Themes.qml).
//
// Na troca de tema, todas as cores são uma mistura entre a paleta de origem e
// a de destino, conduzida por `progress`; uma única animação faz o shell
// inteiro mudar de cor junto. Trocar de novo no meio da animação parte das
// cores que estão na tela.
Singleton {
    id: root

    // [{ id, name, dark, colors }]
    readonly property var themes: Themes.list
    readonly property var current: Themes.find(Preferences.appearance.theme)
    readonly property bool dark: current.dark
    readonly property int transitionMs: 450

    // Paletas convertidas ({ chave: { r, g, b, a } }). Nulas até o primeiro
    // tema ser aplicado, sem animação.
    property var fromPalette: null
    property var toPalette: null
    property real progress: 1

    function mix(key: string): color {
        const to = root.toPalette ?? Themes.palette(root.current)
        const b = to[key]
        const a = root.fromPalette?.[key] ?? b
        const t = root.progress
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
    }

    // Cor fixa de um tema (texto), para prévias que não devem animar.
    function colorOf(theme: var, key: string): string {
        return Themes.hex(theme, key)
    }

    function alpha(base: color, value: real): color {
        return Qt.rgba(base.r, base.g, base.b, value)
    }

    onCurrentChanged: {
        const target = Themes.palette(root.current)
        if (!root.toPalette) {
            root.fromPalette = target
            root.toPalette = target
            return
        }
        const snapshot = {}
        for (const key of Themes.keys) {
            const c = root.mix(key)
            snapshot[key] = { r: c.r, g: c.g, b: c.b, a: c.a }
        }
        transition.stop()
        root.fromPalette = snapshot
        root.toPalette = target
        root.progress = 0
        transition.start()
    }

    Component.onCompleted: {
        if (!root.toPalette) {
            root.fromPalette = Themes.palette(root.current)
            root.toPalette = root.fromPalette
        }
    }

    NumberAnimation {
        id: transition
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.transitionMs
        easing.type: Easing.InOutCubic
    }

    // Superfícies, da mais escura para a mais clara (no tema escuro)
    readonly property color crust: mix("crust")
    readonly property color mantle: mix("mantle")
    readonly property color base: mix("base")
    readonly property color surface0: mix("surface0")
    readonly property color surface1: mix("surface1")
    readonly property color surface2: mix("surface2")
    readonly property color outline: mix("outline")
    // Realce de hover/pressão sobre `base` e sobre `surface0`
    readonly property color baseHover: mix("baseHover")
    readonly property color basePressed: mix("basePressed")
    readonly property color surface0Hover: mix("surface0Hover")

    // Texto
    readonly property color overlay0: mix("overlay0")
    readonly property color overlay1: mix("overlay1")
    readonly property color subtext0: mix("subtext0")
    readonly property color text: mix("text")
    readonly property color textStrong: mix("textStrong")
    readonly property color barText: mix("barText")

    // Acentos
    readonly property color blue: mix("blue")
    readonly property color sapphire: mix("sapphire")
    readonly property color sky: mix("sky")
    readonly property color lavender: mix("lavender")
    readonly property color mauve: mix("mauve")
    readonly property color red: mix("red")
    readonly property color yellow: mix("yellow")
    readonly property color green: mix("green")

    // Véus atrás do lançador e dos diálogos
    readonly property color scrim: mix("scrim")
    readonly property color scrimStrong: mix("scrimStrong")

    // Texto direto sobre o papel de parede (relógio da tela de bloqueio):
    // igual em todos os temas.
    readonly property color wallpaperText: "#ffffff"
    readonly property color wallpaperSubtext: "#e6e9f5"

    // Raios de canto: controles, cartões e painéis
    readonly property int radius_s: 8
    readonly property int radius_m: 12
    readonly property int radius_l: 18

    // Fontes: `font_ui` para texto em geral, `font_display` para a barra e
    // títulos de cartões.
    readonly property string font_ui: "Cantarell"
    readonly property string font_display: "Cantarell Extra Bold"
    readonly property string font_nerd: "JetBrainsMono Nerd Font Mono"
    readonly property string font_awesome: "Font Awesome 7 Free"
}
