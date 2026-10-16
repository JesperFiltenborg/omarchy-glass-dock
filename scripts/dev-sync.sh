#!/bin/bash
# Copy the working tree into the Omarchy plugin directory and restart the
# shell so it loads the new code.
#
# Why a copy and a restart: the shell's file watcher does not follow symlinks,
# and its hot reload only re-reads the plugin entry file. Components imported
# from core/ and ui/ stay cached until the shell process restarts.
#
#   scripts/dev-sync.sh            sync + restart shell
#   scripts/dev-sync.sh --watch    sync + restart on every save (needs inotify-tools)
#   scripts/dev-sync.sh --no-restart

set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
id="$(jq -r .id "$src/manifest.json")"
dest="$HOME/.config/omarchy/plugins/$id"

sync_once() {
  mkdir -p "$dest"
  rsync -a --delete \
    --exclude .git --exclude .github --exclude .claude --exclude .githooks \
    --exclude scripts --exclude tests --exclude docs --exclude '*.md' --exclude LICENSE \
    "$src/" "$dest/"
  echo "synced → $dest"
}

restart() {
  omarchy-restart-shell >/dev/null 2>&1
  echo "shell restarted"
}

case "${1:-}" in
  --no-restart)
    sync_once
    ;;
  --watch)
    sync_once && restart
    echo "watching $src (ctrl+c to stop)"
    while inotifywait -qq -r -e close_write,create,delete,move --exclude '/\.git/' "$src"; do
      # Let editors finish multi-file saves before restarting.
      read -r -t 0.3 _ < <(inotifywait -qq -r -e close_write --exclude '/\.git/' "$src") || true
      sync_once && restart
    done
    ;;
  *)
    sync_once && restart
    ;;
esac
