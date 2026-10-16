# Changelog

## 1.2.2 — 2026-10-17

- **Security:** window titles and app names are now always shown as plain
  text. Before, they were rendered as rich text, so a web page could set its
  tab title to markup such as `<img src="https://…">` and make the shell load
  that URL when the title appeared in a window preview, the Alt+Tab switcher
  or the right-click menu. Every text label now uses plain text, and a
  contract test enforces it. Reported in the Omarchy plugin marketplace
  review.

## 1.2.1 — 2026-10-17

No changes to the plugin itself; this release prepares the Omarchy plugin
marketplace listing and the project's contribution workflow.

- README: a **Requirements** section (Omarchy 4, Hyprland 0.55+ with the Lua
  config), a preview image (`preview.png`, also used by the marketplace) and
  an Alt+Tab switcher screenshot.
- GitHub issue templates: a bug report form, with blank issues turned off.
- Git workflow (`docs/GIT_WORKFLOW.md`): Conventional Commits, branch names
  (`feat/`, `fix/`, `hotfix/`, `release/`, `docs/`, `chore/`), squash-merged
  pull requests into a protected `main`. A `commit-msg` hook and a
  `conventions` CI check enforce it.
- CI: git refused to list files in the Arch container ("dubious ownership"),
  so lint checked nothing and failed. This is why the `v1.2.0` tag's build is
  red; its code is the same as 1.2.1's. Push builds now run only for `main`
  and release tags.

## 1.2.0 — 2026-10-17

- **Show/hide key.** Super+Alt+D hides or shows the dock. Change it in Dock
  Settings → Dock (click the field, press the combination), or remove it with
  ✕. New key: `toggleKey` (a Hyprland combo, `""` for none). The plugin binds
  it itself with `hyprctl eval`, rebinds it after `hyprctl reload`, and drops
  it when unloaded, so it needs no `hyprland.lua` change.
- **Show delay.** New setting `showDelay` (Dock Settings → Behaviour, default
  100 ms): how long the pointer must stay near a show-on-hover dock before it
  appears. It replaces the fixed delay (140 ms in overlay mode, 60 ms
  otherwise).
- **Animations toggle.** New setting `animations` (Dock Settings →
  Behaviour). Off disables every animation, including the launch bounce, so
  the dock, previews, switcher and settings window change instantly.
- **Hidden stays hidden.** New setting `showDock` ("Show the dock"). The
  `toggle`, `show` and `hide` IPC methods now change it, so the dock keeps its
  state across restarts.
- README: a "Disable or uninstall" section, including why disabling the
  plugin leaves Alt+Tab doing nothing until `hyprland.lua` is changed. The
  old README example bind (`SUPER + SHIFT + D`) clashed with Omarchy's Docker
  bind and is gone.
- New setting **Show on** (Dock Settings → Alt+Tab switcher) chooses where
  Alt+Tab appears: the current display (default), a main display you pick,
  or all displays, mirrored with the same selection.
- New keys: `switcherDisplay` (`"focused"`, `"primary"` or `"all"`) and
  `switcherMainDisplay` (an output name; empty means the first display).
- The switcher is now a controller plus one panel per monitor
  (`ui/SwitcherPanel.qml`). Only one panel takes the keyboard.
- Contributor tooling: `AGENTS.md` (a guide for AI coding agents),
  `CLAUDE.md`, and Claude Code project skills (`glassdock-develop`,
  `glassdock-add-setting`, `glassdock-release`). New
  `scripts/dev-tools.sh` for inspecting the live dock: layers, screenshots,
  pointer moves, plugin logs, IPC and live settings edits.
- Linting and formatting: `scripts/lint.sh [--fix]` runs biome (JS),
  stylua and luacheck (Lua), shfmt and shellcheck (shell), the qmllint gate,
  and a repo-wide whitespace/indent/line-length check. It runs in
  `scripts/test.sh`, in CI (strict), and in an optional pre-commit hook
  (`scripts/setup-dev.sh`).
- Added `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1)
  and `docs/STYLE_GUIDE.md`.

## 1.1.1 — 2026-10-17

- Test suite: `scripts/test.sh` runs static checks (a qmllint gate, JS and Lua
  syntax, the manifest), Node unit tests, and Lua tests of the Hyprland
  snippet. `scripts/test.sh e2e` runs a live smoke test in an Omarchy session.
  GitHub Actions runs the suite on Arch for every push.
- Ordering, selection, matching and geometry rules moved out of QML into
  `core/lib/*.mjs`, so they can be unit tested.
- Fixed Alt+Tab order right after a shell restart: windows focused since
  startup were pushed behind Hyprland's older focus history.

## 1.1.0 — 2026-10-16

- Design switch: **Glass** or **Omarchy**. The Omarchy design follows the
  Omarchy style guide: bar and popup colours, theme borders via the shell's
  BorderSurface, Hyprland corner rounding, and the shell's hover, selection
  and control colours. It applies to the dock, previews, menu, switcher and
  settings.
- Settings sections are collapsible, with Collapse all / Expand all.
- **Show on hover** (replaces autohide): the dock stays hidden until the
  pointer enters its area.
- **Act as overlay**: the dock floats over windows instead of reserving space.
- **Reveal area** (default 24 px above the dock, 6× that to each side): the
  pointer only has to come near the dock, not hit it exactly.
- Smoother show/hide: a single hover zone (no enter/leave flicker), a short
  dwell so passing the edge doesn't pop the dock, a slide plus fade (ease out
  in, ease in out), and no magnification until the dock has settled.
- Fixed icons spilling over the dock's sides while magnifying (the shelf width
  trailed the icons).
- Fixed the dock briefly starting with default settings, which in overlay mode
  left the default space reserved until the next change.
- Fixed the dock flickering between shown and hidden while hovering an icon
  with a short hide delay.
- New `config` IPC method to print the settings the dock is running with.
- Settings keys renamed: `autoHide` → `showOnHover`, `autoHideDelay` →
  `hideDelay`.
- Magnified icons no longer poke out above the dock; the shelf grows with
  them. Tiled windows don't move, because the reserved space keeps its
  resting height.
- Settings window: glass panel with live controls for every option, monitor
  selection, pinned-app reordering and removal, and Reset to defaults.
- Open it with `omarchy-shell glassdock settings`, from "Dock Settings…" in the
  right-click menu, or from a Super+Space → System entry (snippet in README).
- Turning the switcher off now falls back to Omarchy's plain window cycling
  instead of leaving Alt+Tab inert.

## 1.0.0 — 2026-10-16

First release.

- Liquid-glass dock: theme-derived tint, Hyprland layer blur, sheen and rim.
- Magnification on hover.
- Per-app window groups: window-count dots and hover previews with live
  thumbnails.
- Click, middle-click, wheel and right-click menu actions.
- Pinned apps, persisted in `~/.config/omarchy/glassdock.json`.
- Alt+Tab switcher: app groups in most-recently-used order, live previews,
  and stepping through each app's windows with ↑ ↓ or Alt+`.
- Hyprland snippet for blur, layer rules and Alt+Tab binds.
- Optional autohide and per-monitor filtering.
