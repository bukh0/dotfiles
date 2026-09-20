#!/usr/bin/env bash
# backup-dotfiles.sh
# Syncs selected configs into ~/dotfiles and pushes to bukh0/dotfiles.git
#
# Usage: ./backup-dotfiles.sh [--push | --restore]
#   (none)     sync live configs into the repo + git add
#   --push     also commit and push after syncing
#   --restore  reverse direction: copy repo files back to their live locations
#              (no --delete, no git). Use on a fresh install.

set -euo pipefail

DOTFILES="$HOME/dotfiles"
CONFIG="$HOME/.config"
#WALLPAPERS="$HOME/Pictures/Wallpapers"

# Shell history is never backed up: it is skipped in SYNC_MAP, excluded from rsync,
# kept in .gitignore, and unstaged before commit. To remove history that was already
# backed up (working tree + git history), run ~/.scripts/purge-history.sh
HISTORY_FILES=(.zsh_history .bash_history .zhistory .histfile .sh_history)

is_history() {
  local p
  for p in "${HISTORY_FILES[@]}"; do
    [[ ${1##*/} == "$p" ]] && return 0
  done
  return 1
}

HISTORY_EXCLUDES=()
for p in "${HISTORY_FILES[@]}"; do HISTORY_EXCLUDES+=(--exclude "$p"); done

MODE="backup"
if [ "${1:-}" == "--restore" ]; then MODE="restore"; fi

# --- Map of source -> destination inside dotfiles repo -----------------
# Add/remove lines here as your setup evolves.
declare -A SYNC_MAP=(
  ["$CONFIG/quickshell"]="$DOTFILES/quickshell"
  ["$CONFIG/quickshell-mango"]="$DOTFILES/quickshell-mango"
  ["$CONFIG/hypr"]="$DOTFILES/hypr"
  ["$CONFIG/rofi"]="$DOTFILES/rofi"
  ["$CONFIG/kitty"]="$DOTFILES/kitty"
  ["$CONFIG/nvim"]="$DOTFILES/nvim"
  ["$HOME/.zshrc"]="$DOTFILES/zsh/.zshrc"
  ["$CONFIG/swaync"]="$DOTFILES/swaync"
  ["$CONFIG/matugen"]="$DOTFILES/matugen"
  ["$CONFIG/waybar"]="$DOTFILES/waybar"

  # --- Session env, GTK and cursor settings ---
  ["$CONFIG/uwsm"]="$DOTFILES/uwsm"
  ["$CONFIG/gtk-3.0/settings.ini"]="$DOTFILES/gtk-3.0/settings.ini"
  ["$CONFIG/gtk-4.0/settings.ini"]="$DOTFILES/gtk-4.0/settings.ini"
  ["$HOME/.icons/default/index.theme"]="$DOTFILES/icons/default/index.theme"

  # --- Newly added theme architecture paths ---
  ["$HOME/.scripts"]="$DOTFILES/scripts"
  ["$CONFIG/wal"]="$DOTFILES/wal"
  ["$CONFIG/wlogout"]="$DOTFILES/wlogout"
  ["$CONFIG/vesktop/themes"]="$DOTFILES/vesktop/themes"

  #  ["$WALLPAPERS"]="$DOTFILES/Wallpapers"
)

# dwm: source lives at ~/dwm (own git repo, config.h baked into the binary
# at compile time, so we back up the source dir rather than a config file).
DWM_SRC="$HOME/dwm"
SYNC_MAP["$DWM_SRC"]="$DOTFILES/dwm"

# slstatus: same deal as dwm, suckless-style config.h compiled into the binary.
SLSTATUS_SRC="$HOME/slstatus"
SYNC_MAP["$SLSTATUS_SRC"]="$DOTFILES/slstatus"

echo "==> Ensuring dotfiles repo exists at $DOTFILES"
if [ ! -d "$DOTFILES/.git" ]; then
  echo "No git repo found at $DOTFILES. Clone it first:"
  echo "  git clone git@github.com:bukh0/dotfiles.git $DOTFILES"
  exit 1
fi

# Backup mirrors deletions into the repo; restore must never delete live files.
DELETE_FLAG=(--delete)
if [ "$MODE" == "restore" ]; then DELETE_FLAG=(); fi

echo "==> Syncing configs ($MODE)"
for entry in "${!SYNC_MAP[@]}"; do
  src="$entry"
  dest="${SYNC_MAP[$entry]}"
  if [ "$MODE" == "restore" ]; then
    src="${SYNC_MAP[$entry]}"
    dest="$entry"
  fi
  if is_history "$src"; then
    echo "  skipped (shell history): $src"
    continue
  fi
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dest")"
    if [ -d "$src" ]; then
      mkdir -p "$dest"
      rsync -av "${DELETE_FLAG[@]}" \
        "${HISTORY_EXCLUDES[@]}" \
        --exclude '.git' \
        --exclude '*.cache' \
        --exclude 'node_modules' \
        --exclude '*.o' \
        --exclude 'dwm' \
        --exclude 'slstatus' \
        --exclude '__pycache__' \
        "$src/" "$dest/"
    else
      cp -f "$src" "$dest"
    fi
    echo "  synced: $src -> $dest"
  else
    echo "  skipped (not found): $src"
  fi
done

if [ "$MODE" == "restore" ]; then
  echo "==> Restored from $DOTFILES. Log out and back in to apply."
  exit 0
fi

cd "$DOTFILES"

# Keep history files git-ignored (any depth).
for p in "${HISTORY_FILES[@]}"; do
  grep -qxF "$p" .gitignore 2>/dev/null || echo "$p" >> .gitignore
done

git add -A

# Fail-safe: unstage any history file that slipped through, warn if one is already tracked.
specs=()
for p in "${HISTORY_FILES[@]}"; do specs+=(":(glob)**/$p"); done
git reset -q -- "${specs[@]}" 2>/dev/null || true
tracked=$(git ls-files -- "${specs[@]}")
if [ -n "$tracked" ]; then
  echo "WARNING: shell history is tracked in git. Run ~/.scripts/purge-history.sh"
  echo "$tracked" | sed 's/^/  /'
fi

if [ "${1:-}" == "--push" ]; then
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  if git diff --cached --quiet; then
    echo "==> Nothing new to commit"
  else
    git commit -m "Backup configs: $ts"
  fi

  # Push only when local commits are ahead of the remote (covers commits left
  # over from prior runs, and doesn't try to push when the remote is ahead).
  git fetch origin --quiet || true
  AHEAD=$(git rev-list --count '@{u}..@' 2>/dev/null || echo 0)
  if [ "$AHEAD" -gt 0 ]; then
    git push
    echo "==> Pushed to remote"
  else
    echo "==> Nothing to push, already up to date with remote"
  fi
else
  echo "==> Synced and staged. Review with 'git status' / 'git diff --cached', then commit+push manually,"
  echo "    or re-run with --push to do it automatically."
fi
