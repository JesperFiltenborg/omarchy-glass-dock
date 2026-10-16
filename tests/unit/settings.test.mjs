import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as S from "../../core/lib/settings.mjs"

describe("pinned apps", () => {
  it("toggles a pin on and off without mutating the input", () => {
    const pinned = ["a"]
    assert.deepEqual(S.togglePin(pinned, "b"), ["a", "b"])
    assert.deepEqual(S.togglePin(pinned, "a"), [])
    assert.deepEqual(pinned, ["a"])
  })

  it("moves a pinned app, clamping the target index", () => {
    assert.deepEqual(S.movePinned(["a", "b", "c"], "c", 0), ["c", "a", "b"])
    assert.deepEqual(S.movePinned(["a", "b", "c"], "a", 99), ["b", "c", "a"])
    assert.deepEqual(S.movePinned(["a", "b", "c"], "b", -5), ["b", "a", "c"])
  })
})

describe("monitors", () => {
  const all = ["HDMI-A-1", "DP-3"]

  it("treats [] as every monitor", () => {
    assert.equal(S.monitorShown([], "DP-3"), true)
    assert.equal(S.monitorShown(["DP-3"], "HDMI-A-1"), false)
  })

  it("turning one monitor off from 'all' leaves the others", () => {
    assert.deepEqual(S.toggleMonitor([], all, "HDMI-A-1"), ["DP-3"])
  })

  it("never turns off the last monitor", () => {
    assert.deepEqual(S.toggleMonitor(["DP-3"], all, "DP-3"), ["DP-3"])
  })

  it("collapses back to [] once every monitor is selected", () => {
    assert.deepEqual(S.toggleMonitor(["DP-3"], all, "HDMI-A-1"), [])
  })

  it("filters screens by name", () => {
    const screens = all.map(name => ({ name }))
    assert.deepEqual(S.screensFor(screens, []), screens)
    assert.deepEqual(
      S.screensFor(screens, ["DP-3"]).map(s => s.name),
      ["DP-3"],
    )
  })
})
