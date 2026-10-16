#!/bin/bash
# Run the Glass Dock test suites.
#
#   scripts/test.sh            lint + static + unit + lua (fast, no desktop needed; what CI runs)
#   scripts/test.sh lint       formatters and linters for every language (scripts/lint.sh)
#   scripts/test.sh unit       Node unit tests for core/lib/*.mjs and repo contracts
#   scripts/test.sh lua        hypr/glassdock.lua against a fake Hyprland API
#   scripts/test.sh static     JS/Lua syntax, manifest, leftover debug output
#   scripts/test.sh e2e        live smoke test in a running Omarchy session
#                              (add --sync to install the working tree first)
#   scripts/test.sh all        everything above
#
# Needs: node >= 20, lua 5.4, qmllint (qt6-declarative), jq.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

bold=$'\e[1m' green=$'\e[32m' red=$'\e[31m' dim=$'\e[2m' reset=$'\e[0m'
[[ -t 1 ]] || bold="" green="" red="" dim="" reset=""

failed=()

run() {
  local name=$1
  shift
  echo "${bold}▶ $name${reset}"
  if "$@"; then
    echo "${green}✔ $name${reset}"
  else
    echo "${red}✘ $name${reset}"
    failed+=("$name")
  fi
  echo
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "${red}missing tool: $1${reset}" >&2
    return 1
  }
}

static_checks() {
  local ok=0

  echo "${dim}manifest${reset}"
  jq -e '.schemaVersion == 1 and (.id | test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and (.kinds | length > 0)' \
    manifest.json >/dev/null || {
    echo "manifest.json is invalid"
    ok=1
  }
  if command -v omarchy-plugin-validate >/dev/null 2>&1; then
    omarchy-plugin-validate . || ok=1
  else
    echo "  (omarchy-plugin-validate not installed; skipped)"
  fi

  echo "${dim}JavaScript modules${reset}"
  for f in core/lib/*.mjs tests/unit/*.mjs tests/tools/*.mjs; do
    node --check "$f" || ok=1
  done

  echo "${dim}Lua${reset}"
  luac -p hypr/glassdock.lua tests/lua/*.lua || ok=1

  echo "${dim}leftover debug output${reset}"
  if grep -rn --include='*.qml' --include='*.mjs' -E 'console\.(log|debug)|GDDEBUG' core ui GlassDock.qml; then
    echo "remove debug logging before committing"
    ok=1
  fi

  return $ok
}

unit_tests() { node --test tests/unit/; }
lua_tests() { lua tests/lua/glassdock_test.lua; }
lint_checks() { scripts/lint.sh; }
e2e_tests() { tests/e2e/smoke.sh "$@"; }

suite=${1:-default}
shift || true

case "$suite" in
  default)
    need node && need lua && need luac && need jq || exit 2
    run lint lint_checks
    run static static_checks
    run unit unit_tests
    run lua lua_tests
    ;;
  unit)
    need node || exit 2
    run unit unit_tests
    ;;
  lua)
    need lua || exit 2
    run lua lua_tests
    ;;
  static)
    need node && need luac && need jq || exit 2
    run static static_checks
    ;;
  lint)
    need node || exit 2
    run lint lint_checks
    ;;
  e2e) run e2e e2e_tests "$@" ;;
  all)
    need node && need lua && need luac && need jq || exit 2
    run lint lint_checks
    run static static_checks
    run unit unit_tests
    run lua lua_tests
    run e2e e2e_tests "$@"
    ;;
  *)
    echo "unknown suite: $suite (default|lint|unit|lua|static|e2e|all)" >&2
    exit 2
    ;;
esac

if ((${#failed[@]})); then
  echo "${red}${bold}failed: ${failed[*]}${reset}"
  exit 1
fi
echo "${green}${bold}all passed${reset}"
