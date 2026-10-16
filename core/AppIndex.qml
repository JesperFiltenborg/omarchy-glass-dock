import QtQuick
import Quickshell

// Maps window app ids (Wayland app_id / X11 class) to desktop entries, icons
// and launch commands. Rebuilt whenever the desktop entry database changes.
Item {
  id: root

  // Lookups are memoised per index build (index.cache), so a desktop entry
  // database change naturally invalidates them.
  readonly property var index: build(DesktopEntries.applications.values)

  function build(entries) {
    const byId = {}, byClass = {}, byName = {}, byExec = {}, webapps = []
    for (const e of entries || []) {
      if (!e || e.noDisplay) continue
      byId[String(e.id).toLowerCase().replace(/\.desktop$/, "")] = e
      if (e.startupClass) byClass[String(e.startupClass).toLowerCase()] = e
      if (e.name) byName[String(e.name).toLowerCase()] = e
      const cmd = (e.command || []).join(" ")
      const url = cmd.match(/https?:\/\/([^\/\s"']+)/)
      if (url) webapps.push({ host: url[1].toLowerCase(), entry: e })
      else if (e.command && e.command.length) {
        const bin = String(e.command[0]).split("/").pop().toLowerCase()
        if (!(bin in byExec)) byExec[bin] = e
      }
    }
    return { byId, byClass, byName, byExec, webapps, cache: {} }
  }

  // Chromium-family --app windows are named like "chrome-www.youtube.com__-Default".
  function webappHost(appId) {
    const m = String(appId).match(/^(?:chrome|chromium|brave|msedge)-([^_]+)__/i)
    return m ? m[1].toLowerCase() : ""
  }

  function lookup(appId) {
    if (!appId) return null
    const cache = index.cache
    if (appId in cache) return cache[appId]
    const key = String(appId).toLowerCase()
    const tail = key.split(".").pop()
    const host = webappHost(appId)
    let entry = null
    if (host) {
      const hit = index.webapps.find(w => w.host === host || host.endsWith("." + w.host) || w.host.endsWith("." + host))
      entry = hit ? hit.entry : null
    }
    entry = entry
      || index.byClass[key] || index.byId[key]
      || index.byId[tail] || index.byClass[tail]
      || index.byName[key] || index.byName[tail]
      || index.byExec[key] || index.byExec[tail]
      || null
    cache[appId] = entry
    return entry
  }

  function iconFor(appId) {
    const entry = lookup(appId)
    const candidates = []
    if (entry && entry.icon) candidates.push(entry.icon)
    if (appId) {
      candidates.push(appId, String(appId).toLowerCase(), String(appId).split(".").pop().toLowerCase())
      if (webappHost(appId)) candidates.push("web-browser")
    }
    for (const c of candidates) {
      if (String(c).startsWith("/")) return "file://" + c
      const p = Quickshell.iconPath(c, true)
      if (p) return p
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  function nameFor(appId) {
    const entry = lookup(appId)
    if (entry && entry.name) return entry.name
    const host = webappHost(appId)
    if (host) return host.replace(/^www\./, "")
    const tail = String(appId || "").split(".").pop()
    return tail ? tail.charAt(0).toUpperCase() + tail.slice(1) : "Unknown"
  }

  // Launch through uwsm like the rest of Omarchy, so apps land in their own
  // systemd scope instead of being children of the shell.
  function launch(appId) {
    const entry = lookup(appId)
    if (entry) Quickshell.execDetached(["uwsm-app", "--", String(entry.id).replace(/\.desktop$/, "") + ".desktop"])
    else if (appId) Quickshell.execDetached(["uwsm-app", "--", String(appId).toLowerCase()])
  }
}
