# AGENTS.md: working on Glass Dock

This guide is for AI coding agents (and humans) changing this repo. Read it
before editing. The README covers user-facing behaviour, and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) has the full design.

## What this is

Glass Dock is an **Omarchy shell plugin**: QML loaded into the running
`omarchy-shell` (Quickshell 0.3 / Qt 6) on **Hyprland 0.55+**, whose config is
**Lua**. It provides:

- a dock with per-app window groups, live previews and magnification
- an Alt+Tab switcher
- a settings window
- Glass and Omarchy designs

There's no build step and no package manager. The plugin id is
`jesperfiltenborg.glassdock`; the IPC target is `glassdock`.

```
GlassDock.qml        entry point: wires everything, IPC handler
core/lib/*.mjs       ALL decision logic, pure and unit tested (QML and Node import it)
core/*.qml           data layer: Settings (JSON file), AppIndex, WindowModel, ToggleKey (show/hide bind)
ui/*.qml             views: Dock, DockItem, Switcher (+Panel/Card), SettingsWindow, Theme, Surface …
hypr/glassdock.lua   Hyprland side: blur, layer rules, Alt+Tab binds (users dofile it)
tests/               unit (node), lua (fake hl), e2e smoke, tools/lint-qml.mjs
scripts/             dev-sync.sh (install + restart), test.sh, dev-tools.sh (inspection)
```

## Rules

1. **Logic goes in `core/lib/*.mjs`, not inline QML.** Any ordering,
   selection, matching, timing or geometry rule should be a pure function in
   `core/lib/`. QML imports it (`import "lib/x.mjs" as X`) and owns only live
   state, timers and dispatches. Add a test in `tests/unit/` alongside it.
   Inline QML logic can only be checked by hand.
2. **Settings live in four places,** and `tests/unit/contract.test.mjs`
   enforces it. See the `glassdock-add-setting` skill:
   `Settings.defaults`, a matching `JsonAdapter` property, a README table row,
   and a control in `ui/SettingsWindow.qml`.
3. **Views use theme tokens only.** Colours come from `dock.theme.*` and radii
   from `theme.r(n)`. Never test `style` in a view; `Theme.qml` and
   `Surface.qml` handle both designs.
4. **Shared state goes through the `dock` object** (`dock.settings`,
   `dock.apps`, `dock.windows`, `dock.theme`). Don't add QML singletons.
5. **Never edit `/usr/share/omarchy/`.** It's the read-only Omarchy package.
   Read it freely; Omarchy's own UI (`shell/Ui`, `shell/Commons`) is the
   reference for the Omarchy design.
6. **Changelog and version move together.** The newest `## x.y.z` heading in
   `CHANGELOG.md` must equal `manifest.json`'s version (a contract test checks
   this).

## Gotchas we already paid for

| Symptom | Cause | Do this |
| --- | --- | --- |
| Edits to `core/` or `ui/` don't show up | The shell's hot reload only re-reads the entry file; sub-dir components stay cached | `scripts/dev-sync.sh` copies **and restarts the shell** |
| A delegate's `bar: bar` is undefined | A property with the same name as an outer id shadows it | Give window ids unique names (the dock window is `win`) |
| `Cannot override FINAL property` and the plugin won't load | Custom property named like an Item builtin (`top`, `left`, …) | Pick another name; check the logs after every sync |
| A handler acts on the previous state | A derived binding hasn't updated yet inside the `on…Changed` handler that triggers it | In handlers, compute from sources directly (a function), not from a derived property |
| Hover state lost over icons | A sibling `HoverHandler` *behind* a `MouseArea` loses hover to it | Put the `HoverHandler` on a **parent** (`stage` in `Dock.qml`) |
| `hyprctl dispatch focuswindow …` errors | Hyprland 0.55+ dispatch takes Lua | `hl.dsp.focus({ window = "address:0x…" })` (see `windowSelector`) |
| A layer rule matches the dock but not `glassdock-switcher` | Hyprland layer-rule regexes are **full** matches | `^glassdock(-.*)?$` |
| Overlay mode reserves space after a restart | A layer created before settings loaded keeps its initial exclusive zone | Docks wait for `settings.ready`; keep it that way |
| `wtype` key presses do nothing | Hyprland ignores binds from virtual keyboards | Drive the switcher with IPC (`next`, `nextWindow`, `commit`, `cancel`) |
| A bind added with `hyprctl eval` vanishes | `hyprctl reload` drops runtime binds | `ToggleKey.qml` re-applies on the `configreloaded` event; do the same for any runtime bind |
| A combo can't be recorded in the settings window | Hyprland handles bound combos before any client sees them | Expected; the recorder suspends only our own bind while it listens |
| qmllint floods warnings | It can't resolve `qs.Commons`, `qs.Ui` or Quickshell types outside the shell | Use `node tests/tools/lint-qml.mjs`, which fails only on real errors |

## Development loop

```bash
scripts/dev-sync.sh                 # install the working tree + restart omarchy-shell
scripts/dev-tools.sh logs 2         # ALWAYS check after a sync: empty means it loaded cleanly
scripts/test.sh                     # lint + static + unit + lua (what CI runs)
scripts/lint.sh --fix               # formatters + whitespace fixes; see docs/STYLE_GUIDE.md
scripts/test.sh e2e                 # live smoke test against the installed plugin
```

To inspect the live result:

```bash
scripts/dev-tools.sh layers                   # which glassdock layers are mapped, where
scripts/dev-tools.sh ipc state | jq           # what the dock sees (apps, windows, order)
scripts/dev-tools.sh ipc config | jq          # settings the dock is running with
scripts/dev-tools.sh shot dock                # screenshot the shelf area → prints a PNG path
scripts/dev-tools.sh shot glassdock-switcher  # screenshot an open layer
scripts/dev-tools.sh hover X Y                # pointer to X,Y (fires Qt hover)
scripts/dev-tools.sh away                     # pointer away from the dock
scripts/dev-tools.sh set '.showOnHover=true'  # change a setting live
```

Read screenshots to check visual changes. A dock that renders wrong still
passes every test.

## Working on someone's live desktop

The e2e tests and `dev-tools.sh` act on the **user's real session**:

- `dev-sync.sh` restarts their shell, and the bar blinks. Don't loop it
  needlessly.
- Settings you change for a test (`dev-tools.sh set …`) are the user's
  settings. Note the old values first and **restore them afterwards**.
- Never `commit` the switcher in a test unless switching focus is the point;
  use `cancel`. Moving the pointer is fine, but put it back with `away`.
- The user may be using the desktop while you test. If state looks odd (a
  setting changed, a window open), check before "fixing" it.
- Hyprland config lives in `~/.config/hypr/`. Validate with
  `hyprctl reload && hyprctl configerrors`, and back files up before editing.

## Verifying a change (definition of done)

1. `scripts/lint.sh --fix`, then `scripts/test.sh` passes, with new logic
   covered in `tests/unit/`. Code follows
   [docs/STYLE_GUIDE.md](docs/STYLE_GUIDE.md).
2. `scripts/dev-sync.sh`, then `scripts/dev-tools.sh logs 2` shows nothing.
3. `scripts/test.sh e2e` passes.
4. For visual or interaction changes: screenshots read and checked, and
   pointer and IPC scenarios exercised.
5. README, `docs/ARCHITECTURE.md` and `CHANGELOG.md` updated where behaviour
   or structure changed.
6. Tell the user what you couldn't verify, such as real key presses or clicks.

## Commits and releases

- Commit or push only when the user asks. `main` is published on GitHub, and
  CI (`.github/workflows/test.yml`) runs `scripts/test.sh` on Arch for every
  push.
- A release is a semver bump in `manifest.json` plus a dated `CHANGELOG.md`
  entry, a commit named `Release Glass Dock x.y.z`, and an annotated tag
  `vx.y.z`. See the `glassdock-release` skill.
- Never move or delete a pushed tag without the user's explicit OK.
