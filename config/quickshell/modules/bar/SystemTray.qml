pragma ComponentBehavior: Bound

import qs.controllers
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

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
            
            Image {
                anchors.fill: parent
                source: item.modelData.icon
                sourceSize: Qt.size(parent.width * 2, parent.height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                function openMenu(): void {
                    if (!item.modelData.hasMenu)
                        return
                    // A dica do ícone ficaria por cima do menu.
                    TooltipManager.hide(mouse)
                    const p = item.mapToItem(root.trayMenu, item.width / 2, item.height + 12)
                    root.trayMenu.open(item.modelData.menu, p.x, p.y)
                }

                onClicked: (mouseEvent) => {
                    if (mouseEvent.button === Qt.MiddleButton)
                        item.modelData.secondaryActivate()
                    else if (mouseEvent.button === Qt.RightButton || item.modelData.onlyMenu)
                        openMenu()
                    else
                        item.modelData.activate()
                }
                onEntered: {
                    const text = item.modelData.title !== ""
                        ? item.modelData.title
                        : item.modelData.tooltipTitle
                    if (text)
                        TooltipManager.show(mouse, text)
                }
                onExited: {
                    TooltipManager.hide(mouse)
                }
            }
        }
    }
}
