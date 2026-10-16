@AGENTS.md

## Claude Code

Project skills (in `.claude/skills/`) cover the common jobs. Load the matching
one before starting:

- `glassdock-develop`: any code change; the edit → sync → check loop on the
  live desktop.
- `glassdock-add-setting`: adding, renaming or removing a setting (four
  places, enforced by tests).
- `glassdock-release`: version bump, changelog, commit and tag, push, and
  confirming CI.

Reading a screenshot from `scripts/dev-tools.sh shot …` is how you check
visual work here. Do it for anything that changes how the dock looks or moves.
