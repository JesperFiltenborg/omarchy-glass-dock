import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// Alt+Tab: a glass overlay of the dock's app groups in most-recently-used
// order, each with a live preview. Tab moves between apps, ` moves between the
// selected app's windows, releasing Alt switches.
//
// Driven over IPC by hypr/glassdock.lua (next/prev/nextWindow/prevWindow/commit).
// The overlay also takes keyboard focus, so arrows, Enter, Esc and the Alt
// release work even if the Hyprland release bind is missing.
PanelWindow {
  id: root

  required property var dock

  readonly property var settings: dock.settings
  readonly property var theme: dock.theme

  property bool opened: false
  property bool revealed: false   // UI shown; quick taps commit before this flips
  property var apps: []           // snapshot of dock.windows.switcherApps at open
  property int appIndex: 0
  property int windowIndex: 0
  property double lastEarlyCommit: 0
  property double lastClosed: 0
  property bool hoverArmed: false  // ignore the pointer until it moves after opening

  readonly property var selectedApp: apps[appIndex] || null
  readonly property var selectedWindows: selectedApp ? selectedApp.windows.filter(w => w && w.address) : []
  readonly property var selectedWindow: selectedWindows[windowIndex] || selectedWindows[0] || null

  visible: opened
  screen: {
    const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
  }
  color: "transparent"
  WlrLayershell.namespace: "glassdock-switcher"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  // Unanchored, so the compositor centres it; sized to the panel so Hyprland
  // only has to blur the area the glass actually covers.
  implicitWidth: Math.max(1, panel.width)
  implicitHeight: Math.max(1, panel.height)

  // ---- state machine ----------------------------------------------------------

  function begin(appStep, windowStep) {
    const list = dock.windows.switcherApps
    if (!list.length) return
    apps = list
    // The first entry is the focused app, so Alt+Tab lands on the one before it.
    appIndex = appStep && list.length > 1 ? (appStep > 0 ? 1 : list.length - 1) : 0
    const count = list[appIndex].windows.length
    windowIndex = windowStep ? (windowStep > 0 ? 1 : count - 1) % count : 0
    opened = true
    revealed = false
    hoverArmed = false
    revealTimer.restart()
    hoverArmTimer.restart()
    // Alt was already released before this call arrived: switch straight away.
    if (Date.now() - lastEarlyCommit < 300) commit()
  }

  function step(delta) {
    if (!opened) return begin(delta, 0)
    if (!apps.length) return
    appIndex = ((appIndex + delta) % apps.length + apps.length) % apps.length
    windowIndex = 0
    reveal()
  }

  function stepWindow(delta) {
    if (!opened) return begin(0, delta)
    const n = selectedWindows.length
    if (n < 2) return
    windowIndex = ((windowIndex + delta) % n + n) % n
    reveal()
  }

  function reveal() {
    revealTimer.stop()
    revealed = true
  }

  function commit() {
    if (!opened) {
      // Alt release reaches us twice (Hyprland release bind + our own key
      // handler); the late duplicate must not look like an early release.
      if (Date.now() - lastClosed > 400) lastEarlyCommit = Date.now()
      return
    }
    const target = selectedWindow
    close()
    if (target) dock.windows.focusWindow(target)
  }

  function cancel() {
    close()
  }

  function close() {
    lastClosed = Date.now()
    lastEarlyCommit = 0
    revealTimer.stop()
    opened = false
    revealed = false
    apps = []
  }

  function select(appIdx, winIdx) {
    appIndex = appIdx
    windowIndex = winIdx
  }

  Timer {
    id: hoverArmTimer
    interval: 350
    onTriggered: root.hoverArmed = true
  }

  Timer {
    id: revealTimer
    interval: root.settings.cfg.switcherRevealDelay
    onTriggered: root.revealed = true
  }

  // ---- input ----------------------------------------------------------------------

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: event => {
      const alt = event.modifiers & Qt.AltModifier
      const back = event.modifiers & Qt.ShiftModifier
      switch (event.key) {
      case Qt.Key_Tab: root.step(1); break
      case Qt.Key_Backtab: root.step(-1); break
      case Qt.Key_Right: root.step(1); break
      case Qt.Key_Left: root.step(-1); break
      case Qt.Key_Down: root.stepWindow(1); break
      case Qt.Key_Up: root.stepWindow(-1); break
      case Qt.Key_QuoteLeft: root.stepWindow(back ? -1 : 1); break
      case Qt.Key_AsciiTilde: root.stepWindow(-1); break
      case Qt.Key_Return:
      case Qt.Key_Enter: root.commit(); break
      case Qt.Key_Escape: root.cancel(); break
      case Qt.Key_W:
      case Qt.Key_Q:
        if (alt && root.selectedWindow) root.dock.windows.closeWindow(root.selectedWindow)
        break
      default: return
      }
      event.accepted = true
    }
    Keys.onReleased: event => {
      if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) {
        root.commit()
        event.accepted = true
      }
    }
  }

  // Windows closed while the switcher is open drop out of the snapshot.
  Connections {
    target: root.dock.windows
    function onSwitcherAppsChanged() {
      if (!root.opened) return
      const live = root.dock.windows.switcherApps
      const keep = root.apps
        .map(a => live.find(l => l.appId === a.appId))
        .filter(a => a)
      if (!keep.length) return root.cancel()
      const current = root.selectedApp ? root.selectedApp.appId : ""
      root.apps = keep
      const at = keep.findIndex(a => a.appId === current)
      root.appIndex = at === -1 ? Math.min(root.appIndex, keep.length - 1) : at
      root.windowIndex = Math.min(root.windowIndex, Math.max(0, root.selectedWindows.length - 1))
    }
  }

  // ---- panel ------------------------------------------------------------------------

  readonly property int cardWidth: settings.cfg.switcherCardWidth
  readonly property int maxPanelWidth: Math.round((screen ? screen.width : 1920) * 0.9)

  Item {
    id: panel
    width: Math.min(cards.contentWidth, root.maxPanelWidth - 32) + 32
    height: content.implicitHeight + 32
    opacity: root.revealed ? 1 : 0
    scale: root.revealed ? 1 : 0.96
    Behavior on opacity { NumberAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    GlassSurface {
      anchors.fill: parent
      theme: root.theme
      radius: 28
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
        model: root.opened ? root.apps : []
        currentIndex: root.appIndex
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
          selected: index === root.appIndex
          shownWindow: selected ? root.selectedWindow : modelData.windows[0]
          onHovered: if (root.hoverArmed) root.select(index, 0)
          onClicked: {
            root.select(index, 0)
            root.commit()
          }
        }
      }

      // The selected app's window group, when it has more than one window.
      Column {
        visible: root.selectedWindows.length > 1
        width: parent.width
        spacing: 8

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: (root.windowIndex + 1) + " / " + root.selectedWindows.length + "  ·  ↑ ↓ to switch window"
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
          model: root.opened ? root.selectedWindows : []
          currentIndex: root.windowIndex
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
            selected: index === root.windowIndex
            onActivated: {
              root.windowIndex = index
              root.commit()
            }
          }
        }
      }
    }
  }
}
