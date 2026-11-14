import qs.config
import qs.controllers
import QtQuick
import QtQuick.Controls

Button {
    id: root

    property int fontSize: 14
    property bool active: false
    property string tooltip

    // Left icon
    property string iconSource: ""
    property int iconSize: 18

    leftPadding: 10
    rightPadding: 10

    background: Rectangle {
        radius: Config.bar_button_radius
        color: (root.down || root.active) ? Theme.surface1 :
               root.hovered ? Theme.surface0 :
               "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.InOutQuad
            }
        }
    }

    contentItem: Row {
        spacing: 10

        Image {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconSource !== ""
            source: root.iconSource
            width: root.iconSize
            height: root.iconSize
            sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            asynchronous: true
        }
        
        // Default label shown when `text` property is used.
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            visible: root.text !== "" && root.text !== undefined
            font.family: Theme.font_display
            font.pixelSize: root.fontSize
            font.weight: Font.Bold
            color: root.active ? Theme.textStrong : Theme.barText
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    onHoveredChanged: {
        if (hovered && root.tooltip) {
            TooltipManager.show(root, root.tooltip);
        } else {
            TooltipManager.hide(root);
        }
    }
}
