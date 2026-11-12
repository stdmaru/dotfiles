pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick

// Calendário mensal do painel de notificações.
Rectangle {
    id: root

    property var calendarMonth: firstOfMonth(new Date())
    property var selectedDate: new Date()
    property int slideDirection: -1
    property int monthOffset: 0
    readonly property var weekdays: ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
    readonly property var monthNames: ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
    readonly property real dayCellWidth: (calendarGrid.width - 6 * calendarGrid.spacing) / 7
    // Reavaliado a cada hora para que "hoje" acompanhe a virada do dia.
    readonly property string todayKey: clock.date.toDateString()
    readonly property var days: {
        const year = calendarMonth.getFullYear()
        const month = calendarMonth.getMonth()
        const firstWeekday = (new Date(year, month, 1).getDay() + 6) % 7

        return Array.from({ length: 42 }, (_, index) => {
            const date = new Date(year, month, index - firstWeekday + 1)
            return {
                day: date.getDate(),
                timestamp: date.getTime(),
                inMonth: date.getMonth() === month,
                isToday: date.toDateString() === root.todayKey,
                isSelected: date.toDateString() === selectedDate.toDateString()
            }
        })
    }

    function firstOfMonth(date): var {
        return new Date(date.getFullYear(), date.getMonth(), 1)
    }

    // Volta para o mês atual com o dia de hoje selecionado.
    function resetToToday(): void {
        calendarMonthAnimation.stop()
        calendarGrid.x = 0
        calendarMonthTitle.x = 0
        const today = new Date()
        calendarMonth = firstOfMonth(today)
        selectedDate = today
    }

    function changeMonth(offset: int): void {
        if (calendarMonthAnimation.running)
            return

        monthOffset = offset
        slideDirection = offset > 0 ? -1 : 1
        calendarMonthAnimation.start()
    }

    height: 245
    radius: 14
    color: Theme.base

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    SequentialAnimation {
        id: calendarMonthAnimation

        ParallelAnimation {
            NumberAnimation {
                target: calendarGrid
                property: "x"
                to: calendarGrid.width * root.slideDirection
                duration: 100
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: calendarMonthTitle
                property: "x"
                to: calendarMonthTitle.width * root.slideDirection
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        ScriptAction {
            script: {
                root.calendarMonth = new Date(
                    root.calendarMonth.getFullYear(),
                    root.calendarMonth.getMonth() + root.monthOffset,
                    1
                )
                root.selectedDate = new Date(root.calendarMonth)
                calendarGrid.x = -calendarGrid.width * root.slideDirection
                calendarMonthTitle.x = -calendarMonthTitle.width * root.slideDirection
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: calendarGrid
                property: "x"
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: calendarMonthTitle
                property: "x"
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 7

        Row {
            width: parent.width
            height: 28
            spacing: 8

            Item {
                id: calendarTitleViewport
                width: parent.width - 72
                height: parent.height
                clip: true

                Text {
                    id: calendarMonthTitle
                    width: parent.width
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.font_display
                    font.pixelSize: 15
                    color: Theme.text
                    text: `${root.monthNames[root.calendarMonth.getMonth()]} ${root.calendarMonth.getFullYear()}`
                }
            }

            Repeater {
                model: ["‹", "›"]

                delegate: Rectangle {
                    required property string modelData
                    width: 28
                    height: 28
                    radius: 14
                    color: navArea.pressed ? Theme.surface1
                        : navArea.containsMouse ? "#3b3d54" : Theme.surface0
                    scale: navArea.pressed ? 0.92 : navArea.containsMouse ? 1.06 : 1

                    Behavior on color {
                        ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: navArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        anchors.verticalCenterOffset: -2
                        font.pixelSize: 20
                        color: Theme.text
                    }

                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !calendarMonthAnimation.running
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.changeMonth(parent.modelData === "‹" ? -1 : 1)
                    }
                }
            }
        }

        Row {
            width: parent.width
            height: 18
            spacing: calendarGrid.spacing

            Repeater {
                model: root.weekdays

                Text {
                    required property string modelData
                    width: root.dayCellWidth
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: Theme.font_display
                    font.pixelSize: 10
                    color: Theme.overlay1
                    text: modelData
                }
            }
        }

        Item {
            id: calendarGridViewport
            width: parent.width
            height: calendarGrid.implicitHeight
            clip: true

            Grid {
                id: calendarGrid
                width: parent.width
                columns: 7
                spacing: 3

                Repeater {
                    model: root.days

                    delegate: Rectangle {
                        required property var modelData
                        width: root.dayCellWidth
                        height: 24
                        radius: 7
                        color: modelData.isSelected ? Theme.blue
                            : dayArea.pressed ? Theme.surface1
                            : dayArea.containsMouse ? "#31364d"
                            : modelData.isToday ? Theme.surface0
                            : "transparent"
                        scale: dayArea.pressed ? 0.92 : dayArea.containsMouse ? 1.06 : 1

                        Behavior on color {
                            ColorAnimation { duration: Config.ui_color_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: dayArea.pressed ? Config.ui_press_ms : Config.ui_hover_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_fast_effect_curve }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.day
                            font.family: Theme.font_display
                            font.pixelSize: 11
                            color: parent.modelData.isSelected ? Theme.crust
                                : parent.modelData.inMonth ? Theme.text : Theme.surface2
                        }

                        MouseArea {
                            id: dayArea
                            anchors.fill: parent
                            enabled: parent.modelData.inMonth && !calendarMonthAnimation.running
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.selectedDate = new Date(parent.modelData.timestamp)
                        }
                    }
                }
            }
        }
    }
}
