pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

PanelWindow {
    id: root

    required property ShellScreen targetScreen
    property bool closeOnOutsideClick: true
    readonly property bool isTargetScreen: targetScreen.name === Dialogs.targetScreenName
    property real progress: Dialogs.open ? 1 : 0

    screen: targetScreen
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    visible: (Dialogs.open || progress > 0) && isTargetScreen
    color: "transparent"
    focusable: Dialogs.open && isTargetScreen
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    Behavior on progress {
        NumberAnimation {
            duration: Dialogs.open ? 160 : 130
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: overlay
        anchors.fill: parent
        focus: Dialogs.open && root.isTargetScreen
        Keys.onEscapePressed: Dialogs.close()

        Rectangle {
            id: backdrop
            anchors.fill: parent
            color: "#aa080810"
            opacity: root.progress

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: {
                    if (root.closeOnOutsideClick && Dialogs.open)
                        Dialogs.close()
                }
            }
        }

        Rectangle {
            id: card
            width: Math.min(440, parent.width - 40)
            height: Math.min(parent.height - 40, cardContent.implicitHeight + 38)
            anchors.centerIn: parent
            radius: 18
            color: "#191923"
            border.width: 1
            border.color: "#343443"
            opacity: root.progress
            scale: 0.96 + root.progress * 0.04
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onClicked: mouse.accepted = true
            }

            Column {
                id: cardContent
                width: parent.width - 40
                anchors.centerIn: parent
                spacing: 16

                Row {
                    width: parent.width
                    spacing: 12

                    Item {
                        id: titleIconContainer
                        visible: Dialogs.icon.length > 0
                        width: visible ? 30 : 0
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            text: Dialogs.icon
                            color: Dialogs.iconColor
                            font.family: "JetBrainsMono Nerd Font Mono"
                            font.pixelSize: 26
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        width: parent.width - closeButton.width - parent.spacing
                            - (titleIconContainer.visible ? titleIconContainer.width + parent.spacing : 0)
                        text: Dialogs.title
                        color: "#e6e6f0"
                        font.family: Config.main_font
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Button {
                        id: closeButton
                        width: 30
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: "×"
                        onClicked: Dialogs.close()

                        contentItem: Text {
                            text: closeButton.text
                            color: "#a7a7bc"
                            font.pixelSize: 22
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 9
                            color: closeButton.down ? "#414155" : closeButton.hovered ? "#30303f" : "transparent"
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: Dialogs.message.length > 0
                    text: Dialogs.message
                    color: "#bfc0d0"
                    font.family: Config.main_font
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                }

                Column {
                    id: fieldsColumn
                    width: parent.width
                    spacing: 12
                    visible: Dialogs.mode === "input" && Dialogs.fields.length > 0

                    Repeater {
                        id: fieldsRepeater
                        model: Dialogs.fields

                        delegate: Column {
                            id: fieldDelegate
                            required property var modelData
                            required property int index
                            property alias inputField: field
                            width: fieldsColumn.width
                            spacing: 6

                            Text {
                                width: parent.width
                                visible: fieldDelegate.modelData.label.length > 0
                                text: fieldDelegate.modelData.label
                                color: "#bfc0d0"
                                font.family: Config.main_font
                                font.pixelSize: 12
                            }

                            TextField {
                                id: field
                                width: parent.width
                                height: 42
                                text: fieldDelegate.modelData.value
                                placeholderText: fieldDelegate.modelData.placeholder
                                echoMode: fieldDelegate.modelData.password ? TextInput.Password : TextInput.Normal
                                color: "#f4f4f8"
                                placeholderTextColor: "#77778b"
                                font.family: Config.main_font
                                font.pixelSize: 14
                                leftPadding: 12
                                rightPadding: 12
                                background: Rectangle {
                                    radius: 10
                                    color: "#11111b"
                                    border.width: field.activeFocus ? 2 : 1
                                    border.color: field.activeFocus ? "#89b4fa" : "#38384d"
                                }
                                onTextChanged: Dialogs.setInputValue(fieldDelegate.modelData.key, text)
                                onAccepted: root.submit()
                            }
                        }
                    }
                }

                Flow {
                    id: optionsFlow
                    width: parent.width
                    spacing: 8
                    flow: Flow.LeftToRight
                    layoutDirection: Qt.RightToLeft
                    height: childrenRect.height

                    Repeater {
                        model: Dialogs.options

                        delegate: Button {
                            required property var modelData
                            implicitWidth: Math.max(88, optionText.implicitWidth + 28)
                            height: 38
                            onClicked: Dialogs.choose(modelData)

                            contentItem: Text {
                                id: optionText
                                text: modelData.text
                                color: modelData.role === "primary" ? "#11111b" : "#e6e6f0"
                                font.family: Config.main_font
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 11
                                color: modelData.role === "primary"
                                    ? (parent.down ? "#74a8f5" : "#89b4fa")
                                    : (parent.down ? "#414155" : parent.hovered ? "#30303f" : "#252532")
                                border.width: modelData.role === "primary" ? 0 : 1
                                border.color: "#38384d"
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: Dialogs
        function onOpenChanged(): void {
            if (Dialogs.open && root.isTargetScreen && Dialogs.mode === "input")
                Qt.callLater(root.focusFirstInput)
        }
    }

    function focusFirstInput(): void {
        const firstField = fieldsRepeater.itemAt(0)
        if (firstField)
            firstField.inputField.forceActiveFocus()
    }

    function submit(): void {
        const primary = Dialogs.options.find(option => option.role === "primary")
        Dialogs.choose(primary ?? Dialogs.options[Dialogs.options.length - 1])
    }
}
