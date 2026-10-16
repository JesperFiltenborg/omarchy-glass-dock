// Cross-file contracts that are easy to break by hand: every setting has a
// default, a JsonAdapter property, a README row and (where it makes sense) a
// control in the settings window; the manifest and changelog agree.

import { describe, it } from "node:test"
import assert from "node:assert/strict"
import { readFileSync } from "node:fs"

const root = new URL("../../", import.meta.url)
const read = path => readFileSync(new URL(path, root), "utf8")

const settingsQml = read("core/Settings.qml")
const defaultsBlock = settingsQml.slice(
  settingsQml.indexOf("readonly property var defaults"),
  settingsQml.indexOf("})"),
)
const defaultKeys = [...defaultsBlock.matchAll(/^\s{4}(\w+):/gm)].map(m => m[1])

const adapterBlock = settingsQml.slice(settingsQml.indexOf("JsonAdapter {"))
const adapterKeys = [...adapterBlock.matchAll(/property \w+ (\w+):/g)].map(m => m[1])

// Edited through a helper rather than a direct assignment in the window.
const NO_DIRECT_CONTROL = new Set(["monitors"])

describe("settings contract", () => {
  it("found the settings (sanity check of this test's parsing)", () => {
    assert.ok(defaultKeys.length >= 20, `only parsed ${defaultKeys.length} defaults`)
  })

  it("every default has a JsonAdapter property bound to it", () => {
    for (const key of defaultKeys) {
      assert.match(adapterBlock, new RegExp(`property \\w+ ${key}: root\\.defaults\\.${key}\\b`), key)
    }
  })

  it("every JsonAdapter property except pinned has a default", () => {
    assert.deepEqual(
      adapterKeys.filter(k => k !== "pinned" && !defaultKeys.includes(k)),
      [],
    )
  })

  it("every setting is documented in the README table", () => {
    const readme = read("README.md")
    for (const key of [...defaultKeys, "pinned"]) assert.match(readme, new RegExp(`\\| \`${key}\``), key)
  })

  it("every setting has a control in the settings window", () => {
    const ui = read("ui/SettingsWindow.qml")
    for (const key of defaultKeys) {
      if (NO_DIRECT_CONTROL.has(key)) continue
      assert.match(ui, new RegExp(`root\\.cfg\\.${key} = `), key)
    }
  })

  it("settings window section titles match the collapse list", () => {
    const ui = read("ui/SettingsWindow.qml")
    const listed = JSON.parse(ui.match(/sectionTitles: (\[.*\])/)[1])
    const titled = [...ui.matchAll(/^\s+title: "([^"]+)"$/gm)]
      .map(m => m[1])
      .filter(t => listed.includes(t) || !["Glass", "Omarchy"].includes(t))
    for (const title of titled)
      assert.ok(listed.includes(title), `section "${title}" missing from sectionTitles`)
  })
})

describe("release contract", () => {
  const manifest = JSON.parse(read("manifest.json"))

  it("manifest id is not in the reserved omarchy.* namespace", () => {
    assert.doesNotMatch(manifest.id, /^omarchy\./)
  })

  it("the changelog's newest entry is the manifest version", () => {
    const newest = read("CHANGELOG.md").match(/^## (\S+)/m)[1]
    assert.equal(newest, manifest.version)
  })

  it("the Hyprland snippet loads from the manifest id's plugin folder", () => {
    assert.match(
      read("hypr/glassdock.lua"),
      new RegExp(`plugins/${manifest.id.replace(".", "\\.")}/hypr/glassdock\\.lua`),
    )
    assert.match(
      read("README.md"),
      new RegExp(`plugins/${manifest.id.replace(".", "\\.")}/hypr/glassdock\\.lua`),
    )
  })

  it("the IPC target used by the Hyprland snippet exists", () => {
    const target = read("GlassDock.qml").match(/target: "([^"]+)"/)[1]
    assert.match(read("hypr/glassdock.lua"), new RegExp(`omarchy-shell -q ${target} `))
  })
})
