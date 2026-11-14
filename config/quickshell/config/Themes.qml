pragma Singleton

import Quickshell
import QtQuick

// Temas de cores do shell (singleton QML: uma biblioteca .js ficaria em cache
// e não recarregaria ao editar). Para criar um tema novo, acrescente um objeto à
// lista: `id` é o que fica salvo em preferences.json, `name` aparece na
// janela de configurações e `dark` diz se o fundo é escuro. Cores ausentes
// herdam do primeiro tema da lista. Formatos aceitos: "#rrggbb" e
// "#aarrggbb".
//
// Papéis das cores:
//   crust → base → surface0..2   superfícies, da barra ao controle em destaque
//   outline                      bordas finas de cartões e campos
//   baseHover, basePressed,
//   surface0Hover                realce de hover/pressão sobre base e surface0
//   overlay0..1, subtext0, text  texto, do mais apagado ao normal
//   textStrong                   texto de maior ênfase (botão ativo da barra)
//   barText                      texto dos botões da barra em repouso
//   blue … green                 acentos (o texto sobre eles usa `crust`)
//   scrim, scrimStrong           véu atrás do lançador e dos diálogos
Singleton {
    id: root

    readonly property var list: [
        {
            id: "mocha",
            name: "Catppuccin Mocha",
            dark: true,
            colors: {
                crust: "#11111b",
                mantle: "#181825",
                base: "#1e1e2e",
                surface0: "#313244",
                surface1: "#45475a",
                surface2: "#585b70",
                outline: "#38384d",
                baseHover: "#25263a",
                basePressed: "#292b40",
                surface0Hover: "#3b3d54",

                overlay0: "#6c7086",
                overlay1: "#7f849c",
                subtext0: "#a6adc8",
                text: "#cdd6f4",
                textStrong: "#ffffff",
                barText: "#b1b1b5",

                blue: "#89b4fa",
                sapphire: "#74c7ec",
                sky: "#89dceb",
                lavender: "#b4befe",
                mauve: "#cba6f7",
                red: "#f38ba8",
                yellow: "#f9e2af",
                green: "#a6e3a1",

                scrim: "#72090a12",
                scrimStrong: "#aa080810"
            }
        },
        {
            // Escuro Material 3 em tons de violeta: superfícies quase pretas
            // levemente arroxeadas e acentos lavanda.
            id: "amethyst",
            name: "Ametista",
            dark: true,
            colors: {
                crust: "#121116",
                mantle: "#19181d",
                base: "#1e1d22",
                surface0: "#2a282e",
                surface1: "#36343b",
                surface2: "#45404d",
                outline: "#2c2934",
                baseHover: "#242328",
                basePressed: "#29272d",
                surface0Hover: "#322f37",

                overlay0: "#6f6b76",
                overlay1: "#8a8690",
                subtext0: "#b4b0b9",
                text: "#e6e1e9",
                textStrong: "#f6f1f9",
                barText: "#c4c0c9",

                blue: "#c7b6f5",
                sapphire: "#b3a4e3",
                sky: "#b5c4ff",
                lavender: "#e1d6ff",
                mauve: "#eab4cb",
                red: "#ffb4ab",
                yellow: "#e8c48b",
                green: "#a8d5a2",

                scrim: "#80000000",
                scrimStrong: "#b0000000"
            }
        },
        {
            // Claro Material 3 em tons de creme rosado: superfícies quase
            // brancas e quentes, cartões rosados, texto marrom e acento
            // ferrugem.
            id: "petal",
            name: "Pétala",
            dark: false,
            colors: {
                crust: "#fcf5f3",
                mantle: "#f8e6e3",
                base: "#faefec",
                surface0: "#f1dcd8",
                surface1: "#e7cfcb",
                surface2: "#d8bfbb",
                outline: "#eddcd9",
                baseHover: "#f5e3df",
                basePressed: "#f0dad6",
                surface0Hover: "#ead3cf",

                overlay0: "#a08b89",
                overlay1: "#857371",
                subtext0: "#665452",
                text: "#3a2a28",
                textStrong: "#231918",
                barText: "#5a4644",

                blue: "#8a4640",
                sapphire: "#9c5a52",
                sky: "#775653",
                lavender: "#a3615a",
                mauve: "#7a6a3a",
                red: "#ba1a1a",
                yellow: "#8b6b1f",
                green: "#4f6f3e",

                scrim: "#40231918",
                scrimStrong: "#70231918"
            }
        }
    ]

    readonly property string defaultId: list[0].id
    readonly property var keys: Object.keys(list[0].colors)

    function find(id: string): var {
        return root.list.find(theme => theme.id === id) ?? root.list[0]
    }

    function exists(id: string): bool {
        return root.list.some(theme => theme.id === id)
    }

    // "#rrggbb" / "#aarrggbb" → { r, g, b, a } em 0..1.
    function parseHex(hex: string): var {
        let digits = String(hex).replace("#", "")
        let alpha = 255
        if (digits.length === 8) {
            alpha = parseInt(digits.slice(0, 2), 16)
            digits = digits.slice(2)
        }
        return {
            r: parseInt(digits.slice(0, 2), 16) / 255,
            g: parseInt(digits.slice(2, 4), 16) / 255,
            b: parseInt(digits.slice(4, 6), 16) / 255,
            a: alpha / 255
        }
    }

    // Cor do tema em texto; as ausentes vêm do primeiro tema.
    function hex(theme: var, key: string): string {
        return theme.colors[key] || root.list[0].colors[key]
    }

    // Paleta completa do tema, já convertida.
    function palette(theme: var): var {
        const result = {}
        for (const key of root.keys)
            result[key] = root.parseHex(root.hex(theme, key))
        return result
    }
}
