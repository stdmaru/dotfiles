pragma ComponentBehavior: Bound

import qs.components.common
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Row {
    id: root

    required property PanelWindow parentWindow
    required property TrayMenu trayMenu

    anchors.verticalCenter: parent.verticalCenter
    spacing: 5
    leftPadding: 5
    rightPadding: 5

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: item
            width: 18
            height: 18
            required property SystemTrayItem modelData
            
            IconImage {
                source: item.modelData.icon
                implicitSize: parent.height
            }

            Tooltip {
                id: tooltip
                text: {
                    if(item.modelData.title !== "")
                        return item.modelData.title
                    else if(item.modelData.tooltipTitle !== "")
                        return item.modelData.tooltipTitle
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouseEvent) => {
                    if (mouseEvent.button === Qt.LeftButton) {
                        item.modelData.activate()
                    } else {
                        if (!item.modelData?.hasMenu) return;
                        const centerX = root.width / 2
                        const p = root.mapToItem(root.trayMenu, centerX, root.height)
                        root.trayMenu.open(item.modelData?.menu, p.x, p.y)
                    }
                }
                onEntered: {
                    if (tooltip.text && tooltip.text !== "")
                        tooltip.showFor(root);
                }
                onExited: {
                    tooltip.hide();
                }
            }
        }
    }
}