#!/bin/bash
# Live smoke test: drives the installed plugin in a running Omarchy session
# over IPC and checks the result through Hyprland.
#
#   tests/e2e/smoke.sh          test the installed plugin as it is
#   tests/e2e/smoke.sh --sync   install the working tree first (restarts the shell)
#
# Leaves things as it found them: it never commits a switch (no focus change),
# and closes everything it opens. Needs a Hyprland session with omarchy-shell.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

id=$(jq -r .id manifest.json)
started=$(date "+%Y-%m-%d %H:%M:%S")
passed=0 failed=0

ok() { passed=$((passed + 1)); echo "  ok   $1"; }
fail() { failed=$((failed + 1)); echo "  FAIL $1${2:+ — $2}"; }
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi; }
pause() { perl -e "select(undef, undef, undef, $1)"; }
ipc() { omarchy-shell glassdock "$@"; }

# Count layers in a namespace, waiting up to ~2s for it to reach $2.
layers() { hyprctl layers -j | jq "[.[] | .levels[] | .[] | select(.namespace == \"$1\")] | length"; }
wait_layers() {
  local ns=$1 want=$2 n
  for _ in $(seq 20); do
    n=$(layers "$ns")
    [[ $n == "$want" ]] && return 0
    pause 0.1
  done
  echo "    $ns: expected $want layer(s), found $n" >&2
  return 1
}

for tool in hyprctl omarchy-shell jq journalctl; do
  command -v "$tool" >/dev/null || { echo "smoke: needs $tool (run inside an Omarchy session)"; exit 2; }
done
[[ -d ~/.config/omarchy/plugins/$id || ${1:-} == --sync ]] \
  || { echo "smoke: $id is not installed (use --sync)"; exit 2; }

echo "e2e smoke ($id)"

if [[ ${1:-} == --sync ]]; then
  scripts/dev-sync.sh >/dev/null && ok "installed working tree and restarted shell" || fail "dev-sync"
fi

# ---- loaded ------------------------------------------------------------------------

alive=0
for _ in $(seq 50); do
  [[ $(ipc ping 2>/dev/null) == ok ]] && { alive=1; break; }
  pause 0.2
done
((alive)) && ok "plugin answers IPC" || { fail "plugin answers IPC" "is it enabled? omarchy plugin enable $id"; exit 1; }

pause 1
warnings=$(journalctl --user --since "$started" --no-pager 2>/dev/null \
  | grep -i "$id" | grep -v -E "IpcHandler|reloading" || true)
[[ -z $warnings ]] && ok "no shell warnings from the plugin" || fail "no shell warnings from the plugin" "$(echo "$warnings" | head -3)"

state=$(ipc state)
check "state is valid JSON" jq -e . <<<"$state"
config=$(ipc config)
check "config is valid JSON" jq -e . <<<"$config"
# Every key in the file is what the dock runs with (keys missing from an older
# file fall back to defaults, so only the file's keys are compared).
check "config matches the settings file" \
  jq -e --argjson running "$config" 'to_entries | all(.value == $running[.key])' ~/.config/omarchy/glassdock.json

# ---- docks -------------------------------------------------------------------------

monitors=$(hyprctl monitors -j | jq length)
wanted=$(jq '.monitors | length' <<<"$config")
expected=$((wanted > 0 ? wanted : monitors))
check "one dock per configured monitor ($expected)" wait_layers glassdock "$expected"

ipc hide
check "hide removes the docks" wait_layers glassdock 0
ipc show
check "show brings them back" wait_layers glassdock "$expected"

if [[ $(jq .overlay <<<"$config") == true ]]; then
  ok "overlay mode: reserved space not checked"
else
  check "dock reserves space at the bottom" \
    bash -c "hyprctl monitors -j | jq -e 'all(.[]; .reserved[3] > 0)'"
fi

# ---- switcher ----------------------------------------------------------------------

if [[ $(jq '.switcher | length' <<<"$state") -gt 0 && $(jq .switcher <<<"$config") == true ]]; then
  focus_before=$(hyprctl activewindow -j | jq -r .address)
  ipc next
  check "Alt+Tab (next) opens the switcher" wait_layers glassdock-switcher 1
  ipc nextWindow
  ipc prev
  check "stepping keeps it open" wait_layers glassdock-switcher 1
  ipc cancel
  check "cancel closes it" wait_layers glassdock-switcher 0
  focus_after=$(hyprctl activewindow -j | jq -r .address)
  [[ $focus_before == "$focus_after" ]] && ok "cancel leaves focus unchanged" || fail "cancel leaves focus unchanged"
else
  ok "switcher: no windows open or switcher disabled, skipped"
fi

# ---- settings window ---------------------------------------------------------------

ipc openSettings
check "settings window opens" wait_layers glassdock-settings 1
ipc closeSettings
check "settings window closes" wait_layers glassdock-settings 0

# ---- Hyprland integration ----------------------------------------------------------

binds=$(hyprctl binds -j)
check "Alt+Tab is bound to Glass Dock" \
  jq -e 'any(.[]; .description == "Glass Dock: next app")' <<<"$binds"
check "Omarchy's Alt+Tab cycle_next is gone" \
  bash -c "jq -e 'all(.[]; .description != \"Focus on next window\")' <<<'$binds'"
check "Hyprland config has no errors" bash -c '[[ -z $(hyprctl configerrors | tr -d "[:space:]") ]]'

echo
echo "$passed passed, $failed failed"
((failed == 0))
