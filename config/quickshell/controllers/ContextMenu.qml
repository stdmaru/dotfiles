pragma Singleton

import Quickshell
import QtQuick

// Menu contextual único do shell. Qualquer componente abre o menu com
// show(tela, x, y, itens), com x/y em coordenadas da tela. Cada item é
// { text, icon?, danger?, enabled?, action } ou { separator: true }.
Singleton {
  id: root

  property bool open: false
  property ShellScreen screen: null
  property real x: 0
  property real y: 0
  property var items: []

  function show(targetScreen: ShellScreen, menuX: real, menuY: real, menuItems: var): void {
    root.screen = targetScreen
    root.x = menuX
    root.y = menuY
    root.items = menuItems ?? []
    root.open = root.items.length > 0
  }

  function close(): void {
    root.open = false
  }

  function trigger(index: int): void {
    const item = root.items[index]
    root.close()
    if (item && !item.separator && item.enabled !== false && typeof item.action === "function")
      Qt.callLater(item.action)
  }
}
