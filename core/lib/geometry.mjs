// Dock geometry: magnification and the show-on-hover zone. Pure maths used by
// ui/Dock.qml.

/**
 * Zoom factor for the icon at `slot`. `hoverPos` is the pointer in slot
 * coordinates (slot + x / width), -1 when away. Cosine falloff over `range`
 * slots; `amount` (0..1) fades the whole effect in and out.
 */
export function zoomFor(slot, hoverPos, magnification, range, amount) {
  if (magnification <= 1.001 || hoverPos < 0 || amount <= 0) return 1
  range = Math.max(1, range)
  const d = Math.abs(slot + 0.5 - hoverPos)
  if (d >= range) return 1
  return 1 + (magnification - 1) * amount * (Math.cos(d / range * Math.PI) + 1) / 2
}

/** Largest zoom across `count` slots: how much the shelf has to grow. */
export function peakZoom(count, hoverPos, magnification, range, amount) {
  let peak = 1
  for (let i = 0; i < count; i++) peak = Math.max(peak, zoomFor(i, hoverPos, magnification, range, amount))
  return peak
}

/** Sideways the reveal zone reaches this many times further than upwards. */
export const SIDE_REACH_FACTOR = 6

/**
 * The pointer zone that reveals or keeps a show-on-hover dock, in window
 * coordinates. While hidden it starts at the dock's resting top edge; while
 * shown, at the (possibly magnified) shelf's top. The same reach applies
 * either way, so a pointer resting in the outer area can't summon the dock
 * and then immediately hide it. Without show-on-hover it is just the shelf.
 */
export function hotZone({ hoverMode, revealed, revealArea, shelfX, shelfY, shelfWidth,
                          restingTop, windowWidth, windowHeight }) {
  const reach = hoverMode ? revealArea : 0
  const side = reach * SIDE_REACH_FACTOR
  const edge = revealed ? shelfY : restingTop
  const x = Math.max(0, shelfX - side)
  const right = Math.min(windowWidth, shelfX + shelfWidth + side)
  const y = Math.max(0, edge - reach)
  return { x, y, width: right - x, height: windowHeight - y }
}
