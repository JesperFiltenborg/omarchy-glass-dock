import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Live view of every Hyprland window, grouped by application.
//
//   groups        { appId: { appId, windows: [HyprlandToplevel, ...] } }, windows MRU-first
//   dockApps      pinned apps in pinned order, then running apps in launch order (stable)
//   switcherApps  [{ appId, windows }] ordered by most recently focused window
//
// Windows are HyprlandToplevel objects: `.address`, `.title`, `.workspace`,
// `.monitor`, and `.wayland` (the handle ScreencopyView captures).
Item {
  id: root

  required property var settings

  property var mru: []         // window addresses, most recently focused first
  property var appearance: []  // app ids in first-seen order, keeps the dock stable

  readonly property var activeWindow: Hyprland.activeToplevel
  readonly property string activeAppId: appIdOf(activeWindow)

  readonly property var windows: Hyprland.toplevels.values.filter(t => t && t.address && appIdOf(t) !== "")

  readonly property var groups: {
    const rank = {}
    mru.forEach((address, i) => rank[address] = i)
    const map = {}
    for (const t of windows) {
      const id = appIdOf(t)
      if (!map[id]) map[id] = { appId: id, windows: [] }
      map[id].windows.push(t)
    }
    for (const id in map) {
      map[id].windows.sort((a, b) => (rank[a.address] ?? 1e9) - (rank[b.address] ?? 1e9))
    }
    return map
  }

  readonly property var pinnedApps: settings.cfg.pinned
  readonly property var runningApps: appearance.filter(id => groups[id] && pinnedApps.indexOf(id) === -1)
  readonly property var dockApps: pinnedApps.concat(runningApps)

  readonly property var switcherApps: {
    const rank = {}
    mru.forEach((address, i) => rank[address] = i)
    const currentWs = Hyprland.focusedWorkspace
    const list = []
    for (const id in groups) {
      let wins = groups[id].windows
      if (settings.cfg.switcherCurrentWorkspaceOnly && currentWs)
        wins = wins.filter(w => w.workspace === currentWs)
      if (wins.length) list.push({ appId: id, windows: wins, rank: rank[wins[0].address] ?? 1e9 })
    }
    return list.sort((a, b) => a.rank - b.rank)
  }

  onGroupsChanged: {
    const next = appearance.filter(id => groups[id])
    for (const id in groups) if (next.indexOf(id) === -1) next.push(id)
    if (next.join("\n") !== appearance.join("\n")) appearance = next
  }

  function appIdOf(t) {
    if (!t) return ""
    return (t.wayland && t.wayland.appId) || (t.lastIpcObject && t.lastIpcObject["class"]) || ""
  }

  function windowsOf(appId) {
    return groups[appId] ? groups[appId].windows : []
  }

  function touch(t) {
    if (!t || !t.address) return
    mru = [t.address].concat(mru.filter(a => a !== t.address))
  }

  function addr(t) {
    return "0x" + String(t.address).replace(/^0x/, "")
  }

  function focusWindow(t) {
    if (!t || !t.address) return
    Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`)
  }

  function closeWindow(t) {
    if (!t || !t.address) return
    Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr(t)}" })`)
  }

  // Dock click: focus the app's most recent window, or step to its next window
  // when the app is already focused. Returns false when nothing is running.
  function activateApp(appId) {
    const wins = windowsOf(appId)
    if (!wins.length) return false
    if (activeAppId === appId && wins.length > 1) {
      const at = wins.indexOf(activeWindow)
      // MRU order means wins[0] is the active window; step to the least recent
      // so repeated clicks walk through every window instead of flip-flopping.
      focusWindow(wins[at <= 0 ? wins.length - 1 : at - 1])
    } else {
      focusWindow(wins[0])
    }
    return true
  }

  function cycleApp(appId, step) {
    const wins = windowsOf(appId)
    if (!wins.length) return
    // Cycle in a stable (address) order; MRU order would just bounce between two.
    const stable = wins.slice().sort((a, b) => String(a.address).localeCompare(String(b.address)))
    const at = stable.indexOf(activeWindow)
    focusWindow(stable[((at === -1 ? 0 : at + step) % stable.length + stable.length) % stable.length])
  }

  function closeApp(appId) {
    for (const t of windowsOf(appId)) closeWindow(t)
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
        const seeded = clients
          .filter(c => c.focusHistoryID >= 0)
          .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
          .map(c => String(c.address).replace(/^0x/, ""))
        // Focus changes seen since startup are newer than the history.
        const live = root.mru.filter(a => seeded.indexOf(a) === -1)
        root.mru = live.concat(seeded.filter(a => live.indexOf(a) === -1))
      }
    }
  }

  Component.onCompleted: {
    Hyprland.refreshToplevels()
    seed.running = true
  }
}
