// Window grouping and ordering. Pure functions over plain data so they run in
// both the shell (imported by core/WindowModel.qml) and Node (tests/unit).
//
// A "window" is any object with an `address` (HyprlandToplevel in the shell,
// plain objects in tests). Callers pass `appIdOf(window)` so this module never
// touches Quickshell types.

const UNRANKED = 1e9

/** Rank lookup: address -> position in the MRU list (0 = most recent). */
export function rankOf(mru) {
  const rank = {}
  mru.forEach((address, i) => { rank[address] = i })
  return rank
}

/** Group windows by app id, each group's windows most-recently-used first. */
export function groupWindows(windows, mru, appIdOf) {
  const rank = rankOf(mru)
  const groups = {}
  for (const w of windows) {
    const id = appIdOf(w)
    if (!id) continue
    if (!groups[id]) groups[id] = { appId: id, windows: [] }
    groups[id].windows.push(w)
  }
  for (const id in groups) {
    groups[id].windows.sort((a, b) => (rank[a.address] ?? UNRANKED) - (rank[b.address] ?? UNRANKED))
  }
  return groups
}

/**
 * Keep app ids in first-seen order: drop apps that closed, append new ones.
 * Returns the same array when nothing changed, so QML bindings don't churn.
 */
export function mergeAppearance(appearance, groups) {
  const next = appearance.filter(id => groups[id])
  for (const id in groups) if (next.indexOf(id) === -1) next.push(id)
  return next.join("\n") === appearance.join("\n") ? appearance : next
}

/** Running apps that aren't pinned, in first-seen order. */
export function runningApps(appearance, groups, pinned) {
  return appearance.filter(id => groups[id] && pinned.indexOf(id) === -1)
}

/**
 * Apps for the Alt+Tab switcher, ordered by their most recent window.
 * `keepWindow` optionally filters windows (e.g. current workspace only).
 */
export function switcherApps(groups, mru, keepWindow) {
  const rank = rankOf(mru)
  const list = []
  for (const id in groups) {
    const wins = keepWindow ? groups[id].windows.filter(keepWindow) : groups[id].windows
    if (wins.length) list.push({ appId: id, windows: wins, rank: rank[wins[0].address] ?? UNRANKED })
  }
  return list.sort((a, b) => a.rank - b.rank)
}

/** Move a window address to the front of the MRU list. */
export function touch(mru, address) {
  if (!address) return mru
  return [address].concat(mru.filter(a => a !== address))
}

/**
 * Merge Hyprland's focus history (`hyprctl clients -j`) into the MRU list.
 * Focus changes recorded since startup are newer than the history, so they
 * stay in front; history fills in the rest.
 */
export function seedMru(clients, mru) {
  const seeded = clients
    .filter(c => c.focusHistoryID >= 0)
    .sort((a, b) => a.focusHistoryID - b.focusHistoryID)
    .map(c => String(c.address).replace(/^0x/, ""))
  return mru.concat(seeded.filter(a => mru.indexOf(a) === -1))
}

/**
 * Which window a dock click should focus. `wins` is the app's group (MRU
 * first). If the app already has focus, step to its least recent window so
 * repeated clicks walk every window instead of flip-flopping between two.
 * Returns null when the app has no windows.
 */
export function clickTarget(wins, active, appIsActive) {
  if (!wins.length) return null
  if (appIsActive && wins.length > 1) {
    const at = wins.indexOf(active)
    return wins[at <= 0 ? wins.length - 1 : at - 1]
  }
  return wins[0]
}

/**
 * Next window for wheel cycling: a stable (address) order, since MRU order
 * would just bounce between the two most recent windows.
 */
export function cycleTarget(wins, active, step) {
  if (!wins.length) return null
  const stable = wins.slice().sort((a, b) => String(a.address).localeCompare(String(b.address)))
  const at = stable.indexOf(active)
  return stable[wrap(at === -1 ? 0 : at + step, stable.length)]
}

/** Hyprland window selector for an address, with or without a 0x prefix. */
export function windowSelector(address) {
  return "address:0x" + String(address).replace(/^0x/, "")
}

/** Index wrapped into [0, n). */
export function wrap(index, n) {
  return n > 0 ? ((index % n) + n) % n : 0
}
