pragma Singleton

import Quickshell

Singleton {
    // General
    readonly property string temperature_metric: "°C"
    readonly property string main_font: "Cantarell Extra Bold"
    readonly property string gpu_type: "NVIDIA" // NVIDIA; GENERIC; NONE
    readonly property int topbar_height: 50
    readonly property int topbar_corner_radius: 7
    readonly property bool frame_enabled: false
    readonly property int frame_thickness: 5
    readonly property int frame_corner_radius: 7
    readonly property string frame_color: "#11111b"
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
    readonly property int notification_panel_corner_radius: 22
    readonly property int notification_panel_emergence: 30
    readonly property int notification_panel_left_weight: 2
    readonly property int notification_panel_right_weight: 1
    readonly property int notification_panel_inset: 15
    readonly property int notification_body_max_chars: 600
    // Lock-screen grouping: true = by app only, false = by notification source.
    readonly property bool notifications_lockscreen_full_privacy: true
    readonly property bool blur_on_lock: true
    readonly property bool empty_workspace_on_lock: true

    // Workspaces
    readonly property bool workspaces_showAll: true
    readonly property int workspaces_max: 7
    //readonly property var workspaces_labels: ({1: " 1 ", 2: " 2 ", 3: " 3 ", 4: " 4 ", 5: " 5 ", 6: " 6 ", 7: " 7 ", 8: " 8 ", 9: " 9 "}) // Default
    //readonly property var workspaces_labels: ({1: "\udb84\udc88", 2: "\udb84\udc89", 3: "\udb84\udc8a", 4: "\udb84\udc8b", 5: "\udb84\udc8c", 6: "\udb84\udc8d", 7: "\udb84\udc8e", 8: "\udb84\udc8f", 9: "\udb84\udc90"}) // Roman
    readonly property var workspaces_labels: ({1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "七", 8: "八", 9: "九"}) // Japanese

}
