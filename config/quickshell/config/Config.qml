pragma Singleton

import Quickshell

// Opções do shell. As que o usuário ajusta pela janela de configurações vêm
// de Preferences (userdata/preferences.json); o resto é fixo aqui.
Singleton {
    // Monitores
    // A barra, as notificações e o cartão de login ficam no monitor principal.
    // Se ele não estiver conectado, o primeiro monitor disponível assume.
    readonly property string primary_screen: Preferences.behavior.primaryScreen
    // Workspaces vazias reservadas para o bloqueio de sessão, por monitor.
    // Precisam existir como regras persistentes no hyprland.lua.
    readonly property var lock_workspaces: ({ "DP-2": 99, "DP-1": 98 })
    // Workspace para onde cada monitor volta se, ao bloquear, ele já estiver
    // parado em uma workspace reservada (ex.: desbloqueio anterior incompleto).
    readonly property var home_workspaces: ({ "DP-2": 1, "DP-1": 10 })

    // General
    readonly property string terminal: Preferences.user.terminal || "alacritty"
    // Foca automaticamente janelas que pedem atenção (evento "urgent").
    readonly property bool focus_urgent_windows: Preferences.behavior.focusUrgentWindows
    readonly property string temperature_metric: "°C"
    // NVIDIA, GENERIC ou NONE; vazio detecta sozinho.
    readonly property string gpu_type: Preferences.bar.gpuType === "auto" ? "" : Preferences.bar.gpuType
    readonly property int topbar_height: Preferences.bar.height
    readonly property int topbar_corner_radius: Preferences.bar.cornerRadius
    // Espessura visível da barra (o fundo escuro). Flutuante, ela fica a
    // `bar_margin` das bordas da tela; no modo moldura, é a faixa superior
    // da moldura.
    readonly property int bar_thickness: topbar_height - 2 * bar_margin
    readonly property int bar_margin: 5
    // Distância do topo da tela até a borda inferior da barra, de onde os
    // painéis brotam.
    readonly property int bar_bottom: frame_enabled ? bar_thickness : bar_margin + bar_thickness
    // Modo moldura: a barra vira a faixa de cima de uma moldura em volta da
    // tela, e as janelas ficam no recorte arredondado do meio.
    readonly property bool frame_enabled: Preferences.bar.frameEnabled
    readonly property int frame_thickness: Preferences.bar.frameThickness
    readonly property int frame_corner_radius: Preferences.bar.frameCornerRadius
    readonly property int app_launcher_top_gap: 5
    readonly property int app_launcher_item_transition_ms: 180

    // Notification motion timings (ms)
    // Caelestia-inspired motion tokens: spatial changes ease out with a
    // restrained overshoot; opacity and color use a gentler effects curve.
    readonly property int motion_spatial_ms: 500
    readonly property int motion_fast_spatial_ms: 350
    readonly property int motion_effect_ms: 200
    readonly property int motion_fast_effect_ms: 150
    readonly property var motion_spatial_curve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var motion_fast_spatial_curve: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var motion_effect_curve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var motion_fast_effect_curve: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property int notification_expand_ms: motion_spatial_ms
    readonly property int notification_fade_ms: motion_effect_ms
    readonly property int notification_slide_ms: motion_fast_spatial_ms
    readonly property int notification_panel_ms: motion_spatial_ms
    readonly property int ui_hover_ms: motion_effect_ms
    readonly property int ui_press_ms: motion_fast_effect_ms
    readonly property int ui_color_ms: motion_effect_ms
    readonly property int notification_panel_max_width: 750
    readonly property int notification_panel_height: 590
    readonly property int notification_panel_corner_radius: 18
    readonly property int notification_panel_emergence: 30
    readonly property int notification_panel_left_weight: 2
    readonly property int notification_panel_right_weight: 1
    readonly property int notification_panel_inset: 15
    readonly property int notification_body_max_chars: 600

    // Workspaces
    readonly property bool workspaces_showAll: Preferences.bar.workspacesShowAll
    readonly property int workspaces_max: Preferences.bar.workspacesMax
    readonly property var workspaces_label_sets: ({
        numbers: ({}),
        roman: ({1: "\udb84\udc88", 2: "\udb84\udc89", 3: "\udb84\udc8a", 4: "\udb84\udc8b", 5: "\udb84\udc8c", 6: "\udb84\udc8d", 7: "\udb84\udc8e", 8: "\udb84\udc8f", 9: "\udb84\udc90"}),
        japanese: ({1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "七", 8: "八", 9: "九"})
    })
    readonly property var workspaces_labels: workspaces_label_sets[Preferences.bar.workspaceLabels] ?? ({})
}
