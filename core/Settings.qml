import QtQuick
import Quickshell
import Quickshell.Io

// User settings, persisted as JSON in ~/.config/omarchy/glassdock.json.
// The file is created with defaults on first run and hot-reloads on edit.
// Read values through `settings.cfg.<key>`; write with `settings.set(key, value)`.
Item {
  id: root

  readonly property string path: Quickshell.env("HOME") + "/.config/omarchy/glassdock.json"
  readonly property alias cfg: adapter
  property double lastWrite: 0

  function set(key, value) {
    adapter[key] = value
  }

  function isPinned(appId) {
    return adapter.pinned.indexOf(appId) !== -1
  }

  function togglePin(appId) {
    const pinned = adapter.pinned.slice()
    const at = pinned.indexOf(appId)
    if (at === -1) pinned.push(appId)
    else pinned.splice(at, 1)
    adapter.pinned = pinned
  }

  function movePinned(appId, toIndex) {
    const pinned = adapter.pinned.filter(id => id !== appId)
    pinned.splice(Math.max(0, Math.min(toIndex, pinned.length)), 0, appId)
    adapter.pinned = pinned
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
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound) writeAdapter()
    }

    JsonAdapter {
      id: adapter

      // Dock
      property var pinned: []
      property var monitors: []          // [] = every monitor, else output names e.g. ["DP-3"]
      property int iconSize: 52
      property real magnification: 1.55 // 1.0 disables hover magnification
      property int magnificationRange: 3 // neighbours (in icons) affected by magnification
      property int margin: 10            // gap between dock and screen edge
      property bool autoHide: false
      property int autoHideDelay: 600
      property bool showRunningSeparator: true

      // Glass
      property real glassOpacity: 0.32   // tint strength; keep above the blur ignore_alpha (0.12)
      property real glassHighlight: 0.14 // specular sheen on the top edge
      property int cornerRadius: 24

      // Window groups / previews
      property bool previews: true
      property int previewWidth: 240
      property int previewDelay: 380
      property int maxDots: 3

      // Alt+Tab switcher
      property bool switcher: true
      property int switcherCardWidth: 280
      property int switcherRevealDelay: 90 // quick taps under this switch without flashing UI
      property bool switcherCurrentWorkspaceOnly: false
    }
  }
}
