#!/bin/bash
# Helpers for checking Glass Dock in a running Omarchy session, by hand or by
# an AI agent. Everything goes through Hyprland and the plugin's IPC.
#
#   scripts/dev-tools.sh layers [namespace]      Glass Dock layer surfaces (monitor, geometry)
#   scripts/dev-tools.sh shot <target> [out.png]  screenshot a layer namespace, a monitor
#                                                 name, or "dock" (the shelf area); prints the path
#   scripts/dev-tools.sh hover <x> <y>            move the pointer there (with a nudge, so Qt
#                                                 sees real motion and fires hover events)
#   scripts/dev-tools.sh away                     move the pointer to the middle of the focused
#                                                 monitor, away from the dock
#   scripts/dev-tools.sh dock-rect [monitor]      shelf position on screen: x y w h
#   scripts/dev-tools.sh logs [minutes]           plugin warnings from the shell log (default 5)
#   scripts/dev-tools.sh ipc <method> [arg]       omarchy-shell glassdock <method>
#   scripts/dev-tools.sh set <jq-filter>          edit ~/.config/omarchy/glassdock.json live,
#                                                 e.g. '.showOnHover=true'
#
# Screenshots land in ${GLASSDOCK_SHOTS:-/tmp/glassdock-shots}.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

id=$(jq -r .id manifest.json)
config=~/.config/omarchy/glassdock.json
shots=${GLASSDOCK_SHOTS:-/tmp/glassdock-shots}

pause() { perl -e "select(undef, undef, undef, $1)"; }
move() { hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })" >/dev/null; }

layers() {
  local ns=${1:-}
  hyprctl layers -j | jq -r --arg ns "$ns" '
    to_entries[] | .key as $mon | .value.levels | to_entries[] | .key as $lvl | .value[]
    | select(.namespace | startswith("glassdock")) | select($ns == "" or .namespace == $ns)
    | "\($mon)\tlevel=\($lvl)\t\(.namespace)\t\(.x),\(.y) \(.w)x\(.h)"'
}

# The shelf sits at the bottom centre of its layer; its exact width comes from
# the number of icons, so this is the area it can occupy.
dock_rect() {
  local mon=${1:-$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')}
  local size margin
  size=$(jq -r '.iconSize // 52' "$config")
  margin=$(jq -r '.margin // 10' "$config")
  hyprctl monitors -j | jq -r --arg m "$mon" --argjson s "$size" --argjson g "$margin" '
    .[] | select(.name == $m)
    | (.height - .reserved[3]) as $bottom
    | ($s + ($s * 0.4 | round)) as $shelf
    | "\(.x + (.width / 2 | floor) - 400) \(.y + $bottom - $g - $shelf) 800 \($shelf)"'
}

shot() {
  local target=${1:?target: layer namespace, monitor name or "dock"}
  local out=${2:-$shots/$target-$(date +%H%M%S).png}
  mkdir -p "$(dirname "$out")"
  pause 0.3
  if [[ $target == dock ]]; then
    read -r x y w h < <(dock_rect)
    grim -g "$x,$((y - 40)) ${w}x$((h + 40))" "$out"
  elif hyprctl monitors -j | jq -e --arg m "$target" 'any(.[]; .name == $m)' >/dev/null; then
    grim -o "$target" "$out"
  else
    local geom
    geom=$(layers "$target" | head -1 | cut -f4)
    [[ -n $geom ]] || {
      echo "no layer named $target (is it open?)" >&2
      exit 1
    }
    grim -g "$geom" "$out"
  fi
  echo "$out"
}

case "${1:-}" in
  layers) layers "${2:-}" ;;
  shot)
    shift
    shot "$@"
    ;;
  hover)
    move "$2" "$3"
    pause 0.05
    move "$(($2 + 1))" "$(($3 + 1))"
    ;;
  away)
    read -r x y < <(hyprctl monitors -j |
      jq -r '.[] | select(.focused) | "\(.x + .width / 2 | floor) \(.y + .height / 3 | floor)"')
    move "$x" "$y"
    ;;
  dock-rect) dock_rect "${2:-}" ;;
  logs)
    journalctl --user --since "${2:-5} min ago" --no-pager |
      grep -i "$id" | grep -v -E "IpcHandler|reloading" |
      sed -E 's/.*omarchy-shell\[[0-9]+\]: *//; s#file://[^ ]*/plugins/[^/]+/##' || true
    ;;
  ipc)
    shift
    omarchy-shell glassdock "$@"
    ;;
  set)
    tmp=$(mktemp)
    jq "$2" "$config" >"$tmp" && cat "$tmp" >"$config"
    rm -f "$tmp"
    pause 0.8
    jq -c . "$config"
    ;;
  *)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
