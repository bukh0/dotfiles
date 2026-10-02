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
if (( $# > 1 )); then
  echo "Error: expected at most one option." >&2
  echo "Usage: $0 [--push | --restore]" >&2
  exit 2
fi
case "${1:-}" in
  "")
    ;;
  --push)
    MODE="push"
    ;;
  --restore)
    MODE="restore"
    ;;
  --help|-h)
    sed -n '1,9p' "$0"
    exit 0
    ;;
  *)
    echo "Error: unknown option: $1" >&2
    echo "Usage: $0 [--push | --restore]" >&2
    exit 2
    ;;
esac

# --- Map of source -> destination inside dotfiles repo -----------------
# Add/remove lines here as your setup evolves.
declare -A SYNC_MAP=(
  ["$CONFIG/quickshell"]="$DOTFILES/quickshell"
  ["$CONFIG/quickshell-alt"]="$DOTFILES/quickshell-alt"
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

  # ~/.scripts is a symlink to $DOTFILES/.scripts, so it is already tracked
  # in this repository and must not be mirrored into a second scripts/ tree.
  ["$CONFIG/wal"]="$DOTFILES/wal"
  ["$CONFIG/wlogout"]="$DOTFILES/wlogout"

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

# Serialize the staged-change check, sync and commit as one operation.
exec 9>"$DOTFILES/.git/backup-dotfiles.lock"
flock -x 9

if [ "$MODE" != "restore" ] && ! git -C "$DOTFILES" diff --cached --quiet; then
  echo "Error: the repository already has staged changes." >&2
  echo "Review or commit them before running this script." >&2
  exit 1
fi

# Backup mirrors deletions into the repo; restore must never delete live files.
DELETE_FLAG=(--delete)
if [ "$MODE" == "restore" ]; then DELETE_FLAG=(); fi

echo "==> Syncing configs ($MODE)"
SYNCED_DESTS=()
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
    SYNCED_DESTS+=("$dest")
  else
    echo "  skipped (not found): $src"
  fi
done

if [ "$MODE" == "restore" ]; then
  if [[ -d "$DOTFILES/.scripts" && ! -e "$HOME/.scripts" && ! -L "$HOME/.scripts" ]]; then
    ln -sT -- "$DOTFILES/.scripts" "$HOME/.scripts"
    echo "  linked: $HOME/.scripts -> $DOTFILES/.scripts"
  fi
  echo "==> Restored from $DOTFILES. Log out and back in to apply."
  exit 0
fi

cd "$DOTFILES"

# Keep history files git-ignored (any depth).
for p in "${HISTORY_FILES[@]}"; do
  grep -qxF "$p" .gitignore 2>/dev/null || echo "$p" >> .gitignore
done

# Stage only files managed by this script. This prevents --push from
# committing unrelated work already present in the repository.
STAGE_PATHS=(.gitignore)
# These files already live in the repo, so rsync does not visit them.
# Include the scripts only when this is the live ~/.scripts directory.
if [[ -d "$HOME/.scripts" && -d "$DOTFILES/.scripts" && "$HOME/.scripts" -ef "$DOTFILES/.scripts" ]]; then
  STAGE_PATHS+=(.scripts)
fi
if [[ "$0" -ef "$DOTFILES/backup-dotfiles.sh" ]]; then
  STAGE_PATHS+=(backup-dotfiles.sh)
fi
for dest in "${SYNCED_DESTS[@]}"; do
  STAGE_PATHS+=("${dest#"$DOTFILES/"}")
done
git add -A -- "${STAGE_PATHS[@]}" ':(exclude,glob).scripts/*.o' ':(exclude,glob).scripts/*.d'

# Fail-safe: unstage any history file that slipped through, warn if one is already tracked.
specs=()
for p in "${HISTORY_FILES[@]}"; do specs+=(":(glob)**/$p"); done
git reset -q -- "${specs[@]}" 2>/dev/null || true
tracked=$(git ls-files -- "${specs[@]}")
if [ -n "$tracked" ]; then
  echo "WARNING: shell history is tracked in git. Run ~/.scripts/purge-history.sh"
  echo "$tracked" | sed 's/^/  /'
fi

if [ "$MODE" == "push" ]; then
  ts=$(date "+%Y-%m-%d %H:%M:%S")
  if git diff --cached --quiet; then
    echo "==> Nothing new to commit"
  else
    git commit -m "Backup configs: $ts"
  fi

  # Push only when local commits are ahead of the remote (covers commits left
  # over from prior runs, and doesn't try to push when the remote is ahead).
  if ! git fetch origin --quiet; then
    echo "Error: could not fetch origin; refusing to claim the remote is current." >&2
    exit 1
  fi

  if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo "Error: current branch has no upstream configured; refusing to push blindly." >&2
    exit 1
  fi

  AHEAD=$(git rev-list --count '@{u}..@')
  BEHIND=$(git rev-list --count '@..@{u}')
  if [ "$AHEAD" -gt 0 ]; then
    git push
    echo "==> Pushed to remote"
  elif [ "$BEHIND" -gt 0 ]; then
    echo "==> Nothing to push; local branch is $BEHIND commit(s) behind upstream"
  else
    echo "==> Nothing to push, already up to date with remote"
  fi
else
  echo "==> Synced and staged. Review with 'git status' / 'git diff --cached', then commit+push manually,"
  echo "    or use --push instead of a plain backup next time (requires an empty staging area)."
fi
