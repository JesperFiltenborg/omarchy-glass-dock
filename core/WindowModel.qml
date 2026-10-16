import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "lib/windows.mjs" as Logic

// Live view of every Hyprland window, grouped by application.
//
//   groups        { appId: { appId, windows: [HyprlandToplevel, ...] } }, windows MRU-first
//   dockApps      pinned apps in pinned order, then running apps in launch order (stable)
//   switcherApps  [{ appId, windows }] ordered by most recently focused window
//
// Windows are HyprlandToplevel objects: `.address`, `.title`, `.workspace`,
// `.monitor`, and `.wayland` (the handle ScreencopyView captures).
//
// The ordering and grouping rules live in lib/windows.mjs (unit tested);
// this file binds them to live Hyprland state and dispatches actions.
Item {
  id: root

  required property var settings

  property var mru: []         // window addresses, most recently focused first
  property var appearance: []  // app ids in first-seen order, keeps the dock stable

  readonly property var activeWindow: Hyprland.activeToplevel
  readonly property string activeAppId: appIdOf(activeWindow)

  readonly property var windows: Hyprland.toplevels.values.filter(t => t && t.address && appIdOf(t) !== "")

  readonly property var groups: Logic.groupWindows(windows, mru, appIdOf)

  readonly property var pinnedApps: settings.cfg.pinned
  readonly property var runningApps: Logic.runningApps(appearance, groups, pinnedApps)
  readonly property var dockApps: pinnedApps.concat(runningApps)

  readonly property var switcherApps: {
    const currentWs = Hyprland.focusedWorkspace
    const keep = settings.cfg.switcherCurrentWorkspaceOnly && currentWs
      ? (w => w.workspace === currentWs) : null
    return Logic.switcherApps(groups, mru, keep)
  }

  onGroupsChanged: appearance = Logic.mergeAppearance(appearance, groups)

  function appIdOf(t) {
    if (!t) return ""
    return (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject["class"]) || ""
  }

  function windowsOf(appId) {
    return groups[appId] ? groups[appId].windows : []
  }

  function touch(t) {
    if (t && t.address) mru = Logic.touch(mru, t.address)
  }

  function focusWindow(t) {
    if (!t || !t.address) return
    Hyprland.dispatch(`hl.dsp.focus({ window = "${Logic.windowSelector(t.address)}" })`)
  }

  function closeWindow(t) {
    if (!t || !t.address) return
    Hyprland.dispatch(`hl.dsp.window.close({ window = "${Logic.windowSelector(t.address)}" })`)
  }

  // Dock click: focus the app's latest window, or walk its windows when it
  // already has focus. Returns false when nothing is running.
  function activateApp(appId) {
    const target = Logic.clickTarget(windowsOf(appId), activeWindow, activeAppId === appId)
    if (target) focusWindow(target)
    return target !== null
  }

  function cycleApp(appId, step) {
    const target = Logic.cycleTarget(windowsOf(appId), activeWindow, step)
    if (target) focusWindow(target)
  }

  function closeApp(appId) {
    for (const t of windowsOf(appId)) closeWindow(t)
  }

  // Force quit: Hyprland kills the window's process (SIGKILL), for apps that
  // ignore closeWindow. Unsaved work is lost.
  function killWindow(t) {
    if (!t || !t.address) return
    Hyprland.dispatch(`hl.dsp.window.kill({ window = "${Logic.windowSelector(t.address)}" })`)
  }

  function forceQuitApp(appId) {
    for (const t of windowsOf(appId)) killWindow(t)
  }

  Connections {
    target: Hyprland
    function onActiveToplevelChanged() { root.touch(Hyprland.activeToplevel) }
  }

  // Seed MRU from Hyprland's own focus history so the switcher is correct
  // right after a shell restart. Asked directly rather than via
  // HyprlandToplevel.lastIpcObject, which is not populated yet at startup.
  Process {
    id: seed
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        let clients = []
        try { clients = JSON.parse(text) } catch (e) { return }
        root.mru = Logic.seedMru(clients, root.mru)
      }
    }
  }

  Component.onCompleted: {
    Hyprland.refreshToplevels()
    seed.running = true
  }
}
