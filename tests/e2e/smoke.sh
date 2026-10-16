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
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 1

id=$(jq -r .id manifest.json)
started=$(date "+%Y-%m-%d %H:%M:%S")
passed=0 failed=0

ok() {
  passed=$((passed + 1))
  echo "  ok   $1"
}
fail() {
  failed=$((failed + 1))
  echo "  FAIL $1${2:+ — $2}"
}
check() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi
}
pause() { perl -e "select(undef, undef, undef, $1)"; }
ipc() { omarchy-shell glassdock "$@"; }

# Whether monitor $1 has a mapped layer in namespace $2.
on_monitor() {
  hyprctl layers -j | jq -e --arg m "$1" --arg ns "$2" '.[$m].levels[] | any(.[]; .namespace == $ns)'
}

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
  command -v "$tool" >/dev/null || {
    echo "smoke: needs $tool (run inside an Omarchy session)"
    exit 2
  }
done
[[ -d ~/.config/omarchy/plugins/$id || ${1:-} == --sync ]] ||
  {
    echo "smoke: $id is not installed (use --sync)"
    exit 2
  }

echo "e2e smoke ($id)"

if [[ ${1:-} == --sync ]]; then
  if scripts/dev-sync.sh >/dev/null; then
    ok "installed working tree and restarted shell"
  else
    fail "dev-sync"
  fi
fi

# ---- loaded ------------------------------------------------------------------------

alive=0
for _ in $(seq 50); do
  [[ $(ipc ping 2>/dev/null) == ok ]] && {
    alive=1
    break
  }
  pause 0.2
done
if ((alive)); then
  ok "plugin answers IPC"
else
  fail "plugin answers IPC" "is it enabled? omarchy plugin enable $id"
  exit 1
fi

pause 1
warnings=$(journalctl --user --since "$started" --no-pager 2>/dev/null |
  grep -i "$id" | grep -v -E "IpcHandler|reloading" || true)
if [[ -z $warnings ]]; then
  ok "no shell warnings from the plugin"
else
  fail "no shell warnings from the plugin" "$(echo "$warnings" | head -3)"
fi

state=$(ipc state)
check "state is valid JSON" jq -e . <<<"$state"
config=$(ipc config)
check "config is valid JSON" jq -e . <<<"$config"
# Every key in the file is what the dock runs with (keys missing from an older
# file fall back to defaults, so only the file's keys are compared).
# shellcheck disable=SC2016 # $running is a jq variable
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
  mode=$(jq -r '.switcherDisplay // "focused"' <<<"$config")
  panels=1
  [[ $mode == all ]] && panels=$monitors
  ipc next
  check "Alt+Tab (next) opens the switcher ($mode: $panels panel(s))" wait_layers glassdock-switcher "$panels"
  if [[ $mode == primary ]]; then
    main=$(jq -r '.switcherMainDisplay // ""' <<<"$config")
    [[ -n $main ]] || main=$(hyprctl monitors -j | jq -r '.[0].name')
    check "it shows on the main display ($main)" on_monitor "$main" glassdock-switcher
  fi
  ipc nextWindow
  ipc prev
  check "stepping keeps it open" wait_layers glassdock-switcher "$panels"
  ipc cancel
  check "cancel closes it" wait_layers glassdock-switcher 0
  focus_after=$(hyprctl activewindow -j | jq -r .address)
  check "cancel leaves focus unchanged" test "$focus_before" = "$focus_after"
else
  ok "switcher: no windows open or switcher disabled, skipped"
fi

# ---- settings window ---------------------------------------------------------------

ipc openSettings
check "settings window opens" wait_layers glassdock-settings 1
ipc closeSettings
check "settings window closes" wait_layers glassdock-settings 0

# ---- force quit --------------------------------------------------------------------

# A throwaway terminal whose shell ignores TERM and HUP, i.e. one that a polite
# close can't end. Focus goes back to the window that had it.
probe_class=glassdock-e2e-probe
probe_alive() { hyprctl clients -j | jq -e --arg c "$probe_class" 'any(.[]; .class == $c)' >/dev/null; }
wait_probe() {
  local want=$1
  for _ in $(seq 1 40); do
    if probe_alive; then [[ $want == up ]] && return 0; else [[ $want == gone ]] && return 0; fi
    sleep 0.1
  done
  return 1
}
if command -v foot >/dev/null; then
  focus_before=$(hyprctl activewindow -j | jq -r '.address // empty')
  hyprctl dispatch "hl.dsp.exec_cmd(\"foot --app-id=$probe_class sh -c 'trap \\\"\\\" TERM HUP; sleep 60'\")" >/dev/null
  if wait_probe up; then
    probe_pid=$(hyprctl clients -j | jq -r --arg c "$probe_class" '.[] | select(.class == $c) | .pid')
    ipc forceQuit "$probe_class"
    check "forceQuit closes a window that ignores TERM" wait_probe gone
    check "forceQuit ends its process" bash -c "sleep 0.3; ! kill -0 $probe_pid 2>/dev/null"
  else
    check "force quit probe window opened" false
  fi
  [[ -n $focus_before ]] && hyprctl dispatch "hl.dsp.focus({ window = \"address:$focus_before\" })" >/dev/null
else
  ok "foot not installed: force quit not checked"
fi

# ---- Hyprland integration ----------------------------------------------------------

binds=$(hyprctl binds -j)
check "Alt+Tab is bound to Glass Dock" \
  jq -e 'any(.[]; .description == "Glass Dock: next app")' <<<"$binds"
check "Omarchy's Alt+Tab cycle_next is gone" \
  bash -c "jq -e 'all(.[]; .description != \"Focus on next window\")' <<<'$binds'"
if [[ $(jq -r '.toggleKey' <<<"$config") != "" ]]; then
  check "the show/hide key is bound" \
    jq -e 'any(.[]; .description == "Glass Dock: show or hide the dock")' <<<"$binds"
else
  ok "toggleKey is empty: show/hide bind not checked"
fi
# shellcheck disable=SC2016 # expanded by the inner bash
check "Hyprland config has no errors" bash -c '[[ -z $(hyprctl configerrors | tr -d "[:space:]") ]]'

echo
echo "$passed passed, $failed failed"
((failed == 0))
