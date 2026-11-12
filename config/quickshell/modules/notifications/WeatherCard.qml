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

    height: 141
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

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4
        z: 1

        // Header, current conditions and forecast follow
        // one vertical rhythm and fit inside this card.
        Row {
            id: header
            width: parent.width
            height: 15
            spacing: 6

            Text {
                id: weatherTitle
                text: "Clima"
                font.family: Theme.font_display
                font.pixelSize: 13
                color: Theme.subtext0
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                width: parent.width - weatherTitle.implicitWidth - parent.spacing
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                font.family: Theme.font_ui
                font.pixelSize: 10
                color: Theme.overlay1
                text: Weather.hasData ? `${Weather.region}, ${Weather.state}` : ""
            }
        }

        Row {
            id: currentConditions
            width: parent.width
            height: 38
            spacing: 8
            topPadding: 8
            
            Text {
                id: temperatureNow
                width: 40
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.font_nerd
                font.pixelSize: 42
                color: Theme.sky

                text: Weather.hasData ? Weather.glyph : "\ue226"
            }

            Column {
                width: parent.width - temperatureNow.width - currentConditions.spacing
                height: parent.height
                spacing: 1

                Text {
                    width: parent.width
                    height: 21
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.font_display
                    font.pixelSize: 20
                    color: Theme.text

                    text: Weather.hasData
                        ? `${Weather.tempCurrent}${Config.temperature_metric}`
                        : "--°C"
                }

                Text {
                    width: parent.width
                    height: 16
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    font.family: Theme.font_ui
                    font.pixelSize: 11
                    color: Theme.subtext0

                    text: Weather.hasData
                        ? `${Weather.description} · sensação ${Weather.tempFeelsLike}${Config.temperature_metric}`
                        : "Carregando clima…"
                }
            }
        }

        Row {
            id: weatherForecast
            width: parent.width
            height: 54
            spacing: 4
            topPadding: 20
            Repeater {
                model: Weather.forecast

                delegate: Column {
                    required property var modelData
                    required property int index
                    width: (parent.width - 4 * 4) / 5
                    spacing: 0

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        height: 2
                        font.family: Theme.font_ui
                        font.pixelSize: 9
                        color: Theme.subtext0
                        text: root.forecastDayName(parent.modelData, parent.index)
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.font_nerd
                        height: 32
                        font.pixelSize: 32
                        color: Theme.sky
                        text: parent.modelData.glyph
                    }

                    Row {
                        width: parent.width
                        height: 2

                        Text {
                            width: parent.width / 2
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.font_ui
                            font.pixelSize: 9
                            color: Theme.text
                            text: `${parent.parent.modelData.max}°`
                        }

                        Text {
                            width: parent.width / 2
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: Theme.font_ui
                            font.pixelSize: 9
                            color: Theme.overlay1
                            text: `${parent.parent.modelData.min}°`
                        }
                    }
                }
            }
        }
    }
}
