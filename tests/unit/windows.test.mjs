import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as W from "../../core/lib/windows.mjs"

const win = (address, app, extra = {}) => ({ address, app, ...extra })
const appIdOf = w => w.app

describe("groupWindows", () => {
  it("groups by app id with windows most recent first", () => {
    const a1 = win("a1", "chromium"),
      a2 = win("a2", "chromium"),
      b = win("b", "foot")
    const groups = W.groupWindows([a1, a2, b], ["a2", "b", "a1"], appIdOf)
    assert.deepEqual(Object.keys(groups).sort(), ["chromium", "foot"])
    assert.deepEqual(groups.chromium.windows, [a2, a1])
    assert.deepEqual(groups.foot.windows, [b])
  })

  it("puts windows never focused after focused ones", () => {
    const seen = win("seen", "x"),
      unseen = win("unseen", "x")
    assert.deepEqual(W.groupWindows([unseen, seen], ["seen"], appIdOf).x.windows, [seen, unseen])
  })

  it("skips windows without an app id", () => {
    assert.deepEqual(W.groupWindows([win("a", "")], [], appIdOf), {})
  })
})

describe("mergeAppearance", () => {
  const groups = ids => Object.fromEntries(ids.map(id => [id, { appId: id, windows: [] }]))

  it("keeps first-seen order and appends new apps", () => {
    assert.deepEqual(W.mergeAppearance(["b", "a"], groups(["a", "b", "c"])), ["b", "a", "c"])
  })

  it("drops apps that closed", () => {
    assert.deepEqual(W.mergeAppearance(["a", "b"], groups(["b"])), ["b"])
  })

  it("returns the same array when nothing changed", () => {
    const appearance = ["a", "b"]
    assert.equal(W.mergeAppearance(appearance, groups(["a", "b"])), appearance)
  })
})

describe("runningApps", () => {
  it("lists running, unpinned apps in first-seen order", () => {
    const groups = { a: {}, b: {}, c: {} }
    assert.deepEqual(W.runningApps(["c", "a", "b", "gone"], groups, ["a"]), ["c", "b"])
  })
})

describe("switcherApps", () => {
  const a1 = win("a1", "a"),
    a2 = win("a2", "a"),
    b1 = win("b1", "b"),
    c1 = win("c1", "c")
  const groups = W.groupWindows([a1, a2, b1, c1], ["b1", "a2", "c1", "a1"], appIdOf)

  it("orders apps by their most recent window", () => {
    assert.deepEqual(
      W.switcherApps(groups, ["b1", "a2", "c1", "a1"]).map(x => x.appId),
      ["b", "a", "c"],
    )
  })

  it("applies the window filter and drops apps left empty", () => {
    const list = W.switcherApps(groups, ["b1", "a2", "c1", "a1"], w => w.address !== "b1")
    assert.deepEqual(
      list.map(x => x.appId),
      ["a", "c"],
    )
  })
})

describe("touch", () => {
  it("moves an address to the front without duplicating it", () => {
    assert.deepEqual(W.touch(["a", "b", "c"], "c"), ["c", "a", "b"])
    assert.deepEqual(W.touch(["a"], "z"), ["z", "a"])
  })

  it("ignores an empty address", () => {
    const mru = ["a"]
    assert.equal(W.touch(mru, ""), mru)
  })
})

describe("seedMru", () => {
  const clients = [
    { address: "0xa", focusHistoryID: 0 },
    { address: "0xb", focusHistoryID: 1 },
    { address: "0xc", focusHistoryID: 2 },
    { address: "0xd", focusHistoryID: -1 },
  ]

  it("orders by focus history and strips 0x", () => {
    assert.deepEqual(W.seedMru(clients, []), ["a", "b", "c"])
  })

  it("keeps focus changes seen since startup in front, even if in the history", () => {
    // Focused c, then a, after the shell started but before the seed arrived.
    assert.deepEqual(W.seedMru(clients, ["a", "c"]), ["a", "c", "b"])
    assert.deepEqual(W.seedMru(clients, ["c"]), ["c", "a", "b"])
  })
})

describe("clickTarget", () => {
  const w1 = win("1", "x"),
    w2 = win("2", "x"),
    w3 = win("3", "x")

  it("focuses the latest window of an unfocused app", () => {
    assert.equal(W.clickTarget([w1, w2], w3, false), w1)
  })

  it("walks every window of the focused app, oldest first", () => {
    assert.equal(W.clickTarget([w1, w2, w3], w1, true), w3)
    assert.equal(W.clickTarget([w1, w2, w3], w3, true), w2)
  })

  it("returns null for an app with no windows", () => {
    assert.equal(W.clickTarget([], null, false), null)
  })
})

describe("cycleTarget", () => {
  const wa = win("0xa", "x"),
    wb = win("0xb", "x"),
    wc = win("0xc", "x")

  it("cycles in a stable address order, both directions, wrapping", () => {
    const mruOrder = [wc, wa, wb]
    assert.equal(W.cycleTarget(mruOrder, wa, 1), wb)
    assert.equal(W.cycleTarget(mruOrder, wc, 1), wa)
    assert.equal(W.cycleTarget(mruOrder, wa, -1), wc)
  })

  it("starts at the first window when none of the app's windows is active", () => {
    assert.equal(W.cycleTarget([wb, wa], null, 1), wa)
  })
})

describe("windowSelector", () => {
  it("always prefixes 0x exactly once", () => {
    assert.equal(W.windowSelector("5a15"), "address:0x5a15")
    assert.equal(W.windowSelector("0x5a15"), "address:0x5a15")
  })
})

describe("wrap", () => {
  it("wraps negatives and overflow, and is safe for n = 0", () => {
    assert.equal(W.wrap(-1, 3), 2)
    assert.equal(W.wrap(4, 3), 1)
    assert.equal(W.wrap(5, 0), 0)
  })
})
