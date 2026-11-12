pragma Singleton

import Quickshell
import QtQuick

// Paleta (Catppuccin Mocha) e tipografia compartilhadas por todo o shell.
Singleton {
    // Superfícies, da mais escura para a mais clara
    readonly property color crust: "#11111b"
    readonly property color mantle: "#181825"
    readonly property color base: "#1e1e2e"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color outline: "#38384d"

    // Texto
    readonly property color overlay0: "#6c7086"
    readonly property color overlay1: "#7f849c"
    readonly property color subtext0: "#a6adc8"
    readonly property color text: "#cdd6f4"
    readonly property color white: "#ffffff"
    readonly property color barText: "#b1b1b5"

    // Acentos
    readonly property color blue: "#89b4fa"
    readonly property color sapphire: "#74c7ec"
    readonly property color sky: "#89dceb"
    readonly property color lavender: "#b4befe"
    readonly property color mauve: "#cba6f7"
    readonly property color red: "#f38ba8"
    readonly property color yellow: "#f9e2af"
    readonly property color green: "#a6e3a1"

    // Fontes
    readonly property string font_ui: "Cantarell"
    readonly property string font_display: "Cantarell Extra Bold"
    readonly property string font_nerd: "JetBrainsMono Nerd Font Mono"
    readonly property string font_awesome: "Font Awesome 7 Free"
}
