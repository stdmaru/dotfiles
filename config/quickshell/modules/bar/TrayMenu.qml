pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Controls
import qs.config

Rectangle {
    // Invisible window overlay to close if clicked outside
    id: root
    
    required property PanelWindow parentWindow
    property bool isOpen: false
    property real openX: 0
    property real openY: 0
    
    width: parentWindow.screen.width
    height: parentWindow.screen.height

    visible: false
    z: 1
    color: "transparent"

    Rectangle {
        // Actual menu window
        id: menuContainer
        property int minWidth: 150

        color: "#22222c"
        radius: 6
        z: 2
        border.color: "#444455"
        border.width: 1
        clip: true

        opacity: 0
        visible: false
        transformOrigin: Item.Top

        states: [
            State {
                name: "open"
                when: root.isOpen
                PropertyChanges {
                    target: menuContainer
                    opacity: 1
                    scale: 1
                }
            },
            State {
                name: "closed"
                when: !root.isOpen
                PropertyChanges {
                    target: menuContainer
                    opacity: 0
                    scale: 1
                }
            }
        ]

        transitions: [
            Transition {
                from: "closed"
                to: "open"

                ParallelAnimation {
                    NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            },

            Transition {
                from: "open"
                to: "closed"

                ParallelAnimation {
                    NumberAnimation { properties: "opacity"; from: 1; to: 0; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }

                onRunningChanged: {
                    if (!running && !root.isOpen) {
                        menuContainer.visible = false
                        root.visible = false
                        menuStack.clear()
                    }
                }
            }
        ]


        width: Math.max(menuStack.currentItem ? menuStack.currentItem.implicitWidth : 0, minWidth)
        height: menuStack.currentItem ? menuStack.currentItem.implicitHeight : 0

        // Centralizado no ponto de abertura, sem sair da tela.
        x: Math.max(8, Math.min(root.width - width - 8, root.openX - width / 2))
        y: root.openY

        Behavior on height {
            NumberAnimation {
                duration: Config.motion_spatial_ms
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Config.motion_spatial_curve
            }
        }

        // Close blocker
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            onClicked: {}
        }

        StackView {
            id: menuStack
            initialItem: null

            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: menuContainer.width; to: 0; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

            pushExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 0; to: -menuContainer.width; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: -menuContainer.width; to: 0; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "x"; from: 0; to: menuContainer.width; duration: Config.motion_spatial_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_spatial_curve }
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Config.motion_effect_ms; easing.type: Easing.BezierSpline; easing.bezierCurve: Config.motion_effect_curve }
                }
            }

        }

        component MenuView: Column {
            id: menuView
            property bool isSubmenu
            required property QsMenuHandle handle
            spacing: 5
            padding: 10

            QsMenuOpener {
                id: menuOpener
                menu: menuView.handle
            }

            // BOTÃO VOLTAR
            Rectangle {
                visible: menuView.isSubmenu
                implicitHeight: 25
                implicitWidth: implicitHeight * 2
                radius: implicitHeight
                color: "#444455"

                Text {
                    anchors.centerIn: parent
                    text: "\uf060"
                    font.family: Theme.font_awesome
                    font.pixelSize: 14
                    color: "white"
                }

                MouseArea {
                    acceptedButtons: Qt.RightButton | Qt.LeftButton
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: menuStack.pop()

                    onEntered: parent.color = '#303055'
                    onExited: parent.color = "#444455"
                }
            }

            Repeater {
                id: menuRepeater
                model: menuOpener.children
                delegate: Rectangle {
                    // MenuItem
                    id: item
                    required property QsMenuEntry modelData

                    property bool isEnabled: item.modelData?.enabled ?? false
                    property bool isSeparator: item.modelData?.isSeparator ?? false
                    property bool hasChildren: item.modelData?.hasChildren ?? false
                    property string icon: item.modelData?.icon ?? ""
                    property bool buttonType: item.modelData?.buttonType ?? false
                    property bool checked: item.modelData?.checkState ?? false

                    implicitWidth: 250
                    radius: 4
                    height: !isSeparator ? 25 : 1
                    color: "transparent"

                    Row {
                        padding: 5
                        spacing: 5
                        visible: !item.isSeparator
                        anchors.verticalCenter: parent.verticalCenter

                        // Checkboxes if applicable
                        Text {
                            visible: item.buttonType > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: (item.checked) ? "\uf14a" : "\uf0c8"
                            font.family: Theme.font_awesome
                            font.pixelSize: 14
                            color: "white"
                        }

                        // Icon if applicable
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            id: icon
                            visible: item.icon !== ""
                            source: item.icon
                            width: 16
                            height: 16
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            asynchronous: true
                        }

                        // Label if applicable
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            id: label
                            visible: !item.isSeparator
                            text: !item.isSeparator ? item.modelData.text : "------------------"
                            font.family: Theme.font_display
                            color: (item.isEnabled ? "white" : "#888888")
                        }
                    }

                    // Submenu Arrow  if applicable
                    Text {
                        visible: item.hasChildren
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 5
                        text: "\uf0da"
                        font.family: Theme.font_awesome
                        font.pixelSize: 8
                        color: "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !item.isSeparator
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        onClicked: (mouseEvent) => {
                            const entry = item.modelData;
                            if(!item.modelData.enabled) return;

                            if(item.hasChildren) {
                                // Open submenu
                                // Criado pelo StackView, que o destrói ao sair.
                                menuStack.push(menuComponent, {
                                    handle: entry,
                                    isSubmenu: true
                                });
                            } else {
                                item.modelData.triggered()
                                root.close()
                            }
                        }
                        onEntered: () => {
                            if(!item.isEnabled) return
                            item.color = "#444455"
                        }
                        onExited: () => {
                            item.color = "transparent"
                        }
                    }

                    // Separator if applicable
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: item.modelData?.isSeparator
                        height: 1
                        color: "#444455"
                    }
                }
            }
        }
    }

    Component {
        id: menuComponent
        MenuView {}
    }

    MouseArea {
        id: rootMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        enabled: root.isOpen

        onClicked: (mouseEvent) => {
            if(mouseEvent.button === Qt.RightButton && menuStack.depth > 1) {
                menuStack.pop()
            } else {
                root.close()
            }
        }
    }

    function open(defaultMenuHandle: QsMenuHandle, x: int, y: int) {
        root.openX = x
        root.openY = y
        root.visible = true
        root.isOpen = true

        menuStack.clear()
        menuStack.push(menuComponent, {
            handle: defaultMenuHandle,
            isSubmenu: false
        })
        menuContainer.visible = true
    }

    function close() {
        if (!root.isOpen) return
        root.isOpen = false
    }

}
