import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "lib/keys.mjs" as Keys

// The show/hide key bind (settings `toggleKey`). The plugin owns it while the
// shell runs: it is bound with `hyprctl eval` once settings load, rebound when
// the setting changes or Hyprland reloads its config (which drops runtime
// binds), and removed when the plugin unloads. It needs nothing in
// hyprland.lua.
Item {
  id: root

  required property var settings
  // The settings window sets this while recording a new combo, so pressing
  // the current one reaches the window instead of hiding the dock.
  property bool suspended: false
  // Why Hyprland refused the combo, or "" when it is bound (or there is none).
  property string error: ""

  readonly property string command: "omarchy-shell -q glassdock toggle"
  readonly property string combo: settings.ready && !suspended ? settings.cfg.toggleKey : ""

  onComboChanged: apply()

  function apply() {
    if (!settings.ready) return
    if (proc.running) {
      proc.queued = true
      return
    }
    proc.command = ["hyprctl", "eval", Keys.toggleBindLua(combo, command)]
    proc.running = true
  }

  Process {
    id: proc
    property bool queued: false
    stdout: StdioCollector {
      onStreamFinished: {
        const invalid = root.combo !== "" && !Keys.isValidCombo(root.combo)
        root.error = invalid ? "Not a key combination" : Keys.bindError(text)
      }
    }
    onExited: if (queued) {
      queued = false
      root.apply()
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") root.apply()
    }
  }

  Component.onDestruction: Quickshell.execDetached(["hyprctl", "eval", Keys.toggleBindLua("", command)])
}
