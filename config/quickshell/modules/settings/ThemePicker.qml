pragma ComponentBehavior: Bound

import qs.config
import QtQuick

// Cartões com uma miniatura de cada tema de Themes.qml. As miniaturas usam as
// cores fixas do tema (não as animadas do Theme), para cada uma mostrar o
// próprio tema durante a transição.
Flow {
    id: root

    property string value: ""

    signal selected(string value)

    spacing: 12

    Repeater {
        model: Theme.themes

        delegate: Item {
            id: card

            required property var modelData
            readonly property bool current: modelData.id === root.value
            readonly property bool hovered: cardMouse.containsMouse

            function c(key: string): string {
                return Theme.colorOf(card.modelData, key)
            }

            width: 176
            height: preview.height + nameRow.height + 10

            // Miniatura: área de trabalho com a barra, um painel e um popup.
            Rectangle {
                id: preview

                width: parent.width
                height: 104
                radius: Theme.radius_m
                color: card.c("base")
                border.width: card.current ? 2 : 1
                border.color: card.current ? Theme.blue
                    : card.hovered ? Theme.surface2 : Theme.outline
                scale: cardMouse.pressed ? 0.97 : 1

                Behavior on scale { NumberAnimation { duration: Config.ui_press_ms; easing.type: Easing.OutCubic } }

                Item {
                    anchors.fill: parent
                    anchors.margins: 7

                    // Barra
                    Rectangle {
                        id: miniBar
                        width: parent.width
                        height: 12
                        radius: 4
                        color: card.c("crust")

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    required property int index
                                    width: index === 0 ? 10 : 5
                                    height: 5
                                    radius: 2.5
                                    color: index === 0 ? card.c("blue") : card.c("surface1")
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 4
                            radius: 2
                            color: card.c("barText")
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    color: card.c("textStrong")
                                }
                            }
                        }
                    }

                    // Painel com uma lista
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: miniBar.bottom
                        anchors.topMargin: 6
                        anchors.bottom: parent.bottom
                        width: parent.width * 0.55
                        radius: 5
                        color: card.c("mantle")
                        border.width: 1
                        border.color: card.c("outline")

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 5

                            Rectangle { width: parent.width * 0.6; height: 5; radius: 2.5; color: card.c("text") }
                            Rectangle { width: parent.width * 0.9; height: 4; radius: 2; color: card.c("subtext0") }
                            Rectangle { width: parent.width * 0.75; height: 4; radius: 2; color: card.c("subtext0") }

                            Rectangle {
                                width: parent.width
                                height: 12
                                radius: 3
                                color: card.c("surface0")

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 7
                                    radius: 3.5
                                    color: card.c("blue")
                                }
                            }
                        }
                    }

                    // Popup de notificação com os acentos
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: miniBar.bottom
                        anchors.topMargin: 6
                        width: parent.width * 0.4
                        height: 40
                        radius: 5
                        color: card.c("mantle")
                        border.width: 1
                        border.color: card.c("outline")

                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 5

                            Rectangle { width: parent.width * 0.7; height: 4; radius: 2; color: card.c("text") }

                            Row {
                                spacing: 3
                                Repeater {
                                    model: ["red", "yellow", "green", "mauve"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 7
                                        height: 7
                                        radius: 3.5
                                        color: card.c(modelData)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Row {
                id: nameRow

                anchors.top: preview.bottom
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.modelData.dark ? "" : ""
                    color: card.current ? Theme.blue : Theme.overlay1
                    font.family: Theme.font_awesome
                    font.weight: Font.Black
                    font.pixelSize: 11
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.modelData.name
                    color: card.current ? Theme.text : Theme.subtext0
                    font.family: Theme.font_ui
                    font.pixelSize: 13
                    font.weight: card.current ? Font.DemiBold : Font.Normal
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!card.current)
                        root.selected(card.modelData.id)
                }
            }
        }
    }
}
