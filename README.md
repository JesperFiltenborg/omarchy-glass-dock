# Glass Dock for Omarchy

A liquid-glass application dock for [Omarchy](https://omarchy.org) (Hyprland +
Quickshell), with per-app **window groups**, **live window previews**, and an
**Alt+Tab switcher** built on the same groups.

- **Glass look.** Translucent shelf tinted from your Omarchy theme, real
  Hyprland blur behind it, a specular sheen and a bright rim. It follows
  `omarchy theme set` live.
- **Magnification.** Icons swell under the pointer, macOS style.
- **Window groups.** One icon per app. Dots show how many windows it has. Hover
  for live thumbnails of every window in the group, each with its workspace.
- **Smart clicks.**
  - Left click launches the app or focuses its latest window. Clicking again
    walks through the app's windows.
  - Middle click opens a new window.
  - The mouse wheel cycles through the app's windows.
  - Right click opens a menu: jump to a window, new window, pin or unpin,
    close all.
- **Alt+Tab.** A glass overlay of your apps, most recently used first, with
  live previews. Tab moves between apps, and `` ` `` moves between the selected
  app's windows. Releasing Alt switches.
- **Pinned apps.** Pinned apps sit left of the separator and running apps sit
  right of it. Chromium web apps resolve to their own desktop entries and icons.
- **Multi-monitor.** One dock per monitor, or only the monitors you list.
- **Autohide.** Optional; hover the bottom edge to reveal the dock.

## Install

```bash
omarchy plugin add https://github.com/JesperFiltenborg/omarchy-glass-dock.git --enable
```

Then hook up blur and Alt+Tab by adding this to the end of
`~/.config/hypr/hyprland.lua`:

```lua
local glassdock = os.getenv("HOME") .. "/.config/omarchy/plugins/jesperfiltenborg.glassdock/hypr/glassdock.lua"
if io.open(glassdock) then dofile(glassdock) end
```

Check it with `hyprctl reload && hyprctl configerrors`.

The snippet does three things:

1. **Turns on Hyprland blur.** Omarchy ships with blur disabled. The snippet
   enables it, then opts every window out with `no_blur`, so your apps look
   exactly as before and only the dock is frosted.
2. **Adds layer rules.** These blur the `glassdock*` layers and disable
   Hyprland's slide-in animation for them.
3. **Replaces Alt+Tab.** It removes Omarchy's `ALT + TAB` (cycle_next) and
   `ALT + SHIFT + TAB`, and binds them, plus `` ALT + ` ``, to the switcher.

To opt out of either part, set a global before the `dofile`:

```lua
glassdock_blur = false     -- manage blur yourself
glassdock_alt_tab = false  -- keep Omarchy's Alt+Tab
```

Uninstall with `omarchy plugin remove jesperfiltenborg.glassdock` and delete
the two lines from `hyprland.lua`.

## Controls

| Where    | Input                     | Action                                                  |
| -------- | ------------------------- | ------------------------------------------------------- |
| Dock     | Left click                | Launch, focus the latest window, or step to the next one |
| Dock     | Middle click              | New window                                              |
| Dock     | Wheel                     | Cycle the app's windows                                 |
| Dock     | Hover                     | Live previews of the app's windows                      |
| Dock     | Right click               | Menu: windows, New Window, Keep in Dock, Close          |
| Preview  | Click, middle click or ✕  | Focus, or close the window                              |
| Anywhere | Alt+Tab, Alt+Shift+Tab    | Next or previous app                                    |
| Anywhere | `` Alt+` ``, `` Alt+Shift+` `` | Next or previous window of the selected app        |
| Switcher | ← → ↑ ↓                   | Move between apps and windows                           |
| Switcher | Release Alt or Enter      | Switch                                                  |
| Switcher | Esc                       | Cancel                                                  |
| Switcher | Alt+W or Alt+Q            | Close the selected window                               |

## Configuration

Settings live in `~/.config/omarchy/glassdock.json`. The dock creates the file
with defaults on first run and picks up edits immediately.

| Key                            | Default | Meaning                                              |
| ------------------------------ | ------- | ---------------------------------------------------- |
| `pinned`                       | `[]`    | App ids kept in the dock, in order                   |
| `monitors`                     | `[]`    | Output names to show the dock on (empty means all)   |
| `iconSize`                     | `52`    | Icon size in px                                      |
| `magnification`                | `1.55`  | Hover zoom (`1` disables it)                         |
| `magnificationRange`           | `3`     | How many neighbouring icons the zoom reaches         |
| `margin`                       | `10`    | Gap between the dock and the screen edge             |
| `autoHide`                     | `false` | Hide until the bottom edge is hovered                |
| `autoHideDelay`                | `600`   | ms before hiding                                     |
| `showRunningSeparator`         | `true`  | Divider between pinned and running apps              |
| `glassOpacity`                 | `0.32`  | Tint strength; keep it above the 0.12 blur threshold |
| `glassHighlight`               | `0.14`  | Strength of the top-edge sheen                       |
| `cornerRadius`                 | `24`    | Shelf corner radius                                  |
| `previews`                     | `true`  | Show window previews on hover                        |
| `previewWidth`                 | `240`   | Thumbnail width                                      |
| `previewDelay`                 | `380`   | Hover time before previews open (ms)                 |
| `maxDots`                      | `3`     | Window dots shown per app                            |
| `switcher`                     | `true`  | Enable the Alt+Tab switcher                          |
| `switcherCardWidth`            | `280`   | Switcher card width                                  |
| `switcherRevealDelay`          | `90`    | ms before the overlay appears; quicker taps switch without it |
| `switcherCurrentWorkspaceOnly` | `false` | Limit Alt+Tab to the current workspace               |

App ids are what `hyprctl clients` reports as `class`. The fastest way to pin
an app is from its right-click menu, or run `omarchy-shell glassdock pinFocused`.

## IPC

```bash
omarchy-shell glassdock <method> [arg]
```

| Method                                 | Description                                       |
| -------------------------------------- | ------------------------------------------------- |
| `next`, `prev`                         | Open the switcher, or step to the next/previous app |
| `nextWindow`, `prevWindow`             | Step through the selected app's windows           |
| `commit`, `cancel`                     | Switch to the selection, or close the switcher    |
| `toggle`, `show`, `hide`               | Show or hide the dock                             |
| `pin <appId>`, `unpin <appId>`, `pinFocused` | Manage pinned apps                          |
| `state`                                | JSON dump of what the dock sees, for debugging    |

For example, to bind a key that toggles the dock:

```lua
o.bind("SUPER + SHIFT + D", "Toggle dock", "omarchy-shell -q glassdock toggle")
```

## Known limitations

- The dock is bottom-only for now. With Omarchy's bar also at the bottom, the
  dock sits above the bar, and autohide reveals from the bar's top edge
  rather than the screen edge.
- Alt+Tab can't be exercised with `wtype` or other virtual keyboards, because
  Hyprland ignores their binds. Use the IPC methods to script it.

## Development

The plugin is split into a data layer (`core/`) and views (`ui/`). See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how the pieces fit and where
to extend them.

```bash
scripts/dev-sync.sh           # copy into ~/.config/omarchy/plugins and restart the shell
scripts/dev-sync.sh --watch   # do that on every save
omarchy plugin validate .
```

The script copies the tree and restarts the shell for two reasons. The shell's
hot reload only re-reads the plugin's entry file, so components in `core/` and
`ui/` stay cached until a restart. Its file watcher also doesn't follow
symlinks.

Shell logs: `journalctl --user -f | grep -i glassdock`.

## Credits

Inspired by [rosakodu/omarchy-dock](https://github.com/rosakodu/omarchy-dock).
This is an independent implementation.

## License

[MIT](LICENSE)
