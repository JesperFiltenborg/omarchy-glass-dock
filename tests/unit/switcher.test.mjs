import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as S from "../../core/lib/switcher.mjs"

const app = (appId, count) => ({
  appId,
  windows: Array.from({ length: count }, (_, i) => ({ address: `${appId}${i}` })),
})

describe("initialSelection", () => {
  const apps = [app("focused", 2), app("previous", 1), app("oldest", 3)]

  it("Alt+Tab lands on the previous app", () => {
    assert.deepEqual(S.initialSelection(apps, 1, 0), { appIndex: 1, windowIndex: 0 })
  })

  it("Alt+Shift+Tab lands on the oldest app", () => {
    assert.deepEqual(S.initialSelection(apps, -1, 0), { appIndex: 2, windowIndex: 0 })
  })

  it("Alt+` stays on the focused app and picks its next window", () => {
    assert.deepEqual(S.initialSelection(apps, 0, 1), { appIndex: 0, windowIndex: 1 })
    assert.deepEqual(S.initialSelection(apps, 0, -1), { appIndex: 0, windowIndex: 1 })
  })

  it("with a single app, Alt+Tab stays on it", () => {
    assert.deepEqual(S.initialSelection([app("only", 1)], 1, 0), { appIndex: 0, windowIndex: 0 })
  })

  it("returns null when nothing is open", () => {
    assert.equal(S.initialSelection([], 1, 0), null)
  })
})

describe("stepApp / stepWindow", () => {
  it("wraps app steps both ways and resets the window", () => {
    assert.deepEqual(S.stepApp(2, 1, 3), { appIndex: 0, windowIndex: 0 })
    assert.deepEqual(S.stepApp(0, -1, 3), { appIndex: 2, windowIndex: 0 })
  })

  it("wraps window steps, and ignores single-window apps", () => {
    assert.equal(S.stepWindow(2, 1, 3), 0)
    assert.equal(S.stepWindow(0, -1, 3), 2)
    assert.equal(S.stepWindow(0, 1, 1), 0)
  })
})

describe("reconcile", () => {
  const a = app("a", 2),
    b = app("b", 1),
    c = app("c", 1)

  it("keeps snapshot order and the selected app when it survives", () => {
    const next = S.reconcile([a, b, c], [c, b], "b", 1, 0)
    assert.deepEqual(
      next.apps.map(x => x.appId),
      ["b", "c"],
    )
    assert.equal(next.appIndex, 0)
  })

  it("clamps the selection when the selected app closed", () => {
    const next = S.reconcile([a, b, c], [a, b], "c", 2, 0)
    assert.equal(next.appIndex, 1)
  })

  it("clamps the window index to the app's live windows", () => {
    const shrunk = { appId: "a", windows: [{ address: "a0" }, { address: "" }] }
    assert.equal(S.reconcile([a], [shrunk], "a", 0, 1).windowIndex, 0)
  })

  it("returns null when every app is gone", () => {
    assert.equal(S.reconcile([a], [], "a", 0, 0), null)
  })
})

describe("Alt release timing", () => {
  it("records a commit while closed as an early release", () => {
    assert.equal(S.noteClosedCommit(10_000, 0, 0), 10_000)
  })

  it("ignores the late duplicate of the commit that just closed it", () => {
    assert.equal(S.noteClosedCommit(10_000, 10_000 - S.DUPLICATE_RELEASE_MS + 50, 7), 7)
  })

  it("treats an opening call right after an early release as a quick tap", () => {
    assert.equal(S.isQuickTap(1_000, 1_000 - 100), true)
    assert.equal(S.isQuickTap(1_000, 1_000 - S.EARLY_RELEASE_MS - 1), false)
    assert.equal(S.isQuickTap(1_000, 0), false)
  })
})

describe("switcherScreens", () => {
  const all = ["HDMI-A-1", "DP-3"]

  it("shows on the focused monitor by default", () => {
    assert.deepEqual(S.switcherScreens("focused", all, "DP-3", ""), ["DP-3"])
  })

  it("shows on the main monitor in primary mode, wherever focus is", () => {
    assert.deepEqual(S.switcherScreens("primary", all, "HDMI-A-1", "DP-3"), ["DP-3"])
  })

  it("falls back to the first monitor when the main one is unset or unplugged", () => {
    assert.deepEqual(S.switcherScreens("primary", all, "DP-3", ""), ["HDMI-A-1"])
    assert.deepEqual(S.switcherScreens("primary", all, "DP-3", "eDP-1"), ["HDMI-A-1"])
  })

  it("mirrors on every monitor in all mode", () => {
    assert.deepEqual(S.switcherScreens("all", all, "DP-3", ""), all)
  })

  it("treats an unknown mode as focused, and handles no monitors", () => {
    assert.deepEqual(S.switcherScreens("bogus", all, "DP-3", ""), ["DP-3"])
    assert.deepEqual(S.switcherScreens("all", [], "DP-3", ""), [])
  })
})

describe("keyboardScreen", () => {
  it("is the focused monitor when the switcher shows there", () => {
    assert.equal(S.keyboardScreen(["HDMI-A-1", "DP-3"], "DP-3"), "DP-3")
  })

  it("is the only shown monitor otherwise", () => {
    assert.equal(S.keyboardScreen(["DP-3"], "HDMI-A-1"), "DP-3")
    assert.equal(S.keyboardScreen([], "DP-3"), "")
  })
})
