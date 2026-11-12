import qs.config
import QtQuick

// Raio de um canto da barra sob o qual um painel se encaixa. Vira 90° na hora
// em que o painel começa a abrir e, depois que ele termina de recolher, volta
// a se arredondar suavemente. Arredondar antes abriria um dente entre a curva
// da barra e o topo reto do painel. Use `value` como raio do canto.
Item {
    id: corner

    // Há um painel aberto ou ainda recolhendo embaixo do canto.
    property bool docked: false
    property real radius: 0
    // Espera antes de arredondar, para quem só sabe quando o painel começou
    // a fechar (não quando terminou).
    property int holdMs: 0
    property real value: radius

    onDockedChanged: {
        if (docked) {
            rounding.stop()
            value = 0
        } else {
            rounding.restart()
        }
    }
    onRadiusChanged: {
        if (!docked && !rounding.running)
            value = radius
    }

    SequentialAnimation {
        id: rounding

        PauseAnimation { duration: corner.holdMs }
        NumberAnimation {
            target: corner
            property: "value"
            to: corner.radius
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
}
