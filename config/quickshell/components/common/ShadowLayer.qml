import qs.config
import QtQuick
import QtQuick.Effects

// Sombra projetada pelas superfícies do shell (Config.shadow_enabled). Os
// filhos são desenhados normalmente; com a sombra ligada, viram uma camada
// com MultiEffect, e a sombra sai do contorno da união de todos eles. Assim
// a moldura, a barra e os painéis que brotam dela projetam uma sombra só, sem
// emendas onde se encontram.
//
// Em janelas à parte (lançador, menu do sistema), `clipToWorkArea` recorta a
// sombra à área das janelas, para ela não cair sobre a barra e a moldura,
// que estão em outra janela.
Item {
    id: root

    default property alias surfaces: source.data
    property bool clipToWorkArea: false

    readonly property real workSide: clipToWorkArea && Config.frame_enabled ? Config.frame_thickness : 0
    readonly property real workTop: clipToWorkArea ? Config.bar_bottom : 0

    Item {
        id: viewport

        x: root.workSide
        y: root.workTop
        width: root.width - 2 * root.workSide
        height: root.height - root.workTop - root.workSide
        clip: root.clipToWorkArea && Config.shadow_enabled

        Item {
            id: source

            x: -viewport.x
            y: -viewport.y
            width: root.width
            height: root.height

            layer.enabled: Config.shadow_enabled
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: Config.shadow_opacity
                shadowBlur: 1
                blurMax: Config.shadow_size
                shadowVerticalOffset: Math.round(Config.shadow_size / 8)
            }
        }
    }
}
