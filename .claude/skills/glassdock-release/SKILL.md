---
name: glassdock-release
description: Use when the user asks to commit, tag, release, version-bump or publish Glass Dock (e.g. "commit version 1.3.0", "push it to GitHub"). Covers semver choice, changelog and manifest, pre-release checks, the commit and tag format, pushing, and confirming CI on GitHub.
---

# Releasing Glass Dock

Only commit, tag or push when the user asks.

## 1. Pick the version

Semver against `manifest.json`'s current version:

- **patch:** fixes, tests, docs, internal refactors
- **minor:** new features or settings (including renamed setting keys while
  the project is young)
- **major:** breaking changes for installed users (plugin id, IPC target,
  Hyprland snippet path)

## 2. Update the files

- `manifest.json`: `"version"`.
- `CHANGELOG.md`: a new top entry `## x.y.z — YYYY-MM-DD` (today's date),
  with user-facing bullets first and new or renamed settings keys named. The
  contract test requires this heading to match the manifest.
- The README and `docs/ARCHITECTURE.md` should already describe the changes.
  If not, fix that first.

## 3. Check

```bash
scripts/lint.sh                 # must pass (CI is strict: missing tools fail)
scripts/test.sh                 # must pass
scripts/test.sh e2e --sync      # live smoke on the installed copy
omarchy plugin validate .
git status --short              # everything intended is there; nothing stray
grep -rn -I -E '/home/[a-z]|password|secret' --exclude-dir=.git .   # nothing personal goes public
```

## 4. Commit, tag, push

```bash
git add -A
git commit -F - <<'EOF'
Release Glass Dock x.y.z

<one-line summary>

- <main changes, as in the changelog>

<attribution lines required by the session, if any>
EOF
git tag -a vx.y.z -m "Glass Dock x.y.z"
git push origin main --follow-tags
```

## 5. Confirm CI

```bash
gh run list --limit 3
gh run watch <id> --exit-status     # or poll gh run list until completed
gh run view <id> --log-failed       # if it failed
```

A failure only on GitHub is usually a missing tool in the Arch container.
Fix it in `.github/workflows/test.yml` with a follow-up commit. Don't move
the pushed tag unless the user agrees.

Report the commit hash, the tag, the CI result, and the repo URL.
