# Contributing to Glass Dock

Thanks for helping. Bug reports, ideas and pull requests are all welcome.
By taking part you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a bug

Open an issue with the **Bug Report** form. It asks for:

- your Glass Dock, Omarchy, Hyprland and Quickshell versions
- what you did, what you expected, and what happened
- the plugin's log lines: `journalctl --user --since "10 min ago" | grep -i glassdock`
- `omarchy-shell glassdock config` output, if it's about settings
- a screenshot or short recording, if it's visual

Issues are for bugs only. Send feature ideas and documentation fixes as a
pull request.

## Making a change

```bash
git clone https://github.com/JesperFiltenborg/omarchy-glass-dock.git
cd omarchy-glass-dock
scripts/dev-init.sh        # enables the git hooks and lists missing tools
scripts/dev-sync.sh         # installs your working tree into Omarchy and restarts the shell
```

Create a branch named `<type>/<topic>`, such as `feat/show-delay` or
`fix/alt-tab-focus`. Branch names, commit messages and releases are covered in
[docs/GIT_WORKFLOW.md](docs/GIT_WORKFLOW.md). Then follow the loop:

1. **Edit.** Put rules (ordering, matching, geometry, timing) in pure
   functions in `core/lib/*.mjs` and keep QML for state and views. See
   [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
2. **Sync and look.** Run `scripts/dev-sync.sh`, then
   `scripts/dev-tools.sh logs 2`; no output means the plugin loaded.
   `scripts/dev-tools.sh` also takes screenshots and moves the pointer.
3. **Test.** `scripts/test.sh` runs lint, static checks, unit tests and Lua
   tests. `scripts/test.sh e2e` smoke-tests the live plugin.
4. **Format.** `scripts/lint.sh --fix`. The rules are in
   [docs/STYLE_GUIDE.md](docs/STYLE_GUIDE.md).
5. **Document.** README for behaviour, ARCHITECTURE for structure, and a
   `CHANGELOG.md` line under the next version.

A new setting must exist in four places (default, JSON adapter, README row,
settings window control). `tests/unit/contract.test.mjs` checks this.

## Pull requests

- Commit with [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
  (`fix(switcher): keep focus on cancel`). The `commit-msg` hook checks this.
- The PR title is a Conventional Commit header too. PRs are squash-merged, so
  the title becomes the commit on `main`.
- Keep each PR focused on one change, explain why in the description, and
  include screenshots for UI changes.
- CI must be green: `test` runs `scripts/test.sh` with strict linting on Arch,
  and `conventions` checks the PR title and branch name.
- Say what you tested by hand. Real key presses and clicks can't be
  automated, so mention whether you tried Alt+Tab, hover and clicks.

## AI coding agents

[AGENTS.md](AGENTS.md) is the briefing for AI agents. It covers the rules,
the gotchas table and the verification loop. Claude Code also loads the
project skills in `.claude/skills/`. Contributions made with agents follow
the same rules as any other.
