import QtQuick
import Quickshell
import Quickshell.Wayland

// One monitor's Alt+Tab panel. Pure view: all state lives in the Switcher
// controller (`switcher`), so mirrored panels on several monitors always show
// the same selection. Only the panel on the controller's keyboard monitor
// takes keyboard focus.
PanelWindow {
  id: root

  required property var switcher
  required property var modelData

  readonly property var sw: switcher
  readonly property var dock: switcher.dock
  readonly property var settings: switcher.settings
  readonly property var theme: switcher.theme
  readonly property bool shown: sw.opened && sw.screenNames.indexOf(modelData.name) !== -1
  readonly property bool hasKeyboard: shown && sw.keyboardScreenName === modelData.name

  screen: modelData
  visible: shown
  color: "transparent"
  WlrLayershell.namespace: "glassdock-switcher"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: hasKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  // Unanchored, so the compositor centres it; sized to the panel so Hyprland
  // only has to blur the area the glass actually covers.
  implicitWidth: Math.max(1, panel.width)
  implicitHeight: Math.max(1, panel.height)

  // ---- input ----------------------------------------------------------------------

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: event => {
      const alt = event.modifiers & Qt.AltModifier
      const back = event.modifiers & Qt.ShiftModifier
      switch (event.key) {
      case Qt.Key_Tab: sw.step(1); break
      case Qt.Key_Backtab: sw.step(-1); break
      case Qt.Key_Right: sw.step(1); break
      case Qt.Key_Left: sw.step(-1); break
      case Qt.Key_Down: sw.stepWindow(1); break
      case Qt.Key_Up: sw.stepWindow(-1); break
      case Qt.Key_QuoteLeft: sw.stepWindow(back ? -1 : 1); break
      case Qt.Key_AsciiTilde: sw.stepWindow(-1); break
      case Qt.Key_Return:
      case Qt.Key_Enter: sw.commit(); break
      case Qt.Key_Escape: sw.cancel(); break
      case Qt.Key_W:
      case Qt.Key_Q:
        if (alt && sw.selectedWindow) sw.dock.windows.closeWindow(sw.selectedWindow)
        break
      default: return
      }
      event.accepted = true
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
        sw.commit()
        event.accepted = true
      }
    }
  }

  // ---- panel ------------------------------------------------------------------------

  readonly property int cardWidth: settings.cfg.switcherCardWidth
  readonly property int maxPanelWidth: Math.round((screen ? screen.width : 1920) * 0.9)

  Item {
    id: panel
    width: Math.min(cards.contentWidth, root.maxPanelWidth - 32) + 32
    height: content.implicitHeight + 32
    opacity: sw.revealed ? 1 : 0
    scale: sw.revealed ? 1 : 0.96
    Behavior on opacity { enabled: root.theme.animate; NumberAnimation { duration: 120 } }
    Behavior on scale { enabled: root.theme.animate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    Surface {
      anchors.fill: parent
      theme: root.theme
      radius: root.theme.r(28)
      tint: root.theme.tintStrong
    }

    Column {
      id: content
      x: 16
      y: 16
      width: parent.width - 32
      spacing: 14

      ListView {
        id: cards
        width: parent.width
        height: root.cardWidth * 0.62 + 92
        orientation: ListView.Horizontal
        spacing: 12
        interactive: false
        clip: true
        model: sw.opened ? sw.apps : []
        currentIndex: sw.appIndex
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: SwitcherCard {
          required property var modelData
          required property int index
          dock: root.dock
          theme: root.theme
          appId: modelData.appId
          windows: modelData.windows
          width: root.cardWidth
          height: cards.height
          selected: index === sw.appIndex
          shownWindow: selected ? sw.selectedWindow : modelData.windows[0]
          onHovered: if (sw.hoverArmed) sw.select(index, 0)
          onClicked: {
            sw.select(index, 0)
            sw.commit()
          }
        }
      }

      // The selected app's window group, when it has more than one window.
      Column {
        visible: sw.selectedWindows.length > 1
        width: parent.width
        spacing: 8

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: (sw.windowIndex + 1) + " / " + sw.selectedWindows.length + "  ·  ↑ ↓ to switch window"
          color: root.theme.alpha(root.theme.text, 0.6)
          font.family: root.theme.fontFamily
          font.pixelSize: 11
        }

        ListView {
          id: strip
          readonly property int thumbWidth: 150
          anchors.horizontalCenter: parent.horizontalCenter
          width: Math.min(contentWidth, parent.width)
          height: thumbWidth * 0.62 + 40
          orientation: ListView.Horizontal
          spacing: 8
          interactive: false
          clip: true
          model: sw.opened ? sw.selectedWindows : []
          currentIndex: sw.windowIndex
          onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
          delegate: WindowThumb {
            required property var modelData
            required property int index
            theme: root.theme
            toplevel: modelData
            implicitWidth: strip.thumbWidth
            width: implicitWidth
            height: strip.height
            showClose: false
            selected: index === sw.windowIndex
            onActivated: {
              sw.windowIndex = index
              sw.commit()
            }
          }
        }
      }
    }
  }
}
