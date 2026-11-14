import qs.components.common
import qs.config
import qs.controllers
import QtQuick
import Quickshell

Row {
    id: root
    property var memUsed: System.formatKib(System.memUsed)
    property var cpuUsage: System.cpuPerc
    property var cpuTemp: System.cpuTemp
    property var gpuTemp: System.gpuTemp

    Button {
        id: btn
        height: root.parent.height
        contentItem: Row {
            spacing: 10

            // CPU USAGE
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Label {
                    font.family: Theme.font_awesome
                    font.pixelSize: 16
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: "\uf2db"
                }

                Label {
                    font.pixelSize: btn.fontSize
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: `${Number(root.cpuUsage * 100).toFixed(0)}%`
                }
            }

            // CPU TEMP
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Label {
                    font.family: Theme.font_awesome
                    font.pixelSize: 16
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: "\uf2c9"
                }

                Label {
                    font.pixelSize: btn.fontSize
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: `${Number(root.cpuTemp).toFixed(0)}${Config.temperature_metric}`
                }
            }

            // RAM USAGE
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Label {
                    font.family: Theme.font_awesome
                    font.pixelSize: 16
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: "\uf538"
                }

                Label {
                    font.family: Theme.font_display
                    font.pixelSize: btn.fontSize
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: `${root.memUsed.value.toFixed(1)} ${root.memUsed.unit}`
                }
            }

            // GPU TEMP
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Label {
                    font.family: Theme.font_awesome
                    font.pixelSize: 16
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: "\uf2c9"
                }

                Label {
                    font.pixelSize: btn.fontSize
                    color: btn.active ? Theme.textStrong : Theme.barText
                    text: `${Number(root.gpuTemp).toFixed(0)}${Config.temperature_metric}`
                }
            }
        }

        onClicked: () => {
            Quickshell.execDetached([Config.terminal, "-e", "btop"])
        }
    }
}