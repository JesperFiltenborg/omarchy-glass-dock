# Changelog

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
