// App id → desktop entry matching, display names, icon candidates and launch
// commands. Pure functions over plain data; core/AppIndex.qml feeds them the
// live DesktopEntries and resolves icon names with Quickshell.iconPath.
//
// An "entry" needs: id, name, icon, startupClass, command (string array),
// noDisplay. DesktopEntry objects in the shell, plain objects in tests.

/** Build lookup tables from desktop entries. */
export function buildIndex(entries) {
  const byId = {},
    byClass = {},
    byName = {},
    byExec = {},
    webapps = []
  for (const e of entries || []) {
    if (!e || e.noDisplay) continue
    byId[
      String(e.id)
        .toLowerCase()
        .replace(/\.desktop$/, "")
    ] = e
    if (e.startupClass) byClass[String(e.startupClass).toLowerCase()] = e
    if (e.name) byName[String(e.name).toLowerCase()] = e
    const cmd = (e.command || []).join(" ")
    const url = cmd.match(/https?:\/\/([^/\s"']+)/)
    if (url) webapps.push({ host: url[1].toLowerCase(), entry: e })
    else if (e.command?.length) {
      const bin = String(e.command[0]).split("/").pop().toLowerCase()
      if (!(bin in byExec)) byExec[bin] = e
    }
  }
  return { byId, byClass, byName, byExec, webapps, cache: {} }
}

/** Host of a Chromium-family --app window, e.g. "chrome-www.youtube.com__-Default". */
export function webappHost(appId) {
  const m = String(appId || "").match(/^(?:chrome|chromium|brave|msedge)-([^_]+)__/i)
  return m ? m[1].toLowerCase() : ""
}

/**
 * Desktop entry for an app id, or null. Order: web app by URL host,
 * StartupWMClass, desktop id, last reverse-DNS segment, name, executable.
 * Memoised in index.cache.
 */
export function lookup(index, appId) {
  if (!appId) return null
  const cache = index.cache
  if (appId in cache) return cache[appId]
  const key = String(appId).toLowerCase()
  const tail = key.split(".").pop()
  const host = webappHost(appId)
  let entry = null
  if (host) {
    const hit = index.webapps.find(
      w => w.host === host || host.endsWith(`.${w.host}`) || w.host.endsWith(`.${host}`),
    )
    entry = hit ? hit.entry : null
  }
  entry =
    entry ||
    index.byClass[key] ||
    index.byId[key] ||
    index.byId[tail] ||
    index.byClass[tail] ||
    index.byName[key] ||
    index.byName[tail] ||
    index.byExec[key] ||
    index.byExec[tail] ||
    null
  cache[appId] = entry
  return entry
}

/** Human name: the entry's name, a web app's host, or a tidied app id. */
export function displayName(appId, entry) {
  if (entry?.name) return entry.name
  const host = webappHost(appId)
  if (host) return host.replace(/^www\./, "")
  const tail = String(appId || "")
    .split(".")
    .pop()
  return tail ? tail.charAt(0).toUpperCase() + tail.slice(1) : "Unknown"
}

/**
 * Icon names (or absolute paths) to try, best first. The caller resolves each
 * against the icon theme and falls back to "application-x-executable".
 */
export function iconCandidates(appId, entry) {
  const candidates = []
  if (entry?.icon) candidates.push(String(entry.icon))
  if (appId) {
    const id = String(appId)
    candidates.push(id, id.toLowerCase(), id.split(".").pop().toLowerCase())
    if (webappHost(appId)) candidates.push("web-browser")
  }
  return candidates.filter((c, i) => c && candidates.indexOf(c) === i)
}

/**
 * Launch command. Through uwsm like the rest of Omarchy, so apps land in
 * their own systemd scope instead of being children of the shell.
 */
export function launchCommand(appId, entry) {
  if (entry) return ["uwsm-app", "--", `${String(entry.id).replace(/\.desktop$/, "")}.desktop`]
  if (appId) return ["uwsm-app", "--", String(appId).toLowerCase()]
  return null
}
