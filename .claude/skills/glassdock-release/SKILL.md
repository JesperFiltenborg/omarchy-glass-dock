---
name: glassdock-release
description: Use when the user asks to commit, tag, release, version-bump or publish Glass Dock (e.g. "commit version 1.3.0", "push it to GitHub"). Covers semver choice, changelog and manifest, pre-release checks, the release branch and pull request (main is protected), the Conventional Commit format, tagging after merge, and confirming CI on GitHub.
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

## 4. Branch, commit, pull request

`main` is protected, so a release goes through a pull request like any other
change (see `docs/GIT_WORKFLOW.md`). Do the version bump on a release branch:

```bash
git switch main && git pull
git switch -c release/x.y.z          # before step 2, or carry the edits over
git add -A
git commit -F - <<'MSG'
chore(release): x.y.z

- <main changes, as in the changelog>

<attribution lines required by the session, if any>
MSG
git push -u origin release/x.y.z
gh pr create --title "chore(release): x.y.z" --body "<changelog entry>"
```

Feature work that isn't merged yet belongs on its own `feat/` or `fix/`
branches and pull requests first. The release PR should contain only the
version bump and changelog.

## 5. Wait for checks, merge, tag

```bash
gh pr checks --watch                 # `test` and `conventions` must pass
gh pr merge --squash --delete-branch
git switch main && git pull
git tag -a vx.y.z -m "Glass Dock x.y.z"   # on the squash commit now at main's tip
git push origin vx.y.z
gh run list --limit 3                # the tag's run must pass too
```

If a check fails, fix it with another commit on the release branch. A failure
only on GitHub is usually a missing tool in the Arch container
(`.github/workflows/test.yml`). Never move or delete a pushed tag unless the
user agrees.

Report the PR, the merge commit, the tag, the CI result and the repo URL.
