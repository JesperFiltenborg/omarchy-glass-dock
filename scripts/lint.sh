#!/bin/bash
# Lint and format checks for every language in the repo.
#
#   scripts/lint.sh          check only (what CI and the pre-commit hook run)
#   scripts/lint.sh --fix    apply formatters and safe fixes, then check
#
# Tools (Arch packages shellcheck shfmt stylua luacheck biome; see docs/STYLE_GUIDE.md):
#   all files   tests/tools/check-style.mjs  whitespace, indentation, line length
#   QML         tests/tools/lint-qml.mjs     qmllint gate (qt6-declarative)
#   JavaScript  biome                         format + lint
#   Lua         stylua, luacheck              format, lint
#   Shell       shfmt, shellcheck             format, lint
#
# A missing tool is skipped with a warning. Set LINT_STRICT=1 (CI does) to
# make a missing tool an error.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

fix=0
[[ ${1:-} == --fix ]] && fix=1

# Every file list below comes from git. If git can't read the repo, the
# linters would get empty lists and "pass", so stop here instead.
if ! git ls-files --error-unmatch README.md >/dev/null; then
  echo "lint: git can't list the repo's files (see the error above)" >&2
  exit 1
fi

bold=$'\e[1m' green=$'\e[32m' red=$'\e[31m' yellow=$'\e[33m' reset=$'\e[0m'
[[ -t 1 ]] || bold="" green="" red="" yellow="" reset=""

failed=() skipped=()

step() {
  local name=$1
  shift
  if "$@"; then
    echo "${green}✔${reset} $name"
  else
    echo "${red}✘ $name${reset}"
    failed+=("$name")
  fi
}

have() {
  if command -v "$1" >/dev/null 2>&1; then return 0; fi
  echo "${yellow}– $2: $1 not installed, skipped${reset}"
  skipped+=("$1")
  return 1
}

shell_files() {
  git ls-files --cached --others --exclude-standard -- 'scripts/*' '.githooks/*' 'tests/e2e/*' |
    while read -r f; do [[ -f $f ]] && head -1 "$f" | grep -q '^#!.*\(ba\)\?sh' && echo "$f"; done
}
lua_files() { git ls-files --cached --others --exclude-standard -- '*.lua' '.luacheckrc'; }

mapfile -t sh < <(shell_files)
mapfile -t lua < <(lua_files)

if ((fix)); then
  node tests/tools/check-style.mjs --fix >/dev/null
  command -v biome >/dev/null && biome check --write --no-errors-on-unmatched . >/dev/null 2>&1
  command -v stylua >/dev/null && stylua "${lua[@]}"
  command -v shfmt >/dev/null && shfmt -w "${sh[@]}"
fi

step "style (whitespace, indentation, line length)" node tests/tools/check-style.mjs
step "QML (qmllint gate)" node tests/tools/lint-qml.mjs >/dev/null

if have biome "JavaScript"; then
  step "JavaScript (biome format + lint)" biome check --no-errors-on-unmatched .
fi
if have stylua "Lua format"; then
  step "Lua format (stylua)" stylua --check "${lua[@]}"
fi
if have luacheck "Lua lint"; then
  step "Lua lint (luacheck)" luacheck --quiet "${lua[@]}"
fi
if have shfmt "shell format"; then
  step "shell format (shfmt)" shfmt -d "${sh[@]}"
fi
if have shellcheck "shell lint"; then
  step "shell lint (shellcheck)" shellcheck "${sh[@]}"
fi

if ((${#skipped[@]})) && [[ ${LINT_STRICT:-0} == 1 ]]; then
  failed+=("missing tools: ${skipped[*]}")
fi

echo
if ((${#failed[@]})); then
  echo "${red}${bold}lint failed:${reset} ${failed[*]}"
  ((fix)) || echo "try: scripts/lint.sh --fix"
  exit 1
fi
if ((${#skipped[@]})); then
  echo "${yellow}lint passed, but skipped: ${skipped[*]}${reset}"
  echo "the Arch packages are: shellcheck shfmt stylua luacheck biome (see docs/STYLE_GUIDE.md)"
else
  echo "${green}${bold}lint passed${reset}"
fi
