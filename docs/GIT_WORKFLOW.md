# Git workflow

How changes get into Glass Dock: branch names, commit messages, pull requests
and releases. The rules are checked automatically, by a git hook on your
machine and by CI on every pull request, so you'll know before merge if
something is off.

## The short version

```bash
git switch main && git pull
git switch -c feat/show-delay              # <type>/<topic>
# … edit, then commit with Conventional Commits:
git commit -m "feat(dock): add a show delay for show on hover"
git push -u origin feat/show-delay
gh pr create --fill                        # PR title: a Conventional Commit too
```

`main` is protected: every change lands through a pull request that passes CI,
and is squash-merged so `main` gets one commit per pull request, titled with
the pull request's title.

## Branches

Name every branch `<type>/<topic>`. The topic is a few lower-case words
joined by `-`. For releases, it's the version.

| Branch | Use it for | Example |
| --- | --- | --- |
| `feat/<topic>` | A new feature or setting | `feat/show-delay` |
| `fix/<topic>` | A bug fix that can wait for the next release | `fix/alt-tab-focus` |
| `hotfix/<topic>` | An urgent fix for a released version, released as a patch right after merge | `hotfix/dock-crash-on-unplug` |
| `release/<version>` | The version bump and changelog for a release | `release/1.3.0` |
| `docs/<topic>` | Documentation only | `docs/install-steps` |
| `chore/<topic>` | Everything else: tooling, CI, refactors, tests, dependencies | `chore/biome-2-6` |

Branch from an up-to-date `main`, keep each branch to one change, and delete
it after merge (GitHub does this automatically).

## Commit messages

Commits follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <description>

[optional body: what changed and why, wrapped at 72 columns]

[optional footers, e.g. Fixes #12, BREAKING CHANGE: …, Co-Authored-By: …]
```

- **Header:** at most 72 characters. The description starts in lower case,
  uses the imperative ("add", not "added" or "adds") and has no full stop at
  the end.
- **Body:** separated from the header by a blank line. Explain *why* the change
  was made; the diff already shows *what* changed.
- **Scope** is optional: one lower-case word for the part of the dock that
  changed.

### Types

| Type | When | Release effect |
| --- | --- | --- |
| `feat` | A user-visible feature or setting | minor |
| `fix` | A user-visible bug fix | patch |
| `perf` | Faster or lighter, same behaviour | patch |
| `docs` | Documentation only | none |
| `style` | Formatting only, no code change | none |
| `refactor` | Code change that neither fixes nor adds anything | none |
| `test` | Tests only | none |
| `build` | Packaging, manifest, plugin metadata | none |
| `ci` | GitHub Actions and CI scripts | none |
| `chore` | Tooling and housekeeping, including `chore(release): x.y.z` | none |
| `revert` | Reverting an earlier commit | as the reverted one |

### Scopes

Use these when they fit. They're not enforced, so a new area can use a new
word.

`dock`, `previews`, `switcher`, `settings`, `theme`, `ipc`, `keys`, `hypr`,
`release`, `deps`.

### Breaking changes

A change that breaks installed setups needs a new major version. Examples are
renaming the plugin id, the IPC target, an IPC method or the Hyprland snippet
path. Mark it with `!` after the type or scope, and say what users must do in
a `BREAKING CHANGE:` footer:

```
feat(ipc)!: rename toggle to toggleDock

BREAKING CHANGE: key binds calling `omarchy-shell glassdock toggle` must call
`toggleDock` instead.
```

### Examples

```
feat(settings): add an animations toggle
fix(switcher): keep focus unchanged when Alt+Tab is cancelled
docs: explain why disabling the plugin breaks Alt+Tab
ci: trust the checkout so git can list files in the container
chore(release): 1.3.0
```

## Pull requests

- The **title** is a Conventional Commit header. It becomes the commit message
  on `main`, so it follows every rule above. Use the type of the most
  important change.
- The **description** says what changed, why, and how it was tested (see the
  definition of done in [AGENTS.md](../AGENTS.md#verifying-a-change-definition-of-done)).
- **Checks that must pass:** `test` (lint, static checks, unit and Lua tests)
  and `conventions` (the PR title and the branch name).
- **Merge** with **Squash and merge**. That's the only merge method enabled.

## Releases

Versions follow [semver](https://semver.org): a `feat` since the last release
means a minor bump, only `fix` or `perf` means a patch, and a breaking change
means a major bump.

1. Create `release/x.y.z` from `main`.
2. Set `"version"` in `manifest.json`, and add a dated `## x.y.z — YYYY-MM-DD`
   entry at the top of `CHANGELOG.md`.
3. Open a pull request titled `chore(release): x.y.z` and squash-merge it.
4. Tag the merge commit on `main` and push the tag:

   ```bash
   git switch main && git pull
   git tag -a vx.y.z -m "Glass Dock x.y.z"
   git push origin vx.y.z
   ```

### Hotfixes

For a released bug that can't wait:

1. Branch `hotfix/<topic>` from `main`.
2. Fix it in a `fix:` commit, and merge the pull request.
3. Release a patch straight away (`release/x.y.z+1`, as above).

## Local checks

`scripts/setup-dev.sh` enables two git hooks:

- **pre-commit** runs lint and the unit tests.
- **commit-msg** rejects messages that aren't Conventional Commits.

Check a title or branch name by hand:

```bash
node tests/tools/conventional.mjs title "feat(dock): add a show delay"
node tests/tools/conventional.mjs branch feat/show-delay
```

`git commit --no-verify` skips the hooks once, but CI still checks the pull
request.
