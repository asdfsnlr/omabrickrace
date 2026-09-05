import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omabrickrace"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property real openPanelIndicatorWidth: button.implicitWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "omabrickrace"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.togglePanel() }
  }

  Component {
    id: carGlyph

    Item {
      anchors.fill: parent

      Grid {
        anchors.centerIn: parent
        columns: 3
        rows: 4
        spacing: 1

        // Proportional, compact icon size that matches standard bar icons (~11x15px)
        readonly property int blockSize: Math.max(2, Math.round(Style.bar.iconSlot * 0.105))

        Repeater {
          model: [
            0, 1, 0,
            1, 1, 1,
            0, 1, 0,
            1, 1, 1
          ]
          Rectangle {
            required property int modelData
            width: parent.blockSize
            height: parent.blockSize
            radius: Style.cornerRadius > 0 ? 0.5 : 0
            color: modelData === 1 ? button.foreground : "transparent"
          }
        }
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.opened
    iconComponent: carGlyph
    tooltipText: "Brick Race"
    onPressed: root.togglePanel()
  }
}
