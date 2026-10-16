// The show/hide key bind: turning a Qt key press into a Hyprland combo
// string ("SUPER + ALT + D") and building the Lua that core/ToggleKey.qml
// sends with `hyprctl eval`. Pure; Qt's key and modifier codes are passed in.

// Qt.KeyboardModifier flags, in the order Hyprland combos are written.
const MODIFIERS = [
  [0x10000000, "SUPER"], // Qt.MetaModifier (the Super key on Linux)
  [0x04000000, "CTRL"],
  [0x08000000, "ALT"],
  [0x02000000, "SHIFT"],
]

// Qt.Key_* codes of keys that are modifiers themselves (Shift … Super_R, AltGr).
const MODIFIER_KEYS = [0x01000020, 0x01000021, 0x01000022, 0x01000023, 0x01000053, 0x01000054, 0x01001103]

// Qt.Key_* codes → Hyprland key names for keys other than letters, digits and F-keys.
const NAMED_KEYS = {
  32: "SPACE",
  44: "comma",
  45: "minus",
  46: "period",
  47: "slash",
  59: "semicolon",
  61: "equal",
  91: "bracketleft",
  92: "backslash",
  93: "bracketright",
  96: "grave",
  16777217: "TAB",
  16777220: "RETURN",
  16777222: "INSERT",
  16777223: "DELETE",
  16777232: "HOME",
  16777233: "END",
  16777234: "LEFT",
  16777235: "UP",
  16777236: "RIGHT",
  16777237: "DOWN",
  16777238: "PRIOR",
  16777239: "NEXT",
}

const F1 = 0x01000030

function keyName(key) {
  if ((key >= 0x41 && key <= 0x5a) || (key >= 0x30 && key <= 0x39)) return String.fromCharCode(key)
  if (key >= F1 && key < F1 + 24) return `F${key - F1 + 1}`
  return NAMED_KEYS[key] || ""
}

/**
 * A key press while recording. Returns { combo } once a usable combination
 * is pressed, { pending: true } while only modifiers are held, or { error }.
 * Every combo needs Super, Ctrl or Alt except the F-keys, so a bind never
 * swallows normal typing (Shift alone would take capital letters).
 */
export function comboFromKey(key, modifiers) {
  if (MODIFIER_KEYS.indexOf(key) !== -1) return { pending: true }
  const name = keyName(key)
  if (!name) return { error: "Use a letter, number, F-key or arrow" }
  const mods = MODIFIERS.filter(([flag]) => (modifiers & flag) !== 0).map(([, mod]) => mod)
  if (mods.every(mod => mod === "SHIFT") && !/^F\d+$/.test(name)) {
    return { error: "Hold Super, Ctrl or Alt with the key" }
  }
  return { combo: mods.concat([name]).join(" + ") }
}

/** True for a combo this module could have produced (or "" for no bind). */
export function isValidCombo(combo) {
  return combo === "" || /^((SUPER|CTRL|ALT|SHIFT) \+ )*[A-Za-z0-9]+$/.test(combo)
}

/** "SUPER + ALT + D" → "Super + Alt + D", for the settings window. */
export function formatCombo(combo) {
  if (!combo) return "None"
  const word = part => part.length > 1 && part === part.toUpperCase() && !/^F\d+$/.test(part)
  return combo
    .split(" + ")
    .map(part => (word(part) ? part[0] + part.slice(1).toLowerCase() : part))
    .join(" + ")
}

/**
 * Lua for `hyprctl eval` that drops the previous toggle bind and, unless
 * combo is "", binds combo to `command`. The bind handle lives in a Lua
 * global so the next call can remove it; pcall covers a handle left stale
 * by a Hyprland config reload. An invalid combo only unbinds.
 */
export function toggleBindLua(combo, command) {
  const unbind =
    "if glassdock_toggle_bind then pcall(function() glassdock_toggle_bind:unbind() end) end; " +
    "glassdock_toggle_bind = nil"
  if (!combo || !isValidCombo(combo)) return unbind
  const action = `function() hl.dispatch(hl.dsp.exec_cmd(${JSON.stringify(command)})) end`
  const options = '{ description = "Glass Dock: show or hide the dock" }'
  return `${unbind}; glassdock_toggle_bind = hl.bind(${JSON.stringify(combo)}, ${action}, ${options})`
}

/** `hyprctl eval` output → "" on success, else the reason in plain words. */
export function bindError(output) {
  const text = (output || "").trim()
  if (text === "ok" || text === "") return ""
  const reason = text.match(/failed to parse key string: (.*)$/)
  return reason ? reason[1] : text.replace(/^error: /, "")
}
