import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as K from "../../core/lib/keys.mjs"

const SHIFT = 0x02000000
const CTRL = 0x04000000
const ALT = 0x08000000
const META = 0x10000000

describe("recording a combo", () => {
  it("writes modifiers in Hyprland's order, whatever order Qt reports them", () => {
    assert.deepEqual(K.comboFromKey(0x44, ALT | META), { combo: "SUPER + ALT + D" })
    assert.deepEqual(K.comboFromKey(0x31, SHIFT | CTRL), { combo: "CTRL + SHIFT + 1" })
  })

  it("waits while only modifiers are held", () => {
    assert.deepEqual(K.comboFromKey(0x01000023, ALT), { pending: true })
    assert.deepEqual(K.comboFromKey(0x01000053, META), { pending: true })
  })

  it("names F-keys, arrows and punctuation the way Hyprland does", () => {
    assert.deepEqual(K.comboFromKey(0x01000030 + 11, 0), { combo: "F12" })
    assert.deepEqual(K.comboFromKey(0x01000014, META), { combo: "SUPER + RIGHT" })
    assert.deepEqual(K.comboFromKey(0x60, ALT), { combo: "ALT + grave" })
  })

  it("refuses a plain key, which would swallow typing", () => {
    assert.ok(K.comboFromKey(0x44, 0).error)
    assert.ok(K.comboFromKey(0x44, SHIFT).error)
  })

  it("refuses keys it can't name", () => {
    assert.ok(K.comboFromKey(0x21, META | SHIFT).error) // "!" from Shift+1
  })
})

describe("combo strings", () => {
  it("accepts what it records, and the empty 'no bind'", () => {
    assert.equal(K.isValidCombo("SUPER + ALT + D"), true)
    assert.equal(K.isValidCombo("F12"), true)
    assert.equal(K.isValidCombo(""), true)
  })

  it("rejects anything that could break out of the Lua string", () => {
    assert.equal(K.isValidCombo('SUPER + D") os.execute("x'), false)
    assert.equal(K.isValidCombo("SUPER+D"), false)
  })

  it("formats for display", () => {
    assert.equal(K.formatCombo("SUPER + ALT + D"), "Super + Alt + D")
    assert.equal(K.formatCombo("CTRL + F5"), "Ctrl + F5")
    assert.equal(K.formatCombo("ALT + grave"), "Alt + grave")
    assert.equal(K.formatCombo(""), "None")
  })
})

describe("bind Lua", () => {
  const cmd = "omarchy-shell -q glassdock toggle"

  it("drops the old bind before adding the new one", () => {
    const lua = K.toggleBindLua("SUPER + ALT + D", cmd)
    assert.ok(lua.indexOf("unbind()") < lua.indexOf("hl.bind("))
    assert.match(lua, /hl\.bind\("SUPER \+ ALT \+ D", function\(\) hl\.dispatch\(hl\.dsp\.exec_cmd\(/)
    assert.ok(lua.includes(JSON.stringify(cmd)))
  })

  it("only unbinds for an empty or invalid combo", () => {
    for (const combo of ["", 'X") os.execute("y']) {
      const lua = K.toggleBindLua(combo, cmd)
      assert.ok(!lua.includes("hl.bind("))
      assert.match(lua, /glassdock_toggle_bind = nil$/)
    }
  })
})

describe("bind errors", () => {
  it("is empty when Hyprland accepted the bind", () => {
    assert.equal(K.bindError("ok\n"), "")
  })

  it("keeps only the reason from Hyprland's error", () => {
    const out =
      'error: return hl.bind("NOTAMOD + X", function() end);:1: ' +
      'hl.bind: failed to parse key string: Unknown keysym: "NOTAMOD"'
    assert.equal(K.bindError(out), 'Unknown keysym: "NOTAMOD"')
    assert.equal(K.bindError("error: something else"), "something else")
  })
})
