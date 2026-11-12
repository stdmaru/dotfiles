pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import QtQuick

// Condição atual e previsão de cinco dias; abre a previsão no navegador.
Rectangle {
    id: root

    function forecastDayName(day, index: int): string {
        if (index === 0)
            return "Hoje"

        const parts = day.date.split("-").map(Number)
        const date = new Date(parts[0], parts[1] - 1, parts[2])
        return ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"][date.getDay()]
    }

    height: 146
    radius: Theme.radius_m
    color: weatherArea.pressed ? Theme.basePressed
        : weatherArea.containsMouse ? Theme.baseHover : Theme.base

    Behavior on color {
        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
    }

    MouseArea {
        id: weatherArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Weather.openInBrowser()
    }

    function capitalized(text: string): string {
        return text ? text.charAt(0).toUpperCase() + text.slice(1) : ""
    }

    function degrees(value: real): string {
        return `${Math.round(value)}°`
    }

    Item {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        z: 1

        // Cabeçalho: título e local.
        Item {
            id: header
            width: parent.width
            height: 16

            Text {
                id: weatherTitle
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Clima"
                font.family: Theme.font_display
                font.pixelSize: 13
                color: Theme.subtext0
            }

            Text {
                anchors.left: weatherTitle.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                font.family: Theme.font_ui
                font.pixelSize: 10
                color: Theme.overlay1
                text: Weather.hasData ? `${Weather.region}, ${Weather.state}` : ""
            }
        }

        // Condição atual: ícone, temperatura e descrição; máxima, mínima e
        // sensação à direita.
        Item {
            id: current
            anchors.top: header.bottom
            anchors.topMargin: 6
            width: parent.width
            height: 44

            Text {
                id: currentGlyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                // Caixa fixa; o tamanho do ícone vem só do pixelSize.
                width: 44
                height: 44
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.font_nerd
                font.pixelSize: 48
                color: Theme.sky
                text: Weather.hasData ? Weather.glyph : "\ue226"
            }

            Column {
                anchors.left: currentGlyph.right
                anchors.leftMargin: 8
                anchors.right: range.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    font.family: Theme.font_display
                    font.pixelSize: 24
                    color: Theme.text
                    text: Weather.hasData
                        ? `${Math.round(Weather.tempCurrent)}${Config.temperature_metric}`
                        : `--${Config.temperature_metric}`
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    font.family: Theme.font_ui
                    font.pixelSize: 11
                    color: Theme.subtext0
                    text: Weather.hasData ? root.capitalized(Weather.description) : "Carregando clima…"
                }
            }

            Column {
                id: range
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Weather.hasData
                spacing: 2

                Row {
                    anchors.right: parent.right
                    spacing: 8

                    Text {
                        font.family: Theme.font_ui
                        font.pixelSize: 11
                        color: Theme.text
                        text: `↑ ${root.degrees(Weather.tempMax)}`
                    }

                    Text {
                        font.family: Theme.font_ui
                        font.pixelSize: 11
                        color: Theme.overlay1
                        text: `↓ ${root.degrees(Weather.tempMin)}`
                    }
                }

                Text {
                    anchors.right: parent.right
                    font.family: Theme.font_ui
                    font.pixelSize: 10
                    color: Theme.overlay1
                    text: `Sensação ${root.degrees(Weather.tempFeelsLike)}`
                }
            }
        }

        // Previsão: cinco colunas iguais, dia, ícone e máxima/mínima.
        Row {
            id: forecastRow
            anchors.top: current.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width

            Repeater {
                model: Weather.forecast

                delegate: Column {
                    id: day
                    required property var modelData
                    required property int index

                    width: forecastRow.width / Math.max(1, Weather.forecast.length)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: Theme.font_ui
                        font.pixelSize: 10
                        color: day.index === 0 ? Theme.text : Theme.subtext0
                        text: root.forecastDayName(day.modelData, day.index)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: Theme.font_nerd
                        // Os ícones de clima ocupam pouco do quadro da
                        // fonte; a linha fica curta para não sobrar espaço.
                        height: 24
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 34
                        color: Theme.sky
                        text: day.modelData.glyph
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4

                        Text {
                            font.family: Theme.font_ui
                            font.pixelSize: 10
                            color: Theme.text
                            text: root.degrees(day.modelData.max)
                        }

                        Text {
                            font.family: Theme.font_ui
                            font.pixelSize: 10
                            color: Theme.overlay1
                            text: root.degrees(day.modelData.min)
                        }
                    }
                }
            }
        }
    }
}
