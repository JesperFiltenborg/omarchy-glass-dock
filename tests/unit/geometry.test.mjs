import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as G from "../../core/lib/geometry.mjs"

describe("zoomFor", () => {
  it("is 1 when magnification is off, the pointer is away, or faded out", () => {
    assert.equal(G.zoomFor(0, 0.5, 1, 3, 1), 1)
    assert.equal(G.zoomFor(0, -1, 1.5, 3, 1), 1)
    assert.equal(G.zoomFor(0, 0.5, 1.5, 3, 0), 1)
  })

  it("peaks at the hovered icon's centre", () => {
    assert.equal(G.zoomFor(2, 2.5, 1.5, 3, 1), 1.5)
  })

  it("falls off with distance and is symmetric", () => {
    const left = G.zoomFor(1, 2.5, 1.5, 3, 1)
    const right = G.zoomFor(3, 2.5, 1.5, 3, 1)
    assert.ok(left > 1 && left < 1.5)
    assert.ok(Math.abs(left - right) < 1e-9)
  })

  it("is 1 beyond the range", () => {
    assert.equal(G.zoomFor(9, 2.5, 1.5, 3, 1), 1)
  })

  it("scales with the fade amount", () => {
    assert.equal(G.zoomFor(2, 2.5, 1.5, 3, 0.5), 1.25)
  })
})

describe("peakZoom", () => {
  it("is the largest zoom across the icons", () => {
    assert.equal(G.peakZoom(5, 2.5, 1.6, 3, 1), 1.6)
    assert.equal(G.peakZoom(0, 2.5, 1.6, 3, 1), 1)
  })
})

describe("hotZone", () => {
  const base = {
    hoverMode: true,
    revealed: false,
    revealArea: 24,
    shelfX: 1000,
    shelfY: 380,
    shelfWidth: 200,
    restingTop: 400,
    windowWidth: 3440,
    windowHeight: 500,
  }

  it("without show-on-hover it is exactly the shelf", () => {
    assert.deepEqual(G.hotZone({ ...base, hoverMode: false, revealed: true }), {
      x: 1000,
      y: 380,
      width: 200,
      height: 120,
    })
  })

  it("while hidden it reaches revealArea above the resting top and 6x sideways", () => {
    const side = 24 * G.SIDE_REACH_FACTOR
    assert.deepEqual(G.hotZone(base), { x: 1000 - side, y: 376, width: 200 + 2 * side, height: 124 })
  })

  it("while shown it follows the (magnified) shelf with the same reach", () => {
    const zone = G.hotZone({ ...base, revealed: true })
    assert.equal(zone.y, 380 - 24)
    assert.equal(zone.width, G.hotZone(base).width)
  })

  it("is clamped to the window", () => {
    const zone = G.hotZone({ ...base, shelfX: 10, revealArea: 100 })
    assert.equal(zone.x, 0)
    assert.ok(zone.x + zone.width <= base.windowWidth)
    assert.equal(G.hotZone({ ...base, restingTop: 5, revealArea: 100 }).y, 0)
  })
})
