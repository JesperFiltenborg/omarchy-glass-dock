// Alt+Tab selection logic, used by ui/Switcher.qml. Pure functions: the QML
// side owns the state and timers, these decide what the next state is.

import { wrap } from "./windows.mjs"

/** A late duplicate Alt release (bind + key handler) arrives within this. */
export const DUPLICATE_RELEASE_MS = 400
/** An Alt release this soon before the opening call means a quick tap. */
export const EARLY_RELEASE_MS = 300

/**
 * Where the switcher opens. `apps` is MRU-first, so apps[0] is the focused
 * app: Alt+Tab (appStep 1) lands on the one before it, Alt+Shift+Tab on the
 * oldest. Alt+` (windowStep) stays on the focused app and picks its next or
 * last window.
 */
export function initialSelection(apps, appStep, windowStep) {
  if (!apps.length) return null
  const appIndex = appStep && apps.length > 1 ? (appStep > 0 ? 1 : apps.length - 1) : 0
  const count = apps[appIndex].windows.length
  const windowIndex = windowStep && count > 0 ? wrap(windowStep > 0 ? 1 : -1, count) : 0
  return { appIndex, windowIndex }
}

/** Next app index; the window selection resets to the app's latest window. */
export function stepApp(appIndex, delta, count) {
  return { appIndex: wrap(appIndex + delta, count), windowIndex: 0 }
}

/** Next window index within the selected app (unchanged for one window). */
export function stepWindow(windowIndex, delta, count) {
  return count < 2 ? windowIndex : wrap(windowIndex + delta, count)
}

/** Live windows of an app entry (closed windows lose their address). */
export function liveWindows(app) {
  return app ? app.windows.filter(w => w?.address) : []
}

/**
 * Re-sync an open switcher with the live app list after windows open or
 * close. Keeps the snapshot's order and the selected app when it survives.
 * Returns null when nothing is left (the switcher should cancel).
 */
export function reconcile(snapshot, live, selectedAppId, appIndex, windowIndex) {
  const apps = snapshot.map(a => live.find(l => l.appId === a.appId)).filter(a => a)
  if (!apps.length) return null
  const at = apps.findIndex(a => a.appId === selectedAppId)
  const nextApp = at === -1 ? Math.min(appIndex, apps.length - 1) : at
  const windows = liveWindows(apps[nextApp]).length
  return { apps, appIndex: nextApp, windowIndex: Math.min(windowIndex, Math.max(0, windows - 1)) }
}

/**
 * A commit arrived while closed. Record it as an early Alt release unless it
 * is the late duplicate of a commit that just closed the switcher. Returns the
 * timestamp to store, or the previous one.
 */
export function noteClosedCommit(now, lastClosed, lastEarlyCommit) {
  return now - lastClosed > DUPLICATE_RELEASE_MS ? now : lastEarlyCommit
}

/** Whether an opening call should commit at once (Alt already released). */
export function isQuickTap(now, lastEarlyCommit) {
  return now - lastEarlyCommit < EARLY_RELEASE_MS
}

/**
 * Monitor names the switcher shows on, chosen when it opens:
 *   "focused"  the monitor with the focused window (default)
 *   "primary"  the configured main monitor
 *   "all"      every monitor, mirrored
 * A focused or main monitor that isn't connected falls back to the first one.
 */
export function switcherScreens(mode, all, focused, primary) {
  if (!all.length) return []
  if (mode === "all") return all.slice()
  const wanted = mode === "primary" ? primary : focused
  return [all.indexOf(wanted) !== -1 ? wanted : all[0]]
}

/** The one switcher panel that takes the keyboard: on the focused monitor if shown there. */
export function keyboardScreen(shown, focused) {
  return shown.indexOf(focused) !== -1 ? focused : shown[0] || ""
}
