#!/usr/bin/env bash
# purge-history.sh
# Removes shell history files from ~/dotfiles: the working tree AND all git history,
# then force-pushes the rewritten history. Never touches your live ~/.zsh_history
# or ~/.bash_history.
#
# Usage: purge-history.sh          dry run: lists what would be removed
#        purge-history.sh --yes    do it (local backup, rewrite history, force-push)

set -euo pipefail

DOTFILES="$HOME/dotfiles"
HISTORY_FILES=(.zsh_history .bash_history .zhistory .histfile .sh_history)
YES=0
[[ ${1:-} == "--yes" ]] && YES=1

is_history() {
  local p
  for p in "${HISTORY_FILES[@]}"; do
    [[ ${1##*/} == "$p" ]] && return 0
  done
  return 1
}

cd "$DOTFILES" || exit 1

# copies in the working tree (files or symlinks; .git skipped)
name_args=()
for p in "${HISTORY_FILES[@]}"; do name_args+=(-o -name "$p"); done
mapfile -t tree_files < <(find . -path ./.git -prune -o \( -type f -o -type l \) \( "${name_args[@]:1}" \) -print)

# every history path that ever appeared in any commit on any branch
hist_paths=()
while IFS= read -r f; do
  if [[ -n $f ]] && is_history "$f"; then hist_paths+=("$f"); fi
done < <(git log --all --name-only --pretty=format: | sort -u)

echo "Working-tree copies:"
if ((${#tree_files[@]})); then printf '  %s\n' "${tree_files[@]}"; else echo "  (none)"; fi
echo "Paths found in git history:"
if ((${#hist_paths[@]})); then printf '  %s\n' "${hist_paths[@]}"; else echo "  (none)"; fi

if ((${#tree_files[@]} + ${#hist_paths[@]} == 0)); then
  echo "Nothing to purge."
  exit 0
fi

if ((!YES)); then
  echo
  echo "Dry run. Re-run with --yes to delete these and rewrite git history."
  exit 0
fi

if ((${#hist_paths[@]})); then
  # filter-repo resets the working tree, which would discard uncommitted tracked changes
  if [[ -n $(git status --porcelain --untracked-files=no) ]]; then
    echo "Commit or stash your uncommitted changes first."
    exit 1
  fi
  command -v git-filter-repo >/dev/null || {
    echo "Install it first: sudo pacman -S git-filter-repo"
    exit 1
  }

  bak="$HOME/dotfiles.bak-$(date +%s)"
  cp -a "$DOTFILES" "$bak"
  echo "Backup: $bak (it still contains the history, so delete it when you're happy)"

  url=$(git remote get-url origin 2>/dev/null || true)
  branch=$(git branch --show-current)

  args=()
  for f in "${hist_paths[@]}"; do args+=(--path "$f"); done
  git filter-repo --force --invert-paths "${args[@]}"

  if [[ -n $url ]]; then
    git remote get-url origin &>/dev/null || git remote add origin "$url"
    git push --force --all origin
    git push --force --tags origin
    git branch --set-upstream-to="origin/$branch" "$branch" 2>/dev/null || true
  fi
fi

# leftover untracked copies in the working tree
if ((${#tree_files[@]})); then rm -f -- "${tree_files[@]}"; fi

echo "Done. Shell history removed from the working tree and git history."
