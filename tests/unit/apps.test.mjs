import { describe, it } from "node:test"
import assert from "node:assert/strict"
import * as A from "../../core/lib/apps.mjs"

const entry = (id, fields = {}) => ({ id, name: id, icon: id, command: [id], ...fields })

const entries = [
  entry("chromium", { name: "Chromium", command: ["/usr/bin/chromium", "%U"] }),
  entry("org.gnome.Nautilus", { name: "Files", icon: "org.gnome.Nautilus", command: ["nautilus"] }),
  entry("foot", { name: "Foot", startupClass: "foot" }),
  entry("YouTube", {
    name: "YouTube",
    icon: "youtube",
    command: ["omarchy-launch-webapp", "https://youtube.com/"],
  }),
  entry("Basecamp", {
    name: "Basecamp",
    command: ["omarchy-launch-webapp", "https://launchpad.37signals.com"],
  }),
  entry("steam", { name: "Steam", startupClass: "steam", command: ["steam-runtime"] }),
  entry("hidden-helper", { noDisplay: true }),
]

describe("webappHost", () => {
  it("reads the host from Chromium-family --app classes", () => {
    assert.equal(A.webappHost("chrome-www.youtube.com__-Default"), "www.youtube.com")
    assert.equal(A.webappHost("brave-mail.google.com__mail_-Default"), "mail.google.com")
  })

  it("is empty for ordinary app ids", () => {
    assert.equal(A.webappHost("chromium"), "")
    assert.equal(A.webappHost(undefined), "")
  })
})

describe("lookup", () => {
  const index = A.buildIndex(entries)

  it("matches desktop ids case-insensitively", () => {
    assert.equal(A.lookup(index, "Chromium").name, "Chromium")
  })

  it("matches reverse-DNS ids", () => {
    assert.equal(A.lookup(index, "org.gnome.Nautilus").name, "Files")
  })

  it("prefers StartupWMClass", () => {
    assert.equal(A.lookup(index, "steam").name, "Steam")
  })

  it("matches the executable name", () => {
    assert.equal(A.lookup(A.buildIndex(entries), "nautilus").name, "Files")
  })

  it("matches web apps by URL host, with or without www", () => {
    assert.equal(A.lookup(index, "chrome-www.youtube.com__-Default").name, "YouTube")
    assert.equal(A.lookup(index, "chrome-launchpad.37signals.com__-Default").name, "Basecamp")
  })

  it("ignores NoDisplay entries", () => {
    assert.equal(A.lookup(A.buildIndex(entries), "hidden-helper"), null)
  })

  it("returns null for unknown ids and memoises the miss", () => {
    const fresh = A.buildIndex(entries)
    assert.equal(A.lookup(fresh, "org.omarchy.agent"), null)
    assert.ok("org.omarchy.agent" in fresh.cache)
  })
})

describe("displayName", () => {
  it("uses the entry's name when there is one", () => {
    assert.equal(A.displayName("x", { name: "Pretty" }), "Pretty")
  })

  it("falls back to a web app's host without www", () => {
    assert.equal(A.displayName("chrome-www.example.com__-Default", null), "example.com")
  })

  it("capitalises the last segment of an unknown id", () => {
    assert.equal(A.displayName("org.omarchy.agent", null), "Agent")
    assert.equal(A.displayName("", null), "Unknown")
  })
})

describe("iconCandidates", () => {
  it("tries the entry icon, then the id variants, without duplicates", () => {
    assert.deepEqual(A.iconCandidates("org.gnome.Nautilus", { icon: "org.gnome.Nautilus" }), [
      "org.gnome.Nautilus",
      "org.gnome.nautilus",
      "nautilus",
    ])
  })

  it("adds a generic browser icon for unmatched web apps", () => {
    assert.deepEqual(A.iconCandidates("chrome-x.io__-Default", null).at(-1), "web-browser")
  })
})

describe("launchCommand", () => {
  it("launches the desktop entry through uwsm", () => {
    assert.deepEqual(A.launchCommand("chromium", { id: "chromium" }), ["uwsm-app", "--", "chromium.desktop"])
    assert.deepEqual(A.launchCommand("x", { id: "x.desktop" }), ["uwsm-app", "--", "x.desktop"])
  })

  it("falls back to the lower-cased app id, or nothing", () => {
    assert.deepEqual(A.launchCommand("Foo", null), ["uwsm-app", "--", "foo"])
    assert.equal(A.launchCommand("", null), null)
  })
})
