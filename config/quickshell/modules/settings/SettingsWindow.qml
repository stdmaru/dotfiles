pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell
import QtQuick

// Janela de configurações do shell. É uma janela comum (o Hyprland a deixa
// flutuante pela regra "quickshell-settings"): categorias à esquerda e, à
// direita, as seções da categoria escolhida. Tudo é gerado a partir de
// Preferences.categories e salvo na hora.
FloatingWindow {
    id: root

    readonly property var category: Preferences.categories.find(c => c.id === Settings.category)
        ?? Preferences.categories[0]

    title: "Configurações do shell"
    implicitWidth: 900
    implicitHeight: 620
    minimumSize: Qt.size(720, 460)
    color: Theme.base

    onClosed: Settings.close()

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Settings.close()

        // Categorias
        Rectangle {
            id: sidebar

            width: 236
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.mantle

            Column {
                anchors.fill: parent
                anchors.margins: 14
                anchors.topMargin: 20
                spacing: 4

                Row {
                    leftPadding: 8
                    bottomPadding: 16
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        color: Theme.blue
                        font.family: Theme.font_awesome
                        font.weight: Font.Black
                        font.pixelSize: 17
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Configurações"
                        color: Theme.text
                        font.family: Theme.font_display
                        font.pixelSize: 18
                    }
                }

                Repeater {
                    model: Preferences.categories

                    delegate: Rectangle {
                        id: entry

                        required property var modelData
                        readonly property bool current: modelData.id === root.category.id

                        width: parent.width
                        height: 40
                        radius: Theme.radius_s
                        color: current ? Theme.surface0
                            : entryMouse.containsMouse ? Theme.baseHover : "transparent"

                        Behavior on color { ColorAnimation { duration: Config.ui_color_ms } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: entry.current ? 18 : 0
                            radius: 2
                            color: Theme.blue

                            Behavior on height {
                                NumberAnimation { duration: Config.motion_fast_effect_ms; easing.type: Easing.OutCubic }
                            }
                        }

                        Text {
                            id: entryGlyph
                            x: 14
                            width: 20
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: entry.modelData.glyph
                            color: entry.current ? Theme.blue : Theme.overlay1
                            font.family: Theme.font_awesome
                            font.weight: Font.Black
                            font.pixelSize: 14
                        }

                        Text {
                            anchors.left: entryGlyph.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.label
                            color: entry.current ? Theme.text : Theme.subtext0
                            font.family: Theme.font_ui
                            font.pixelSize: 13
                            font.weight: entry.current ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Settings.category = entry.modelData.id
                        }
                    }
                }
            }

            // Atalho para editar o arquivo à mão.
            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 22
                text: "Abrir preferences.json"
                color: fileMouse.containsMouse ? Theme.blue : Theme.overlay1
                font.family: Theme.font_ui
                font.pixelSize: 12
                font.underline: fileMouse.containsMouse

                MouseArea {
                    id: fileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", Preferences.path])
                }
            }
        }

        // Conteúdo da categoria
        Flickable {
            id: content

            anchors.left: sidebar.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            contentHeight: page.implicitHeight + 64
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Troca de categoria volta ao topo.
            Connections {
                target: Settings
                function onCategoryChanged(): void { content.contentY = 0 }
            }

            Column {
                id: page

                x: 36
                y: 32
                width: Math.min(content.width - 72, 640)
                spacing: 22

                Column {
                    width: parent.width
                    spacing: 6

                    Text {
                        text: root.category.label
                        color: Theme.text
                        font.family: Theme.font_display
                        font.pixelSize: 24
                    }

                    Text {
                        width: parent.width
                        text: root.category.description
                        color: Theme.subtext0
                        font.family: Theme.font_ui
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }

                Repeater {
                    model: root.category.sections

                    delegate: Column {
                        id: section

                        required property var modelData

                        width: page.width
                        spacing: 8

                        Text {
                            leftPadding: 4
                            text: section.modelData.title
                            color: Theme.overlay1
                            font.family: Theme.font_ui
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.6
                        }

                        Rectangle {
                            width: parent.width
                            height: rows.implicitHeight
                            radius: Theme.radius_m
                            color: Theme.mantle
                            border.width: 1
                            border.color: Theme.outline

                            Column {
                                id: rows
                                width: parent.width

                                Repeater {
                                    model: section.modelData.settings

                                    delegate: Item {
                                        id: rowSlot

                                        required property var modelData
                                        required property int index

                                        width: rows.width
                                        height: settingRow.visible ? settingRow.implicitHeight : 0
                                        visible: settingRow.visible

                                        Rectangle {
                                            visible: rowSlot.index > 0
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: 16
                                            anchors.rightMargin: 16
                                            height: 1
                                            color: Theme.outline
                                        }

                                        SettingRow {
                                            id: settingRow
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: 18
                                            anchors.rightMargin: 16
                                            categoryId: root.category.id
                                            setting: rowSlot.modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Restaurar a categoria inteira
                Rectangle {
                    width: resetLabel.implicitWidth + 28
                    height: 34
                    radius: Theme.radius_s
                    color: resetMouse.containsMouse ? Theme.surface0 : "transparent"
                    border.width: 1
                    border.color: Theme.outline

                    Behavior on color { ColorAnimation { duration: Config.ui_color_ms } }

                    Text {
                        id: resetLabel
                        anchors.centerIn: parent
                        text: "Restaurar padrões desta categoria"
                        color: Theme.subtext0
                        font.family: Theme.font_ui
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: resetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Preferences.resetCategory(root.category.id)
                    }
                }
            }
        }
    }
}
