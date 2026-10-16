import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core/lib/switcher.mjs" as Logic

// Alt+Tab: a glass overlay of the dock's app groups in most-recently-used
// order, each with a live preview. Tab moves between apps, ` moves between the
// selected app's windows, releasing Alt switches.
//
// This is the controller: the state machine, driven over IPC by
// hypr/glassdock.lua (next/prev/nextWindow/prevWindow/commit). The UI is a
// SwitcherPanel per monitor; settings.cfg.switcherDisplay picks which of them
// show (focused monitor, main monitor, or all), and exactly one takes the
// keyboard, so arrows, Enter, Esc and the Alt release work even if the
// Hyprland release bind is missing.
Item {
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
  readonly property var selectedWindows: Logic.liveWindows(selectedApp)
  readonly property var selectedWindow: selectedWindows[windowIndex] || selectedWindows[0] || null

  // Monitors showing the switcher, and the one taking the keyboard. Fixed when
  // it opens, so moving focus while Alt is held doesn't move the panel.
  property var screenNames: []
  property string keyboardScreenName: ""

  function chooseScreens() {
    const focused = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    screenNames = Logic.switcherScreens(settings.cfg.switcherDisplay,
      Quickshell.screens.map(s => s.name), focused, settings.cfg.switcherMainDisplay)
    keyboardScreenName = Logic.keyboardScreen(screenNames, focused)
  }

  // ---- state machine ----------------------------------------------------------

  function begin(appStep, windowStep) {
    const list = dock.windows.switcherApps
    const start = Logic.initialSelection(list, appStep, windowStep)
    if (!start) return
    apps = list
    appIndex = start.appIndex
    windowIndex = start.windowIndex
    chooseScreens()
    opened = true
    revealed = false
    hoverArmed = false
    revealTimer.restart()
    hoverArmTimer.restart()
    // Alt was already released before this call arrived: switch straight away.
    if (Logic.isQuickTap(Date.now(), lastEarlyCommit)) commit()
  }

  function step(delta) {
    if (!opened) return begin(delta, 0)
    if (!apps.length) return
    const next = Logic.stepApp(appIndex, delta, apps.length)
    appIndex = next.appIndex
    windowIndex = next.windowIndex
    reveal()
  }

  function stepWindow(delta) {
    if (!opened) return begin(0, delta)
    if (selectedWindows.length < 2) return
    windowIndex = Logic.stepWindow(windowIndex, delta, selectedWindows.length)
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
      lastEarlyCommit = Logic.noteClosedCommit(Date.now(), lastClosed, lastEarlyCommit)
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

  // Windows closed while the switcher is open drop out of the snapshot.
  Connections {
    target: root.dock.windows
    function onSwitcherAppsChanged() {
      if (!root.opened) return
      const next = Logic.reconcile(root.apps, root.dock.windows.switcherApps,
        root.selectedApp ? root.selectedApp.appId : "", root.appIndex, root.windowIndex)
      if (!next) return root.cancel()
      root.apps = next.apps
      root.appIndex = next.appIndex
      root.windowIndex = next.windowIndex
    }
  }

  Variants {
    model: Quickshell.screens
    SwitcherPanel {
      switcher: root
    }
  }
}
