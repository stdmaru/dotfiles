pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Saída de áudio padrão via PipeWire. Volume e mudo são reativos: mudanças
// feitas por teclas de mídia ou outros programas aparecem imediatamente.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool available: !!root.sink?.audio
    readonly property real volume: root.sink?.audio?.volume ?? 0
    readonly property bool muted: root.sink?.audio?.muted ?? false

    readonly property var outputs: Pipewire.nodes.values.filter(node =>
        node.isSink && !node.isStream && node.audio !== null)
    readonly property var streams: Pipewire.nodes.values.filter(node =>
        node.isStream && node.audio !== null)

    // Um nó só expõe (e aceita) volume enquanto estiver sendo acompanhado.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function setVolume(value: real): void {
        if (!root.available)
            return

        const volume = Math.max(0, Math.min(1, value))
        root.sink.audio.volume = volume
        // Mexer no controle deslizante desfaz o mudo, como em qualquer mixer.
        if (root.sink.audio.muted && volume > 0)
            root.sink.audio.muted = false
    }

    function toggleMute(): void {
        if (root.available)
            root.sink.audio.muted = !root.sink.audio.muted
    }

    function setDefaultOutput(node: PwNode): void {
        Pipewire.preferredDefaultAudioSink = node
    }
}
