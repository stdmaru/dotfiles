pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Página "Som" do menu do sistema: volume geral, saídas e mixer por aplicativo.
Column {
    id: soundPageRoot

    // Aba selecionada: "outputs" ou "applications".
    property string tab: "outputs"

    spacing: 12
    readonly property var streamNodes: Audio.streams
    readonly property var appGroups: {
        const groups = Object.create(null)
        for (const node of streamNodes) {
            const props = node.properties ?? ({})
            const mediaClass = String(props["media.class"] || node.type || "")
            if (mediaClass.includes("Input/Audio") || mediaClass.includes("Audio/Source"))
                continue
            const name = String(props["application.name"]
                || props["application.process.binary"]
                || node.description
                || node.name
                || "Aplicativo")
            if (!groups[name])
                groups[name] = { name: name, nodes: [] }
            groups[name].nodes.push(node)
        }
        return Object.values(groups)
    }

    function appIconFor(group) {
        const firstNode = group.nodes[0]
        const props = firstNode?.properties ?? ({})
        const fallback = "application-x-executable"
        const explicitIcon = String(props["application.icon-name"]
            || props["application.icon"] || "").trim()

        if (explicitIcon) {
            if (explicitIcon.startsWith("/") || explicitIcon.startsWith("file://"))
                return explicitIcon
            return Quickshell.iconPath(explicitIcon, fallback)
        }

        const candidates = [
            props["application.id"],
            props["application.process.binary"],
            group.name
        ]
        for (const candidate of candidates) {
            const identity = String(candidate || "").trim()
            if (!identity)
                continue
            const entry = DesktopEntries.heuristicLookup(identity)
            if (entry?.icon)
                return Quickshell.iconPath(entry.icon, fallback)
        }

        return Utils.getAppIcon(group.name, fallback)
    }

    // Os volumes por aplicativo só precisam ser acompanhados com a página aberta.
    PwObjectTracker {
        objects: soundPageRoot.streamNodes
    }

    Text {
        text: "Som"
        color: Theme.text
        font.family: Theme.font_ui
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Row {
        width: parent.width
        spacing: 10
        Text {
            text: Audio.muted || Audio.volume <= 0 ? "\ueee8" : Audio.volume < 0.5 ? "\uf027" : "\uefcf"
            color: Theme.blue
            font.family: Theme.font_nerd
            font.weight: Font.Black
            font.pixelSize: 36
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: Audio.muted ? "Silenciado" : `${Math.round(Audio.volume * 100)}%`
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Item {
        id: volumeSliderArea
        width: parent.width
        height: 24
        property bool pressed: false

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 7
            radius: 4
            color: Theme.outline
            Rectangle {
                width: parent.width * Audio.volume
                height: parent.height
                radius: parent.radius
                color: Theme.blue
            }
        }
        Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * Audio.volume - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            radius: 8
            color: Theme.text
            border.color: Theme.blue
            border.width: 2
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -5
            onPressed: mouse => {
                volumeSliderArea.pressed = true
                Audio.setVolume((mouse.x - 5) / (width - 10))
            }
            onPositionChanged: mouse => {
                if (volumeSliderArea.pressed)
                    Audio.setVolume((mouse.x - 5) / (width - 10))
            }
            onReleased: volumeSliderArea.pressed = false
            onCanceled: volumeSliderArea.pressed = false
        }
    }

    Row {
        width: parent.width
        spacing: 8
        ActionTile {
            width: (parent.width - parent.spacing) / 2
            height: 38
            glyph: Audio.muted ? "\uefcf" : "\ueee8"
            label: Audio.muted ? "Ativar som" : "Silenciar"
            onClicked: Audio.toggleMute()
        }
        ActionTile {
            width: (parent.width - parent.spacing) / 2
            height: 38
            glyph: "\uf028"
            label: "Mixer"
            onClicked: Quickshell.execDetached(["pavucontrol"])
        }
    }

    Row {
        width: parent.width
        spacing: 6
        Repeater {
            model: [
                { id: "outputs", label: "Saídas", icon: "\uf028" },
                { id: "applications", label: "Aplicativos", icon: "\uf108" }
            ]
            delegate: Rectangle {
                required property var modelData
                width: (parent.width - parent.spacing) / 2
                height: 34
                radius: 10
                color: soundPageRoot.tab === modelData.id ? Theme.surface0 : Theme.base
                Row {
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        text: modelData.icon
                        color: soundPageRoot.tab === modelData.id ? Theme.blue : Theme.subtext0
                        font.family: Theme.font_nerd
                        font.pixelSize: 24
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.label
                        color: Theme.text
                        font.family: Theme.font_ui
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: soundPageRoot.tab = modelData.id
                }
            }
        }
    }

    Text {
        visible: soundPageRoot.tab === "outputs"
        text: "Saída de áudio"
        color: Theme.subtext0
        font.family: Theme.font_ui
        font.pixelSize: 12
    }

    Column {
        visible: soundPageRoot.tab === "outputs"
        width: parent.width
        height: Math.max(32, Audio.outputs.length * 49 - 5)
        spacing: 5
        Repeater {
            model: Audio.outputs
            delegate: Rectangle {
                required property var modelData
                width: parent.width
                height: 44
                radius: 10
                color: Theme.base

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.right: outputAction.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: "\udb81\udcc3"
                        color: Theme.blue
                        font.family: Theme.font_nerd
                        font.pixelSize: 19
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        width: parent.width - 27
                        text: modelData.description || modelData.nickname || modelData.name
                        color: Theme.text
                        font.family: Theme.font_ui
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    id: outputAction
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    radius: 9
                    color: Pipewire.defaultAudioSink === modelData ? Theme.blue : outputMouse.containsMouse ? Theme.surface0 : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: Pipewire.defaultAudioSink === modelData ? "\uf00c" : "\uf028"
                        color: Pipewire.defaultAudioSink === modelData ? Theme.crust : Theme.text
                        font.family: Theme.font_nerd
                        font.pixelSize: 24
                    }
                    MouseArea {
                        id: outputMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Audio.setDefaultOutput(modelData)
                    }
                    Behavior on color {
                        ColorAnimation{ duration: 360 }
                    }
                }
            }
        }
        Text {
            visible: Audio.outputs.length === 0
            text: "Nenhuma saída de áudio encontrada"
            color: Theme.overlay0
            font.family: Theme.font_ui
            font.pixelSize: 12
            height: visible ? 32 : 0
            verticalAlignment: Text.AlignVCenter
        }
    }

    Text {
        visible: soundPageRoot.tab === "applications"
        text: "Volume por aplicativo"
        color: Theme.subtext0
        font.family: Theme.font_ui
        font.pixelSize: 12
    }

    ListView {
        visible: soundPageRoot.tab === "applications"
        width: parent.width
        height: visible
            ? Math.min(250, Math.max(38, soundPageRoot.appGroups.length * 70))
            : 0
        clip: true
        spacing: 5
        model: soundPageRoot.appGroups
        delegate: Rectangle {
            id: appRow
            required property var modelData
            width: ListView.view.width
            height: 64
            radius: 10
            color: Theme.base
            property real appVolume: {
                const streams = modelData.nodes.filter(node => node.audio !== null)
                if (streams.length === 0)
                    return 0
                return streams.reduce((sum, node) => sum + node.audio.volume, 0) / streams.length
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.top: parent.top
                anchors.topMargin: 8
                height: 20
                spacing: 8

                Image {
                    width: 20
                    height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    source: soundPageRoot.appIconFor(appRow.modelData)
                    sourceSize: Qt.size(40, 40)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Text {
                    width: parent.width - 26
                    text: appRow.modelData.name
                    color: Theme.text
                    font.family: Theme.font_ui
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Item {
                id: appVolumeSlider
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.right: appVolumeLabel.left
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                height: 18
                property real value: Math.min(1.5, appRow.appVolume)
                property real previewValue: 0
                property bool pressed: false
                readonly property real shownValue: pressed ? previewValue : value

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.outline
                    Rectangle {
                        width: parent.width * appVolumeSlider.shownValue / 1.5
                        height: parent.height
                        radius: parent.radius
                        color: Theme.blue
                    }
                }
                Rectangle {
                    x: Math.max(0, Math.min(parent.width - width,
                        parent.width * appVolumeSlider.shownValue / 1.5 - width / 2))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 13
                    height: 13
                    radius: 7
                    color: Theme.text
                    border.color: Theme.blue
                    border.width: 2
                }
                MouseArea {
                    anchors.fill: parent
                    function setValueAt(x) {
                        const value = 1.5 * Math.max(0, Math.min(1, x / width))
                        appVolumeSlider.previewValue = value
                        for (const stream of appRow.modelData.nodes) {
                            if (stream.audio !== null)
                                stream.audio.volume = value
                        }
                    }
                    onPressed: mouse => {
                        appVolumeSlider.pressed = true
                        setValueAt(mouse.x)
                    }
                    onPositionChanged: mouse => {
                        if (appVolumeSlider.pressed)
                            setValueAt(mouse.x)
                    }
                    onReleased: appVolumeSlider.pressed = false
                    onCanceled: appVolumeSlider.pressed = false
                }
            }

            Text {
                id: appVolumeLabel
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 9
                width: 42
                horizontalAlignment: Text.AlignRight
                text: `${Math.round(appRow.appVolume * 100)}%`
                color: Theme.subtext0
                font.family: Theme.font_ui
                font.pixelSize: 11
            }
        }

        Text {
            anchors.centerIn: parent
            visible: soundPageRoot.appGroups.length === 0
            text: "Nenhum aplicativo reproduzindo áudio"
            color: Theme.overlay0
            font.family: Theme.font_ui
            font.pixelSize: 12
        }
    }
}
