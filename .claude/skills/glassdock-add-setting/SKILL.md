---
name: glassdock-add-setting
description: Use when adding, renaming or removing a Glass Dock user setting (anything stored in ~/.config/omarchy/glassdock.json and shown in Dock Settings). Lists the four places a setting must exist so the contract test passes and the settings window, docs and defaults stay in sync.
---

# Adding a setting

A setting must exist in four places. `tests/unit/contract.test.mjs` fails if
any is missing.

1. **Default:** `core/Settings.qml`, in `readonly property var defaults`.
   Use one key per line, indented four spaces, with a short trailing comment
   if the meaning isn't obvious:
   ```qml
   revealArea: 24,             // px around the dock that also reveals it
   ```
2. **Adapter property:** same file, inside `JsonAdapter`, bound to the
   default:
   ```qml
   property int revealArea: root.defaults.revealArea
   ```
   Types: `bool`, `int`, `real`, `string`, or `var` for lists.
3. **README:** a row in the Configuration table:
   ```
   | `revealArea` | `24` | What it does, in plain words |
   ```
4. **Settings window control:** `ui/SettingsWindow.qml`, in the right
   `Section`, assigning `root.cfg.<key> = …`:
   - number: `Setting { label; hint; Slider { from; to; stepSize; value: root.cfg.key; suffix; onMoved: v => root.cfg.key = v } }`
   - toggle: `Switch { checked: root.cfg.key; onToggled: v => root.cfg.key = v }`
   - choice: a `Row` of `Chip`s with `onClicked: root.cfg.key = "value"`

   Dim dependent controls with `opacity: root.cfg.parent ? 1 : 0.4`. A new
   `Section` title must also be added to `sectionTitles`.

Then:

- Read the value where it's used, via `settings.cfg.<key>` or
  `win.settings.cfg.<key>`. If it drives a rule, pass it into a
  `core/lib/*.mjs` function and unit test that.
- **Renaming a key:** existing users keep the old key in their JSON file
  (it's ignored, and the new key falls back to its default). Note the rename
  in `CHANGELOG.md`.
- Run `node --test tests/unit/`, then sync and check the control renders:
  `scripts/dev-sync.sh`, `scripts/dev-tools.sh ipc openSettings`,
  `scripts/dev-tools.sh shot glassdock-settings`, then
  `scripts/dev-tools.sh ipc closeSettings`.
- Add a `CHANGELOG.md` line naming the new key.
