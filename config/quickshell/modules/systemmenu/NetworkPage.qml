pragma ComponentBehavior: Bound

import qs.config
import qs.controllers
import Quickshell
import QtQuick

// Página "Rede" do menu do sistema: conexão ativa e gerenciamento de Wi-Fi.
Column {
    id: page

    // Um campo de texto do painel recebeu foco (ex.: senha do Wi-Fi).
    signal inputFocused()

    spacing: 11

    Text {
        text: "Rede"
        color: Theme.text
        font.family: Theme.font_ui
        font.pixelSize: 17
        font.weight: Font.DemiBold
    }

    Rectangle {
        width: parent.width
        height: 60
        radius: Theme.radius_m
        color: Theme.base
        Row {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 10
            Text {
                text: Network.connectionKind === "Ethernet" ? "\udb80\ude00" : Network.connectionKind === "Wi-Fi" ? "\uf1eb" : "\udb80\ude02"
                color: Network.connectionKind === "" ? Theme.overlay0 : Theme.blue
                font.family: Theme.font_nerd
                font.pixelSize: 26
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 95
                spacing: 2
                Text {
                    text: Network.connectionKind || "Desconectado"
                    color: Theme.text
                    font.family: Theme.font_ui
                    font.pixelSize: 14
                }
                Text {
                    text: Network.activeConnection
                    color: Theme.subtext0
                    font.family: Theme.font_ui
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 58
        radius: Theme.radius_s
        color: Theme.base
        Row {
            id: wifiHeaderContent
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: wifiToggle.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
                text: "\uf1eb"
                color: Theme.blue
                font.family: Theme.font_nerd
                font.pixelSize: 26
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 36
                spacing: 1
                Text {
                    text: "Wi-Fi"
                    color: Theme.text
                    font.family: Theme.font_ui
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width
                    visible: Network.activeWifiSsid !== ""
                    text: Network.activeWifiSsid
                    color: Theme.subtext0
                    font.family: Theme.font_ui
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
        Rectangle {
            id: wifiToggle
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 24
            radius: 12
            opacity: Network.wifiDeviceAvailable ? 1.0 : 0.4

            color: Network.wifiDeviceAvailable
                ? (Network.wifiEnabled ? Theme.blue : Theme.surface1)
                : Theme.surface1
            Rectangle {
                x: Network.wifiDeviceAvailable && Network.wifiEnabled ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: Theme.text

                Behavior on x {
                    NumberAnimation { duration: 360; easing.type: Easing.OutCubic }
                }
            }
            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            MouseArea {
                anchors.fill: parent
                enabled: Network.wifiDeviceAvailable && !Network.connectingWifiSsid

                onClicked: Network.setWifiEnabled(!Network.wifiEnabled)
            }
        }
    }

    Text {
        text: "Redes disponíveis"
        color: Theme.subtext0
        font.family: Theme.font_ui
        font.pixelSize: 12
        visible: Network.wifiDeviceAvailable && Network.wifiEnabled
    }

    ListView {
        id: availableWifiList

        width: parent.width
        height: 210
        clip: true
        spacing: 4
        visible: Network.wifiDeviceAvailable && Network.wifiEnabled

        model: Network.availableWifi

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    properties: "scale"
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    properties: "opacity"
                    from: 0
                    to: 1
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }

        remove: Transition {
            ParallelAnimation {
                NumberAnimation {
                    properties: "scale"
                    to: 0
                    duration: 180
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    properties: "opacity"
                    to: 0
                    duration: 180
                    easing.type: Easing.InCubic
                }
            }
        }

        delegate: Rectangle {
            id: wifiNetworkDelegate

            required property string ssid
            required property int signal
            required property string security
            required property bool inUse

            readonly property bool expanded:
                Network.expandedWifiSsid === ssid

            readonly property var savedConnection:
                Network.savedWifiConnections.find(
                    connection => connection.ssid === ssid
                ) ?? null
            readonly property bool connectionStatusVisible:
                Network.wifiStatusSsid === ssid && Network.wifiStatusMessage !== ""
            readonly property bool connecting:
                Network.connectingWifiSsid !== ""
            readonly property string connectionActionLabel:
                Network.connectingWifiSsid === ssid
                    ? (Network.pendingWifiForget ? "Esquecendo"
                        : Network.pendingWifiDisconnect ? "Desconectando" : "Conectando")
                    : (inUse ? "Desconectar" : "Conectar")

            width: availableWifiList.width
            height: expanded ? (connectionStatusVisible ? 101 : 82) : 38
            scale: 1
            opacity: 1
            transformOrigin: Item.Center
            radius: Theme.radius_s
            color: networkHeaderMouse.pressed ? Theme.basePressed
                : networkHeaderMouse.containsMouse ? Theme.baseHover : Theme.base
            clip: true

            Behavior on color {
                ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            function connectWifi() {
                if (Network.connectingWifiSsid)
                    return

                const saved = wifiNetworkDelegate.savedConnection
                const password = saved === null ? wifiPasswordInput.text : ""
                if (saved === null && wifiNetworkDelegate.security !== "" && !password)
                    return

                Network.startWifiConnection(
                    wifiNetworkDelegate.ssid,
                    password,
                    saved?.uuid ?? ""
                )
            }

            function forgetWifi() {
                if (savedConnection === null)
                    return
                const active = wifiNetworkDelegate.inUse
                    || Network.activeWifiConnectionUuid === savedConnection.uuid
                    || Network.activeWifiSsid === wifiNetworkDelegate.ssid
                Network.startWifiForget(
                    wifiNetworkDelegate.ssid,
                    savedConnection.uuid,
                    active
                )
            }

            function toggleSavedWifi() {
                if (savedConnection === null)
                    return

                if (inUse) {
                    Network.startWifiDisconnection(
                        wifiNetworkDelegate.ssid,
                        savedConnection.uuid
                    )
                } else {
                    Network.startWifiConnection(
                        wifiNetworkDelegate.ssid,
                        "",
                        savedConnection.uuid
                    )
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            // Cabeçalho da rede
            Row {
                id: networkHeader

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 11
                anchors.rightMargin: 11

                height: 38
                spacing: 9

                Item {
                    width: 26
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: Network.wifiSignalGlyph(
                            wifiNetworkDelegate.security,
                            wifiNetworkDelegate.signal
                        )
                        color: wifiNetworkDelegate.inUse ? Theme.green : Theme.blue
                        font.family: Theme.font_nerd
                        font.pixelSize: 24
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 26 - 24 - 18
                    spacing: 1

                    Text {
                        width: parent.width
                        text: wifiNetworkDelegate.ssid
                        color: Theme.text
                        font.family: Theme.font_ui
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        text: wifiNetworkDelegate.security
                            ? `${wifiNetworkDelegate.security} · ${wifiNetworkDelegate.signal}%`
                            : `Aberta · ${wifiNetworkDelegate.signal}%`
                        color: Theme.overlay0
                        font.family: Theme.font_ui
                        font.pixelSize: 10
                        visible: false
                    }
                }

                Item {
                    width: 24
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: wifiNetworkDelegate.inUse ? "\uf00c" : wifiNetworkDelegate.expanded ? "\uf107" : "\uf105"
                        color: wifiNetworkDelegate.inUse ? Theme.green : Theme.overlay0
                        font.family: Theme.font_nerd
                        font.pixelSize: 24
                    }
                }
            }

            MouseArea {
                id: networkHeaderMouse
                anchors.fill: networkHeader
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (wifiNetworkDelegate.expanded) {
                        Network.expandedWifiSsid = ""
                        return
                    }

                    Network.expandedWifiSsid = wifiNetworkDelegate.ssid

                    if (
                        wifiNetworkDelegate.savedConnection === null
                        && wifiNetworkDelegate.security !== ""
                    ) {
                        Qt.callLater(() => {
                            wifiPasswordInput.forceActiveFocus(Qt.MouseFocusReason)
                        })
                    }
                }
            }

            // Área expansível
            Row {
                id: wifiActionsRow
                anchors.top: networkHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 11
                anchors.rightMargin: 11
                height: 38
                spacing: 7
                visible: wifiNetworkDelegate.expanded

                // Rede conhecida: esquecer
                Rectangle {
                    visible: wifiNetworkDelegate.savedConnection !== null
                    width: visible ? (parent.width - parent.spacing) / 2 : 0
                    height: 32
                    radius: Theme.radius_s
                    scale: forgetMouse.pressed ? 0.97
                        : forgetMouse.containsMouse ? 1.02 : 1
                    opacity: forgetMouse.enabled ? 1 : 0.45
                    color: forgetMouse.containsMouse ? Theme.surface1 : Theme.surface0

                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "\uf1f8"
                            color: Theme.red
                            font.family: Theme.font_nerd
                            font.pixelSize: 17
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: Network.connectingWifiSsid === wifiNetworkDelegate.ssid
                                && Network.pendingWifiForget ? "Esquecendo" : "Esquecer"
                            color: Theme.red
                            font.family: Theme.font_ui
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: forgetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Network.connectingWifiSsid
                        onClicked: wifiNetworkDelegate.forgetWifi()
                    }
                }

                // Rede conhecida: conectar ou desconectar
                Rectangle {
                    visible: wifiNetworkDelegate.savedConnection !== null
                    width: visible ? (parent.width - parent.spacing) / 2 : 0
                    height: 32
                    radius: Theme.radius_s
                    scale: connectionActionMouse.pressed ? 0.97
                        : connectionActionMouse.containsMouse ? 1.02 : 1
                    opacity: connectionActionMouse.enabled ? 1 : 0.45
                    color: connectionActionMouse.containsMouse ? Theme.surface1 : Theme.surface0

                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: wifiNetworkDelegate.inUse ? "\udb81\uddaa" : "\uf1eb"
                            color: Theme.green
                            font.family: Theme.font_nerd
                            font.pixelSize: 17
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: wifiNetworkDelegate.connectionActionLabel
                            color: Theme.green
                            font.family: Theme.font_ui
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: connectionActionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !Network.connectingWifiSsid
                        onClicked: wifiNetworkDelegate.toggleSavedWifi()
                    }
                }

                // Rede desconhecida: campo de senha
                Rectangle {
                    visible: wifiNetworkDelegate.savedConnection === null
                        && wifiNetworkDelegate.security !== ""

                    width: visible ? parent.width - connectWifiButton.width - parent.spacing : 0
                    height: 32
                    radius: Theme.radius_s
                    color: Theme.surface0

                    TextInput {
                        id: wifiPasswordInput

                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9

                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.font_ui
                        font.pixelSize: 12

                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        clip: true
                        enabled: !Network.connectingWifiSsid
                        opacity: enabled ? 1 : 0.55
                        property int passwordResetVersion: Network.wifiPasswordResetVersion
                        onPasswordResetVersionChanged: text = ""

                        onActiveFocusChanged: {
                            if (activeFocus)
                                page.inputFocused()
                        }

                        Text {
                            anchors.fill: parent
                            enabled: false
                            verticalAlignment: Text.AlignVCenter
                            visible: !wifiPasswordInput.text
                            text: "Digite a senha..."
                            color: Theme.overlay0
                            font: wifiPasswordInput.font
                        }

                        Keys.onReturnPressed: wifiNetworkDelegate.connectWifi()

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            cursorShape: Qt.IBeamCursor
                        }
                    }
                }

                // Conectar em rede desconhecida
                Rectangle {
                    id: connectWifiButton

                    visible: wifiNetworkDelegate.savedConnection === null
                    enabled: !Network.connectingWifiSsid
                    opacity: enabled ? 1 : 0.55
                    scale: connectMouse.pressed ? 0.96
                        : connectMouse.containsMouse ? 1.02 : 1
                    width: visible ? 88 : 0
                    height: 32
                    radius: Theme.radius_s
                    color: connectMouse.containsMouse ? Theme.lavender : Theme.blue

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: wifiNetworkDelegate.connectionActionLabel
                        color: Theme.crust
                        font.family: Theme.font_ui
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: connectMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: connectWifiButton.enabled
                        onClicked: wifiNetworkDelegate.connectWifi()
                    }
                }
            }

            Text {
                anchors.top: wifiActionsRow.bottom
                anchors.topMargin: 1
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.right: parent.right
                anchors.rightMargin: 11
                height: 16
                visible: wifiNetworkDelegate.expanded
                    && wifiNetworkDelegate.connectionStatusVisible
                text: Network.wifiStatusMessage
                color: Theme.red
                font.family: Theme.font_ui
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Text {
            anchors.centerIn: parent
            visible: Network.availableWifi.count === 0
            text: Network.wifiEnabled ? "Atualizando lista de redes disponíveis..." :
                "Wi-Fi desativado"
            color: Theme.overlay0
            font.family: Theme.font_ui
            font.pixelSize: 12
        }
    }

    ActionTile {
        width: parent.width
        height: 38
        glyph: "\uf021"
        label: "Atualizar redes"
        visible: Network.wifiDeviceAvailable && Network.wifiEnabled
        enabled: Network.availableWifi.count > 0
            && !Network.wifiPasswordInputExpanded()
            && !Network.connectingWifiSsid
            && Network.wifiDeviceAvailable
            && Network.wifiEnabled
            && !Network.scanPending
        onClicked: {
            if (Network.wifiPasswordInputExpanded() || Network.connectingWifiSsid
                    || Network.scanPending)
                return
            Network.refresh()
            Network.requestWifiScan()
        }
    }
}
