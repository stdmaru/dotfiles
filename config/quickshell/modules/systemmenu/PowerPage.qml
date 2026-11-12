import qs.config
import QtQuick

// Página "Energia e sessão" do menu do sistema.
Column {
    id: page

    // "lock", "logout", "suspend", "reboot" ou "poweroff".
    signal actionRequested(string action)

    spacing: 8

    Text {
        text: "Energia e sessão"
        color: Theme.text
        font.family: Theme.font_ui
        font.pixelSize: 17
        font.weight: Font.DemiBold
        width: parent.width
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: 4

        Repeater {
            model: [
                { action: "lock", glyph: "", color: Theme.blue, label: "Bloquear sessão" },
                { action: "logout", glyph: "", color: Theme.blue, label: "Encerrar sessão" },
                { action: "suspend", glyph: "", color: Theme.yellow, label: "Suspender" },
                { action: "reboot", glyph: "", color: Theme.green, label: "Reiniciar…" },
                { action: "poweroff", glyph: "", color: Theme.red, label: "Desligar…" }
            ]

            delegate: ActionTile {
                required property var modelData
                width: parent.width
                height: 40
                glyph: modelData.glyph
                glyphColor: modelData.color
                label: modelData.label
                onClicked: page.actionRequested(modelData.action)
            }
        }
    }
}
