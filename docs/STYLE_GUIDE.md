# Style guide

This page covers how code and docs are written in Glass Dock. The tools
enforce most of it. Run `scripts/lint.sh --fix` before committing; the
pre-commit hook (`scripts/dev-init.sh`) and CI run `scripts/lint.sh` and
fail on anything left.

## Tools

| Files | Formatter | Linter | Config |
| --- | --- | --- | --- |
| Everything | `tests/tools/check-style.mjs --fix` | the same | `.editorconfig` |
| QML | none (see below) | `tests/tools/lint-qml.mjs` (qmllint gate) | — |
| JavaScript (`.mjs`) | `biome format` | `biome lint` (recommended rules) | `biome.json` |
| Lua | `stylua` | `luacheck` | `.stylua.toml`, `.luacheckrc` |
| Shell | `shfmt` | `shellcheck` | `.editorconfig` |

On Arch, install them with
`sudo pacman -S --needed shellcheck shfmt stylua luacheck biome`. The rest
(`node`, `lua`, `qmllint`) come with an Omarchy install.

`qmlformat` isn't used: it moves the commas of `key: value, // comment`
lines in object literals onto their own lines. QML is held to the
whitespace rules below plus the conventions in this guide.

## Every file

- UTF-8, LF line endings, one final newline, no trailing whitespace, no tabs.
- Indent in steps of **2 spaces** (QML, JS, Lua, shell, JSON, YAML).
- Line length: QML 140, JS, Lua and shell 120. URLs may run over.

## QML

- **Logic lives in `core/lib/*.mjs`.** QML holds state, bindings, timers
  and dispatches. If a block computes something (an order, a selection, a
  position), it belongs in a pure function with a unit test.
- File order: imports, a header comment (what the file is and why it
  exists), `id`, required properties, readonly derived properties, state,
  functions, timers and `Connections`, then child items.
- Each `id` is unique within the file and never equal to a property name a
  child declares; the dock window is `win`, not `bar`.
- One property per line in multi-line objects. Small controls may sit on one
  line (`Slider { from: 0; to: 48; … }`) if the line fits in 140 columns;
  otherwise use one property per line.
- No semicolons at the end of JavaScript statements.
- Use `const` and `let`, never `var`. Use arrow functions for callbacks.
- Colours come from `theme.*` and radii from `theme.r(n)`. Never write
  `"#..."` colours or test `cfg.style` in a view.
- Use a function, not a derived property, in `on…Changed` handlers that
  depend on what just changed.
- Write sections as `// ---- name ----` lines, matching the existing files.
- `console.log` must not be committed. The static check fails on it.

## JavaScript (`core/lib`, `tests`)

- ES modules (`.mjs`), with named exports only. Modules in `core/lib` must
  not touch Quickshell or QML objects; pass in plain data and callbacks (see
  `appIdOf` in `windows.mjs`).
- Functions are pure: return new arrays and objects, never mutate inputs.
  Tests check this.
- Every export gets a short doc comment saying what it decides and why.
- Biome formats: double quotes, no semicolons, trailing commas, arrow
  parentheses only when needed.
- Tests use `node:test` and `node:assert/strict`, with one `describe` per
  function. Test names state the behaviour ("walks every window of the
  focused app, oldest first").

## Lua (`hypr/glassdock.lua`)

- Only `hl` (Hyprland), `o` (Omarchy) and the documented opt-out globals
  (`glassdock_blur`, `glassdock_alt_tab`) are global; everything else is
  `local`.
- Name Hyprland rules with a `glassdock-` prefix so users can find and
  toggle them.
- Bind callbacks must not block; launch commands with `hl.dsp.exec_cmd`.
- Any behaviour change needs a test in `tests/lua/glassdock_test.lua`.

## Shell (`scripts/`, `tests/e2e/`)

- Bash with `set -uo pipefail` (plus `-e` where every failure should abort).
  Quote variables. Use `[[ ]]` for tests and `$(…)`, not backticks.
- Each script starts with a usage comment, which `--help`-style output
  prints.
- Scripts that act on the user's desktop must leave it as they found it.

## Docs and comments

- Comments explain **why**, or a constraint the code can't show ("Hyprland
  full-matches layer regexes"). They don't narrate what the next line does.
- Markdown: sentence-case headings, a blank line around lists and code
  blocks, and a language tag on every fenced block.
- User-facing behaviour goes in the README, structure in
  `docs/ARCHITECTURE.md`, and every release in `CHANGELOG.md`.

## Commits

- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/):
  `<type>(<scope>): <description>`, at most 72 characters, imperative and
  lower case (`fix(dock): stop flicker while hovering icons`). Explain why in
  the body.
- One logical change per commit. Branch names, types, scopes and the release
  flow are in [GIT_WORKFLOW.md](GIT_WORKFLOW.md).
