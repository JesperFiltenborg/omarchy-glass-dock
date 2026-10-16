#!/bin/bash
# One-time setup for working on Glass Dock: enables the git hooks and lists any
# missing tools.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

git config core.hooksPath .githooks
echo "git hooks enabled: pre-commit (lint + unit tests), commit-msg (Conventional Commits)"

missing=()
for tool in node lua luac jq rsync inotifywait shellcheck shfmt stylua luacheck biome; do
  command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
[[ -x /usr/lib/qt6/bin/qmllint ]] || missing+=("qmllint")

if ((${#missing[@]})); then
  declare -A package=([node]=nodejs [lua]=lua [luac]=lua [inotifywait]=inotify-tools [qmllint]=qt6-declarative)
  packages=()
  for tool in "${missing[@]}"; do packages+=("${package[$tool]:-$tool}"); done
  echo "missing: ${missing[*]}"
  echo "install: sudo pacman -S --needed $(printf '%s\n' "${packages[@]}" | sort -u | tr '\n' ' ')"
else
  echo "all tools present"
fi
