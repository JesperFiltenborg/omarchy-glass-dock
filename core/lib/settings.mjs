// Settings list helpers (pinned apps, monitors). Pure: each returns a new
// array, which core/Settings.qml and ui/SettingsWindow.qml assign back.

export function isPinned(pinned, appId) {
  return pinned.indexOf(appId) !== -1
}

export function togglePin(pinned, appId) {
  return isPinned(pinned, appId) ? pinned.filter(id => id !== appId) : pinned.concat([appId])
}

export function movePinned(pinned, appId, toIndex) {
  const next = pinned.filter(id => id !== appId)
  next.splice(Math.max(0, Math.min(toIndex, next.length)), 0, appId)
  return next
}

/** [] means every monitor. */
export function monitorShown(selected, name) {
  return !selected || selected.length === 0 || selected.indexOf(name) !== -1
}

/**
 * Toggle a monitor. The last shown monitor can't be turned off, and picking
 * every monitor explicitly collapses back to [] ("all"), so new monitors
 * show the dock too.
 */
export function toggleMonitor(selected, all, name) {
  const list = selected?.length ? selected.slice() : all.slice()
  const at = list.indexOf(name)
  if (at === -1) list.push(name)
  else if (list.length > 1) list.splice(at, 1)
  return list.length === all.length ? [] : list
}

/** Screens the dock should appear on. */
export function screensFor(screens, selected) {
  return selected?.length ? screens.filter(s => selected.indexOf(s.name) !== -1) : screens
}
