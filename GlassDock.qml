import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "ui"

// Glass Dock — Omarchy shell service entry point.
//
// Wires the data layer (core/) to the views (ui/) and exposes the `glassdock`
// IPC target. Every view receives this object as `dock` and reaches shared
// state through it: dock.settings, dock.apps, dock.windows, dock.theme.
Item {
  id: root

  // Injected by the Omarchy shell host.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  readonly property alias settings: settingsStore
  readonly property alias apps: appIndex
  readonly property alias windows: windowModel
  readonly property alias theme: glassTheme
  readonly property alias switcher: switcherWindow

  property bool dockVisible: true

  Settings { id: settingsStore }

  AppIndex { id: appIndex }

  WindowModel {
    id: windowModel
    settings: settingsStore
  }

  GlassTheme {
    id: glassTheme
    settings: settingsStore
  }

  Variants {
    model: {
      const wanted = settingsStore.cfg.monitors || []
      const screens = Quickshell.screens
      return root.dockVisible
        ? (wanted.length ? screens.filter(s => wanted.indexOf(s.name) !== -1) : screens)
        : []
    }
    Dock {
      dock: root
    }
  }

  Switcher {
    id: switcherWindow
    dock: root
  }

  // omarchy-shell glassdock <method> [arg]
  IpcHandler {
    target: "glassdock"

    function ping(): string { return "ok" }

    // Alt+Tab switcher (see hypr/glassdock.lua)
    function next(): void { if (settingsStore.cfg.switcher) switcherWindow.step(1) }
    function prev(): void { if (settingsStore.cfg.switcher) switcherWindow.step(-1) }
    function nextWindow(): void { if (settingsStore.cfg.switcher) switcherWindow.stepWindow(1) }
    function prevWindow(): void { if (settingsStore.cfg.switcher) switcherWindow.stepWindow(-1) }
    function commit(): void { switcherWindow.commit() }
    function cancel(): void { switcherWindow.cancel() }

    // Dock
    function toggle(): void { root.dockVisible = !root.dockVisible }
    function show(): void { root.dockVisible = true }
    function hide(): void { root.dockVisible = false }
    function pin(appId: string): void { if (!settingsStore.isPinned(appId)) settingsStore.togglePin(appId) }
    function unpin(appId: string): void { if (settingsStore.isPinned(appId)) settingsStore.togglePin(appId) }
    function pinFocused(): void {
      const id = windowModel.activeAppId
      if (id && !settingsStore.isPinned(id)) settingsStore.togglePin(id)
    }

    // Debugging: what the dock currently sees.
    function state(): string {
      return JSON.stringify({
        pinned: windowModel.pinnedApps,
        running: windowModel.runningApps,
        active: windowModel.activeAppId,
        switcher: windowModel.switcherApps.map(a => ({ app: a.appId, windows: a.windows.map(w => w.title) })),
        icons: windowModel.dockApps.map(id => ({ id: id, name: appIndex.nameFor(id), icon: appIndex.iconFor(id) }))
      }, null, 2)
    }
  }
}
