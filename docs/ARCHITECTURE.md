# Architecture

Glass Dock is an Omarchy shell plugin of kind `service`. The shell
instantiates `GlassDock.qml` once and keeps it alive. That object owns
everything else.

```
GlassDock.qml            entry point: builds the objects below, exposes IPC target "glassdock"
├── core/lib/*.mjs      pure logic (windows, apps, switcher, settings, geometry, keys), unit tested
├── core/Settings.qml    ~/.config/omarchy/glassdock.json ⇄ settings.cfg.*
├── core/AppIndex.qml    app id → desktop entry, icon, display name, launch
├── core/WindowModel.qml Hyprland windows → per-app groups, MRU order, focus/close actions
├── core/ToggleKey.qml   the show/hide key bind, owned through `hyprctl eval` while the shell runs
├── ui/Theme.qml         design tokens for the chosen style (glass | omarchy), from the Omarchy theme
├── ui/Dock.qml          ×N, one layer surface per monitor (Variants over screens)
│   ├── DockItem.qml       icon, magnification, dots, launch bounce, mouse actions
│   ├── PreviewPopup.qml   hover: the app's window group as live thumbnails
│   └── ContextMenu.qml    right click
├── ui/Switcher.qml      Alt+Tab controller: the state machine, and which monitors show it
│   └── SwitcherPanel.qml  ×N, one per monitor: the overlay UI (pure view of the controller)
│       └── SwitcherCard.qml one app: live preview, icon, title, window-count badge
├── ui/SettingsWindow.qml glass settings panel; controls write straight to settings.cfg
├── ui/WindowThumb.qml   live window thumbnail (ScreencopyView), shared by both
├── ui/Surface.qml       the pane every surface is drawn on: glass layers, or qs.Ui BorderSurface
└── hypr/glassdock.lua   Hyprland side: blur, layer rules, Alt+Tab binds
```

## Logic and bindings

Decisions live in `core/lib/*.mjs`: plain ES modules with no Quickshell
types, imported by QML (`import "lib/windows.mjs" as Logic`) and by Node in
`tests/unit/`. The QML files own live state, timers and dispatches, and call
into these modules for every ordering, selection or geometry rule. Keep it
that way: a rule written inline in QML can only be checked by hand.

| Module         | Used by                                 | Covers |
| -------------- | --------------------------------------- | ------ |
| `windows.mjs`  | `WindowModel.qml`                       | Groups, MRU (including startup seeding), dock order, switcher order, click and wheel targets |
| `apps.mjs`     | `AppIndex.qml`                          | Desktop-entry matching (web apps by host), names, icon candidates, launch command |
| `switcher.mjs` | `Switcher.qml`                          | Opening selection, stepping, re-syncing after windows close, Alt-release timing, which monitors show it |
| `settings.mjs` | `Settings.qml`, `SettingsWindow.qml`, `GlassDock.qml` | Pin, unpin and reorder, monitor selection |
| `geometry.mjs` | `Dock.qml`                              | Magnification falloff, shelf growth, the show-on-hover zone |
| `keys.mjs`     | `ToggleKey.qml`, `SettingsWindow.qml`   | Recording a key press as a Hyprland combo, display names, the bind/unbind Lua |

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

- **`exclusiveZone`** reserves only the shelf's resting height, so tiled
  windows aren't pushed up by the headroom. It's 0 in overlay mode. With
  show-on-hover the strip stays reserved while hidden, and that empty strip
  is the hover zone.
- **`mask`** limits input to `hotZone` and the active popup; the rest stays
  click-through. `hotZone` is the shelf (or, while hidden, its resting
  footprint), widened by `revealArea` when show-on-hover is on. One
  HoverHandler on `stage`, the parent of every input item, drives reveal (after a short dwell) and hide (after
  `hideDelay`), so there are no competing enter/leave events.
- **Settings gate creation.** Docks aren't created until `Settings.ready`, so a
  layer surface never starts with default values. A surface created with the
  default exclusive zone would otherwise keep it.
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

## Designs

`settings.cfg.style` picks the design, and `Theme` turns it into tokens.
Views never test the style themselves; they use these tokens:

| Token                                    | Glass                     | Omarchy                                           |
| ---------------------------------------- | ------------------------- | ------------------------------------------------- |
| `tint` (shelf)                           | base colour at `glassOpacity` | `Color.bar.background`                        |
| `tintStrong`, `panel` (raised surfaces)  | stronger tint             | `Color.popups.background`                         |
| `rim`                                    | white at 0.2              | `Color.popups.border`, via `Border.localOrSurfaceSpec` |
| `hoverFill`, `selectedFill`              | white and accent washes   | `Style.hoverFill`, `Style.selectedFill`           |
| `r(n)`                                   | `n`                       | `min(n, Style.cornerRadius)`, which follows Hyprland rounding |
| Toggles and sliders                      | accent and white          | the `qs.Ui` ToggleSwitch / PanelSlider formulas   |

`Surface` draws the glass layers itself. For Omarchy it loads
`qs.Ui.BorderSurface`, the same component the bar's popups use, so theme
border gradients and per-side widths work automatically.

## The switcher

`Switcher` is a non-visual controller. Each monitor gets a `SwitcherPanel`:
an unanchored overlay layer named `glassdock-switcher`, sized to its panel and
centred by the compositor. Panels hold no state, so mirrored panels always
show the same selection.

When it opens, the controller fixes which monitors show it, following
`switcherDisplay` (`focused`, `primary` or `all`) and `switcherMainDisplay`.
It also fixes the one panel that takes keyboard focus: the focused monitor's
panel if it's shown, otherwise the first one shown. Moving focus while Alt is
held doesn't move the switcher. The rules are in `switcherScreens` and
`keyboardScreen` in `core/lib/switcher.mjs`.

Its state machine:

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
| A setting                  | A default in `Settings.defaults`, a matching `JsonAdapter` property, and a control in `ui/SettingsWindow.qml` |
| An IPC command             | A typed function on the `IpcHandler` in `GlassDock.qml`        |
| Per-window data (urgency, etc.) | `WindowModel`; views pick it up via `dock.windows`        |
| A context-menu action      | A `MenuRow` in `ui/ContextMenu.qml`                            |
| A new popup kind           | A `Component` in `ui/Dock.qml`, then set `popupKind`           |
| Styling, or a third design | `ui/Theme.qml` (tokens) and `ui/Surface.qml` (drawing). Views only use theme tokens and `theme.r(radius)`, so a new design is a new branch there |
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
