pragma ComponentBehavior: Bound

import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls

// Uma configuração: rótulo e descrição à esquerda, controle à direita. O
// controle sai do tipo declarado no esquema de Preferences.
Item {
    id: row

    required property string categoryId
    // Entrada do esquema: { key, type, label, description, ... }. Ao trocar
    // de categoria, as linhas antigas chegam a ver a categoria nova antes de
    // sumir; por isso os controles toleram valor indefinido.
    required property var setting

    readonly property QtObject group: Preferences.groups[categoryId]
    readonly property var value: group[setting.key]
    readonly property bool isDefault: value === Preferences.defaultOf(categoryId, setting.key)

    function conditionHolds(condition: string): bool {
        if (!condition)
            return true
        const negated = condition.startsWith("!")
        const holds = Boolean(row.group[negated ? condition.slice(1) : condition])
        return negated ? !holds : holds
    }

    function commit(value: var): void {
        Preferences.set(row.categoryId, row.setting.key, value)
    }

    readonly property bool active: conditionHolds(setting.enabledWhen ?? "")

    visible: conditionHolds(setting.visibleWhen ?? "")
    implicitHeight: Math.max(56, texts.implicitHeight + 24)

    Column {
        id: texts
        anchors.left: parent.left
        anchors.right: controls.left
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        opacity: row.active ? 1 : 0.5

        Text {
            width: parent.width
            text: row.setting.label
            color: Theme.text
            font.family: Theme.font_ui
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: text !== ""
            text: row.setting.description ?? ""
            color: Theme.subtext0
            font.family: Theme.font_ui
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Volta ao padrão; só aparece quando o valor foi mudado.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: width / 2
            visible: !row.isDefault && row.active
            color: resetMouse.containsMouse ? Theme.surface0 : "transparent"

            Text {
                anchors.centerIn: parent
                text: ""
                color: resetMouse.containsMouse ? Theme.text : Theme.overlay1
                font.family: Theme.font_awesome
                font.weight: Font.Black
                font.pixelSize: 11
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Preferences.reset(row.categoryId, row.setting.key)
            }
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            enabled: row.active
            sourceComponent: row.setting.type === "bool" ? toggleControl
                : row.setting.type === "int" ? stepperControl
                : row.setting.type === "choice" ? choiceControl
                : textControl
        }
    }

    Component {
        id: toggleControl

        Toggle {
            checked: Boolean(row.value)
            onToggled: checked => row.commit(checked)
        }
    }

    Component {
        id: stepperControl

        Stepper {
            value: row.value ?? 0
            from: row.setting.min
            to: row.setting.max
            stepSize: row.setting.step ?? 1
            unit: row.setting.unit ?? ""
            onMoved: value => row.commit(value)
        }
    }

    Component {
        id: choiceControl

        Segmented {
            value: row.value ?? ""
            options: {
                if (row.setting.optionsFrom !== "screens")
                    return row.setting.options
                const options = Quickshell.screens.map(screen => ({
                    value: screen.name,
                    label: `${screen.name} · ${screen.width}×${screen.height}`
                }))
                // O monitor salvo pode estar desconectado agora.
                if (row.value && !options.some(option => option.value === row.value))
                    options.push({ value: row.value, label: `${row.value} · desconectado` })
                return options
            }
            onSelected: value => row.commit(value)
        }
    }

    Component {
        id: textControl

        TextField {
            id: field

            implicitWidth: 260
            implicitHeight: 34
            leftPadding: 10
            rightPadding: 10
            text: row.value ?? ""
            placeholderText: row.setting.placeholder ?? ""
            placeholderTextColor: Theme.overlay0
            color: Theme.text
            selectionColor: Theme.surface2
            selectedTextColor: Theme.white
            font.family: Theme.font_ui
            font.pixelSize: 13
            selectByMouse: true
            onTextEdited: row.commit(text)
            Keys.onEscapePressed: field.focus = false

            background: Rectangle {
                radius: Theme.radius_s
                color: Theme.surface0
                border.width: 1
                border.color: field.activeFocus ? Theme.blue : Theme.outline

                Behavior on border.color { ColorAnimation { duration: Config.ui_color_ms } }
            }
        }
    }
}
