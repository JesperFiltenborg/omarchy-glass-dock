# Architecture

Glass Dock is an Omarchy shell plugin of kind `service`. The shell
instantiates `GlassDock.qml` once and keeps it alive. That object owns
everything else.

```
GlassDock.qml            entry point: builds the objects below, exposes IPC target "glassdock"
├── core/Settings.qml    ~/.config/omarchy/glassdock.json ⇄ settings.cfg.*
├── core/AppIndex.qml    app id → desktop entry, icon, display name, launch
├── core/WindowModel.qml Hyprland windows → per-app groups, MRU order, focus/close actions
├── ui/GlassTheme.qml    colours and metrics derived from the Omarchy theme + settings
├── ui/Dock.qml          ×N, one layer surface per monitor (Variants over screens)
│   ├── DockItem.qml       icon, magnification, dots, launch bounce, mouse actions
│   ├── PreviewPopup.qml   hover: the app's window group as live thumbnails
│   └── ContextMenu.qml    right click
├── ui/Switcher.qml      Alt+Tab overlay and its state machine
│   └── SwitcherCard.qml   one app: live preview, icon, title, window-count badge
├── ui/WindowThumb.qml   live window thumbnail (ScreencopyView), shared by both
├── ui/GlassSurface.qml  the glass pane every surface is drawn on
└── hypr/glassdock.lua   Hyprland side: blur, layer rules, Alt+Tab binds
```

## Data flow

All shared state hangs off the root object. Every view gets it as a required
`dock` property and reads `dock.settings`, `dock.apps`, `dock.windows` and
`dock.theme`. Nothing uses singletons, so a second dock-like view can be added
without touching existing ones.

### `WindowModel`

`WindowModel` is the core of grouping. It builds everything from
`Hyprland.toplevels`:

- **`groups`** maps each app id to `{ appId, windows }`. Windows are sorted
  most recent first. The app id comes from the Wayland `app_id`, falling back
  to the X11 class.
- **`mru`** lists window addresses, most recently focused first. It updates
  on `Hyprland.activeToplevel` changes, and at startup it's seeded from
  `hyprctl clients -j` (`focusHistoryID`).
- **`dockApps`** puts pinned apps first, then running apps in first-seen
  order. First-seen order keeps icons from jumping around as focus changes.
- **`switcherApps`** lists groups ordered by their most recent window. This
  is what Alt+Tab shows.

Windows are `HyprlandToplevel` objects. `.wayland` is the foreign-toplevel
handle that `ScreencopyView` captures. Focus and close go through Lua
dispatchers, for example
`Hyprland.dispatch('hl.dsp.focus({ window = "address:0x…" })')`. Hyprland
0.55+ expects Lua expressions for dispatches; the old
`focuswindow address:…` syntax is rejected.

### `AppIndex`

`AppIndex` resolves an app id in this order:

1. Chromium-family `--app` windows (`chrome-<host>__…`) are matched by URL
   host to the desktop entry that launches that URL. This is how Omarchy web
   apps get their own icons.
2. `StartupWMClass`
3. Desktop file id
4. The last segment of a reverse-DNS id
5. Name
6. Executable name

Results are memoised per index build. `DesktopEntries` loads asynchronously,
so the index rebuilds once entries arrive.

Apps are launched with `uwsm-app -- <id>.desktop`, as Omarchy launches
everything else.

## The dock surface

Each `Dock` is a bottom-anchored `PanelWindow` in the layer namespace
`glassdock`. It's taller than the visible shelf so magnified icons and popups
can draw above the shelf without a second surface:

- **`exclusiveZone`** reserves only the shelf's height, so tiled windows
  aren't pushed up by the headroom.
- **`mask`** limits input to the shelf, the active popup and, with autohide
  on, a 6 px edge trigger. The rest stays click-through.
- **Blur** is applied by Hyprland's layer rule. `ignore_alpha = 0.12` leaves
  the fully transparent headroom unblurred. The glass tint must stay above
  that alpha, or it won't blur.

Magnification works in slot space. Each `DockItem` reports
`slot + x / width` while hovered. `zoomFor(slot)` turns the distance from that
point into a cosine falloff. Computing it in slot space, not pixels, keeps it
stable while icons resize under the pointer.

Popups (`preview`, `menu`, `tooltip`) share one host item and one `Loader`.
`popupKind` selects the component. To add a popup, add a `Component` and a
kind.

## The switcher

`Switcher` is an unanchored overlay layer named `glassdock-switcher`, sized
to its panel and centred by the compositor. Its state machine:

| Method            | Effect                                                                        |
| ----------------- | ----------------------------------------------------------------------------- |
| `begin(appStep, windowStep)` | Snapshots `switcherApps`, starts on the previous app, opens          |
| `step(±1)`        | Moves between apps; opens if closed                                           |
| `stepWindow(±1)`  | Moves between the selected app's windows                                      |
| `commit()`        | Focuses the selection and closes; called while closed, it records an early release |
| `cancel()`        | Closes                                                                        |

The panel stays invisible for `switcherRevealDelay` ms. A quick Alt+Tab tap
switches straight to the previous app without flashing the overlay.

Alt release is detected in two independent ways:

1. **Hyprland side.** `hypr/glassdock.lua` arms `ALT + ALT_L` (and variant)
   release binds synchronously inside the Alt+Tab handler, so they exist
   before Alt can come up. They fire `commit` and remove themselves.
2. **Shell side.** The overlay takes exclusive keyboard focus, and
   `Keys.onReleased` sees the Alt release.

Both paths call `commit()`. A duplicate that arrives after closing is ignored
(`lastClosed`). A commit that arrives *before* the opening call — a very fast
tap where IPC processes race — is replayed by `begin()` (`lastEarlyCommit`).

## Extending

| To add…                    | Change                                                         |
| -------------------------- | -------------------------------------------------------------- |
| A setting                  | A property on the `JsonAdapter` in `core/Settings.qml`; read it via `settings.cfg.name` |
| An IPC command             | A typed function on the `IpcHandler` in `GlassDock.qml`        |
| Per-window data (urgency, etc.) | `WindowModel`; views pick it up via `dock.windows`        |
| A context-menu action      | A `MenuRow` in `ui/ContextMenu.qml`                            |
| A new popup kind           | A `Component` in `ui/Dock.qml`, then set `popupKind`           |
| Glass styling              | `ui/GlassTheme.qml` (tokens) and `ui/GlassSurface.qml` (drawing) |
| Another dock edge          | `ui/Dock.qml` anchors and layout; the data layer needs no change |

## Gotchas

- **Restart after edits.** The shell's hot reload re-reads only the entry
  file. Components in `core/` and `ui/` stay cached until
  `omarchy-restart-shell`, and `scripts/dev-sync.sh` does this for you.
- **Property shadowing.** Never name an id after a property of a child
  delegate. `bar: bar` inside a `DockItem` binds `bar` to itself, which is
  why the dock window's id is `win`.
- **Full-match regexes.** Hyprland matches layer-rule regexes against the
  full namespace. `^glassdock` matches `glassdock` but not
  `glassdock-switcher`; use `^glassdock(-.*)?$`.
- **Synthetic input.** `wtype` and other virtual keyboards don't trigger
  Hyprland binds, so Alt+Tab can only be tested with real keys. Use the IPC
  methods to script the switcher instead.
