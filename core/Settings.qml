import QtQuick
import Quickshell
import Quickshell.Io
import "lib/settings.mjs" as Logic

// User settings, persisted as JSON in ~/.config/omarchy/glassdock.json.
// The file is created with defaults on first run and hot-reloads on edit.
// Read values through `settings.cfg.<key>`; write with `settings.set(key, value)`.
Item {
  id: root

  readonly property string path: Quickshell.env("HOME") + "/.config/omarchy/glassdock.json"
  readonly property alias cfg: adapter
  property double lastWrite: 0
  // False until the file has been read (or created). Views wait for this so
  // they never start with defaults and then jump to the user's values; a
  // layer surface created with the default exclusive zone would also keep it.
  property bool ready: false

  // Every setting except `pinned`, with its default. "Reset to defaults" in
  // the settings window restores these and keeps the pinned apps.
  readonly property var defaults: ({
    // Dock
    showDock: true,             // false hides the dock everywhere (IPC toggle/show/hide flip this)
    toggleKey: "SUPER + ALT + D", // Hyprland combo that shows/hides the dock; "" = no bind
    monitors: [],               // [] = every monitor, else output names e.g. ["DP-3"]
    iconSize: 52,
    magnification: 1.55,        // 1.0 disables hover magnification
    magnificationRange: 3,      // neighbours (in icons) affected by magnification
    margin: 10,                 // gap between dock and screen edge
    showOnHover: false,         // hidden until the pointer enters the dock's area
    showDelay: 100,             // ms the pointer must stay near a show-on-hover dock before it shows
    hideDelay: 600,             // ms before a show-on-hover dock hides again
    revealArea: 24,             // px around the dock that also reveals it
    overlay: false,             // float over windows instead of reserving space
    showRunningSeparator: true,
    animations: true,           // false makes every transition instant (cheapest to draw)
    // Design: "glass" (liquid glass) or "omarchy" (Omarchy's own style guide)
    style: "glass",
    // Glass
    glassOpacity: 0.32,         // tint strength; keep above the blur ignore_alpha (0.12)
    glassHighlight: 0.14,       // specular sheen on the top edge
    cornerRadius: 24,
    // Window groups / previews
    previews: true,
    previewWidth: 240,
    previewDelay: 380,
    maxDots: 3,
    // Alt+Tab switcher
    switcher: true,
    switcherCardWidth: 280,
    switcherRevealDelay: 90,    // quick taps under this switch without flashing UI
    switcherCurrentWorkspaceOnly: false,
    switcherDisplay: "focused",   // "focused" | "primary" | "all": where Alt+Tab shows
    switcherMainDisplay: ""       // monitor for "primary"; "" = the first monitor
  })

  function set(key, value) {
    adapter[key] = value
  }

  function resetToDefaults() {
    for (const key in defaults) adapter[key] = defaults[key]
  }

  function isPinned(appId) {
    return Logic.isPinned(adapter.pinned, appId)
  }

  function togglePin(appId) {
    adapter.pinned = Logic.togglePin(adapter.pinned, appId)
  }

  function movePinned(appId, toIndex) {
    adapter.pinned = Logic.movePinned(adapter.pinned, appId, toIndex)
  }

  FileView {
    id: file
    path: root.path
    watchChanges: true
    // Our own writes come back as change events; reloading on those would
    // clobber any change made while the write was in flight.
    onFileChanged: if (Date.now() - root.lastWrite > 500) reload()
    onAdapterUpdated: {
      root.lastWrite = Date.now()
      writeAdapter()
    }
    onLoaded: root.ready = true
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) writeAdapter()
      root.ready = true
    }

    JsonAdapter {
      id: adapter

      // Initialised from `defaults`; the file's values replace them on load.
      property var pinned: []
      property bool showDock: root.defaults.showDock
      property string toggleKey: root.defaults.toggleKey
      property var monitors: root.defaults.monitors
      property int iconSize: root.defaults.iconSize
      property real magnification: root.defaults.magnification
      property int magnificationRange: root.defaults.magnificationRange
      property int margin: root.defaults.margin
      property bool showOnHover: root.defaults.showOnHover
      property int showDelay: root.defaults.showDelay
      property int hideDelay: root.defaults.hideDelay
      property int revealArea: root.defaults.revealArea
      property bool overlay: root.defaults.overlay
      property bool showRunningSeparator: root.defaults.showRunningSeparator
      property bool animations: root.defaults.animations
      property string style: root.defaults.style
      property real glassOpacity: root.defaults.glassOpacity
      property real glassHighlight: root.defaults.glassHighlight
      property int cornerRadius: root.defaults.cornerRadius
      property bool previews: root.defaults.previews
      property int previewWidth: root.defaults.previewWidth
      property int previewDelay: root.defaults.previewDelay
      property int maxDots: root.defaults.maxDots
      property bool switcher: root.defaults.switcher
      property int switcherCardWidth: root.defaults.switcherCardWidth
      property int switcherRevealDelay: root.defaults.switcherRevealDelay
      property bool switcherCurrentWorkspaceOnly: root.defaults.switcherCurrentWorkspaceOnly
      property string switcherDisplay: root.defaults.switcherDisplay
      property string switcherMainDisplay: root.defaults.switcherMainDisplay
    }
  }
}
