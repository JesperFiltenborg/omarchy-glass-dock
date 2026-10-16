import QtQuick
import Quickshell
import "lib/apps.mjs" as Logic

// Maps window app ids (Wayland app_id / X11 class) to desktop entries, icons
// and launch commands. Rebuilt whenever the desktop entry database changes.
//
// Matching rules live in lib/apps.mjs (unit tested); this file feeds them the
// live DesktopEntries and resolves icon names against the icon theme.
Item {
  id: root

  // Lookups are memoised per index build (index.cache), so a desktop entry
  // database change naturally invalidates them.
  readonly property var index: Logic.buildIndex(DesktopEntries.applications.values)

  function webappHost(appId) {
    return Logic.webappHost(appId)
  }

  function lookup(appId) {
    return Logic.lookup(index, appId)
  }

  function iconFor(appId) {
    for (const c of Logic.iconCandidates(appId, lookup(appId))) {
      if (c.startsWith("/")) return "file://" + c
      const p = Quickshell.iconPath(c, true)
      if (p) return p
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  function nameFor(appId) {
    return Logic.displayName(appId, lookup(appId))
  }

  function launch(appId) {
    const command = Logic.launchCommand(appId, lookup(appId))
    if (command) Quickshell.execDetached(command)
  }
}
