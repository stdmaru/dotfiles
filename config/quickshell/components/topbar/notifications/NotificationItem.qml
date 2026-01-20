pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls

SwipeDelegate {
    id: root
    required property var modelData;
    required property string scene;
    
    property int implicitHeightCollapsed: 76

    property bool isDeleted: modelData.isDeleted
    property bool expand: false

    // Time display
    property string relativeTime
    property int currentInterval: 1000

    leftPadding: 0
    rightPadding: 0
    topPadding: 3
    bottomPadding: 3

    background: null

    implicitHeight: container.implicitHeight + topPadding + bottomPadding
    height: expand ? implicitHeight : implicitHeightCollapsed
    z: -1

    Timer {
        id: timer
        running: root.scene === "popup"
        interval: root.modelData.expireTimeout > 0 ? root.modelData.expireTimeout : 4_000
        onTriggered: {
            root.expand = false
            root.modelData.isPopup = false
            root.isDeleted = true
            root.height = 0
            root.opacity = 0
        }
    }

    Timer {
        id: relativeTimer
        repeat: true
        running: !root.isDeleted
        interval: root.currentInterval

        onTriggered: root.updateRelativeTime()
    }

    function updateRelativeTime() {
        const delta = Date.now() - modelData.createdAt

        // Atualiza texto
        root.relativeTime = Utils.formatRelativeTime(delta)

        // Decide próximo intervalo
        const next = nextUpdateInterval(delta)

        if (next < 0) {
            relativeTimer.stop()
        } else if (next !== root.currentInterval) {
            root.currentInterval = next
            relativeTimer.restart()
        }
    }

    function nextUpdateInterval(deltaMs) {
        const seconds = deltaMs / 1000
        if (seconds < 60)
            return 1000          // 1s

        if (seconds < 3600)
            return 60_000        // 1 min

        if (seconds < 86400)
            return 3_600_000     // 1 hora

        return -1                // não precisa mais atualizar
    }

    Component.onCompleted: updateRelativeTime()

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                if(root.scene === "popup") timer.stop()
                container.color = "#3c3d4c"
            } else {
                if(root.scene === "popup") timer.start()
                container.color = "#45475a"
            }
        }
        cursorShape: (root.pressed) ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        acceptedButtons: Qt.AllButtons
        
        onTapped: {
            if(root.isDeleted) return
            root.expand = !root.expand
        }
    }

    swipe.right: SwipeRectangle{}

    component SwipeRectangle: Rectangle {
        width: parent?.width ?? 0
        height: parent?.height ?? 0
        color: "transparent"
    }

    swipe.onCompleted: {
        if(root.scene === "popup") {
            root.modelData.isPopup = false
        }
        else if(root.scene === "tray") {
            root.modelData.isDeleted = true
        }

        root.isDeleted = true
        root.opacity = 0
        root.height = 0
    }

    Behavior on opacity {
        NumberAnimation{ duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
    }

    Behavior on height {
        enabled: root.isDeleted
        NumberAnimation{ duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
    }

    contentItem: Rectangle {
        id: container
        anchors.top: parent.top
        width: parent.width
        implicitHeight: innerContent.implicitHeight + 10
        color: "#45475a"
        radius: 10
        clip: true

        Rectangle {
            id: innerContent
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 5
            }
            width: parent.width - 10
            implicitHeight: Math.max(avatar.height + avatar.anchors.topMargin + avatar.anchors.bottomMargin, content.implicitHeight)
            color: "transparent"

            Rectangle {
                id: avatar
                color: "#11111b"
                width: 56
                height: width
                radius: width
                anchors.margins: 2
                anchors.top: parent.top
                anchors.left: parent.left
                //anchors.verticalCenter: parent.verticalCenter

                Image {
                    id: img
                    source: root.modelData.image
                    width: avatar.width
                    height: avatar.height
                    //fillMode: Image.PreserveAspectCrop
                    z: 1

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: avatar.width
                            height: avatar.height
                            radius: avatar.radius
                            color: "white"   // alpha = 1
                        }
                    }
                }

                Text {
                    font.family: "Font Awesome 7 Free"
                    font.pixelSize: 24
                    anchors.centerIn: parent
                    text: ""
                    color: "#b1b1b5"
                }
            }

            Rectangle {
                id: content
                radius: 5
                color: "transparent"
                anchors.leftMargin: 5
                anchors.left: avatar.right

                width: parent.width - avatar.width - 10
                implicitHeight: body.y + body.implicitHeight + 10
                
                TextMetrics {
                    id: titleText
                    text: root.modelData.summary
                }

                Text {
                    id: appName
                    anchors.top: content.top
                    opacity: root.expand ? 1 : 0

                    font.family: Config.main_font
                    text: root.modelData.appName
                    font.pointSize: 11
                    color: "#b1b1b5"
                    topPadding: 5
                    leftPadding: 5
                    maximumLineCount: 1

                    Behavior on opacity {
                        NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]}
                    }
                }

                Text {
                    id: title
                    anchors.top: content.top

                    font.family: Config.main_font
                    text: titleText.text
                    font.pointSize: 11

                    color: "#b1b1b5"
                    topPadding: 5
                    leftPadding: 5
                    maximumLineCount: 1

                    states: [
                        State{
                            name: "expanded"
                            when: root.expand
                            AnchorChanges {
                                target: title
                                anchors.top: appName.bottom
                            }
                        }
                    ]
                    
                    transitions: [
                        Transition{
                            AnchorAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1] }
                        }
                    ]
                }

                Text {
                    id: timeSeparator
                    anchors.top: content.top
                    anchors.left: title.right

                    font.family: Config.main_font
                    text: "•"
                    font.pointSize: 11

                    color: "#b1b1b5"
                    topPadding: 6
                    leftPadding: 5
                    maximumLineCount: 1

                    states: [
                        State {
                            name: "expanded"
                            when: root.expand
                            AnchorChanges {
                                target: timeSeparator
                                anchors.top: content.top
                                anchors.left: appName.right
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            AnchorAnimation {
                                duration: 400
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                            }
                        }
                    ]
                }

                Text {
                    id: time
                    anchors.top: content.top
                    anchors.left: timeSeparator.right

                    font.family: Config.main_font
                    text: root.relativeTime
                    font.pointSize: 10

                    color: "#b1b1b5"

                    topPadding: 6
                    leftPadding: 5
                    maximumLineCount: 1
                }

                Text {
                    id: expandBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: appName.verticalCenter
                    font.family: Config.main_font
                    text: (root.expand) ? "" : ""
                    font.pointSize: 10
                    color: "#b1b1b5"
                    rightPadding: 0
                    bottomPadding: 5
                    maximumLineCount: 1
                }
            
                TextMetrics {
                    id: bodyText
                    text: root.modelData.body
                    //text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
                    elide: Text.ElideRight
                    elideWidth: content.width - 50
                }

                Text {
                    id: body
                    anchors.top: title.bottom
                    font.family: Config.main_font
                    width: parent.width
                    text: bodyText.text
                    wrapMode: Text.WordWrap
                    font.pointSize: 10
                    color: "#b1b1b5"
                    leftPadding: 4
                    maximumLineCount: root.expand ? 999 : 1

                    states: [
                        State{
                            name: "expanded"
                            when: root.expand === true
                            PropertyChanges {
                                body.maximumLineCount: undefined
                                body.text: bodyText.text
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            PropertyAction {
                                target: body
                                property: "maximumLineCount"
                            }
                            AnchorAnimation {
                                duration: 400
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                            }
                        }
                    ]
                }

                Behavior on opacity {
                    NumberAnimation { duration: 400; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]}
                }
                
            }
            
        }
    }
}
