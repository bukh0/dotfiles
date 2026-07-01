#!/usr/bin/env bash
# backup-dotfiles.sh
# Syncs selected configs into ~/dotfiles and pushes to bukh0/dotfiles.git
#
# Usage: ./backup-dotfiles.sh [--push]
#   --push   also commit and push after syncing (default: just sync + git add)

set -euo pipefail

DOTFILES="$HOME/dotfiles"
CONFIG="$HOME/.config"

# --- Map of source -> destination inside dotfiles repo -----------------
# Add/remove lines here as your setup evolves.
declare -A SYNC_MAP=(
  ["$CONFIG/quickshell"]="$DOTFILES/quickshell"
  ["$CONFIG/quickshell-mango"]="$DOTFILES/quickshell-mango"
  ["$CONFIG/hypr"]="$DOTFILES/hypr"
  ["$CONFIG/rofi"]="$DOTFILES/rofi"
  ["$CONFIG/kitty"]="$DOTFILES/kitty"
  ["$CONFIG/nvim"]="$DOTFILES/nvim"
  ["$CONFIG/zsh"]="$DOTFILES/zsh"
  ["$HOME/.zshrc"]="$DOTFILES/zsh/.zshrc"
  ["$CONFIG/swaync"]="$DOTFILES/swaync"
  ["$CONFIG/matugen"]="$DOTFILES/matugen"
)

# dwm: adjust this path to wherever your dwm source lives.
# Since dwm bakes config.h into the binary, we back up the whole source dir.
DWM_SRC="$HOME/.local/src/dwm"
SYNC_MAP["$DWM_SRC"]="$DOTFILES/dwm"

echo "==> Ensuring dotfiles repo exists at $DOTFILES"
if [ ! -d "$DOTFILES/.git" ]; then
  echo "No git repo found at $DOTFILES. Clone it first:"
  echo "  git clone git@github.com:bukh0/dotfiles.git $DOTFILES"
  exit 1
fi

echo "==> Syncing configs"
for src in "${!SYNC_MAP[@]}"; do
  dest="${SYNC_MAP[$src]}"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dest")"
    if [ -d "$src" ]; then
      mkdir -p "$dest"
      rsync -av --delete \
        --exclude '.git' \
        --exclude '*.cache' \
        --exclude 'node_modules' \
        "$src/" "$dest/"
    else
      cp -f "$src" "$dest"
    fi
    echo "  synced: $src -> $dest"
  else
    echo "  skipped (not found): $src"
  fi
done

cd "$DOTFILES"
git add -A

if [ "${1:-}" == "--push" ]; then
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  if git diff --cached --quiet; then
    echo "==> Nothing new to commit"
  else
    git commit -m "Backup configs: $ts"
    git push
    echo "==> Pushed to remote"
  fi
else
  echo "==> Synced and staged. Review with 'git status' / 'git diff --cached', then commit+push manually,"
  echo "    or re-run with --push to do it automatically."
fi
