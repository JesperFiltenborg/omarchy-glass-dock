---
name: glassdock-develop
description: Use for any code change to Glass Dock (the Omarchy dock plugin in this repo): features, bug fixes, UI tweaks, animations, Alt+Tab switcher, settings window, Hyprland snippet. Covers where code belongs, the edit → sync → check loop on the live desktop, and how to verify before reporting done.
---

# Changing Glass Dock

Read `AGENTS.md` first if you haven't this session; its rules and gotchas
table apply throughout.

## 1. Decide where the change goes

| Change | Put it in |
| --- | --- |
| A rule (ordering, selection, matching, timing, geometry, list editing) | A pure function in `core/lib/<area>.mjs` and a test in `tests/unit/<area>.test.mjs` |
| Live data (Hyprland windows, desktop entries, the settings file) | `core/WindowModel.qml`, `core/AppIndex.qml`, `core/Settings.qml`; call into `core/lib` |
| Looks | `ui/Theme.qml` (tokens) and `ui/Surface.qml` (drawing); views use only tokens and `theme.r()` |
| Dock behaviour (hover, reveal, popups, magnification) | `ui/Dock.qml` and `ui/DockItem.qml`, with geometry in `core/lib/geometry.mjs` |
| Alt+Tab | Controller `ui/Switcher.qml`, view `ui/SwitcherPanel.qml`, rules `core/lib/switcher.mjs` |
| An IPC command | The `IpcHandler` in `GlassDock.qml` (typed args, documented in the README IPC table) |
| Key binds, blur, layer rules | `hypr/glassdock.lua`, and `tests/lua/glassdock_test.lua` |
| A new setting | Use the `glassdock-add-setting` skill |

## 2. Branch

`main` is protected. When the user asks you to commit, work on a branch named
`<type>/<topic>` (`feat/`, `fix/`, `hotfix/`, `docs/`, `chore/`), write
Conventional Commits (`fix(switcher): keep focus on cancel`), and open a pull
request whose title is one too. Details are in `docs/GIT_WORKFLOW.md`.

## 3. Loop

```bash
# edit …
node --test tests/unit/                 # fast, while working on core/lib
scripts/dev-sync.sh                     # install + restart the shell (needed for core/ and ui/)
scripts/dev-tools.sh logs 2             # must print nothing; otherwise fix the load error first
```

If `logs` shows `Type X unavailable` or `Cannot override FINAL property`, the
plugin didn't load. Nothing else you observe is meaningful until it does.

## 4. Look at it

- Static UI: `scripts/dev-tools.sh shot dock` (or a layer namespace or monitor
  name), then read the PNG.
- Hover and pointer behaviour: `dev-tools.sh hover X Y`, pause, screenshot,
  then `dev-tools.sh away`. `dev-tools.sh dock-rect` gives the shelf's screen
  area to aim at.
- Animations: take several screenshots in quick succession (sleep 30–50 ms
  between) and read them side by side.
- Alt+Tab: `dev-tools.sh ipc next`, screenshot `glassdock-switcher`, then
  `ipc cancel`. Don't use `commit` unless switching focus is intended.
- Settings: `dev-tools.sh set '<jq filter>'`. Record the old value and
  restore it afterwards.
- State: `dev-tools.sh ipc state | jq` and `dev-tools.sh ipc config | jq`.

## 5. Before reporting done

```bash
scripts/lint.sh --fix    # formatters; then fix whatever it still reports
scripts/test.sh          # lint + static + unit + lua
scripts/test.sh e2e      # live smoke
```

Style rules (QML conventions the tools can't check, such as file order and
ids) are in `docs/STYLE_GUIDE.md`.

Then update `README.md`, `docs/ARCHITECTURE.md` and `CHANGELOG.md` if
behaviour or structure changed. Restore any settings or pointer state you
touched. Tell the user what couldn't be verified (real key presses, clicks,
feel), and ask them to try it.

## Pitfalls specific to QML here

- Delegates: don't name a property like an id you pass in (`bar: bar`).
- No custom properties named like `Item` builtins (`top`, `left`, `x`, …).
- In an `on…Changed` handler, read source values directly, not a derived
  binding (it may not have updated yet).
- Hover must be detected on a **parent** item, never a sibling behind
  `MouseArea`s.
- Hyprland dispatches are Lua strings: `Hyprland.dispatch('hl.dsp.focus({ window = "address:0x…" })')`.
