#!/usr/bin/env bash
# Link the portable configs in this checkout. No packages, builds or services run.
set -euo pipefail
DOTFILES="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
DRY_RUN=0
case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
    --help|-h) echo "Usage: $0 [--dry-run]"; exit 0 ;;
    '') ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "Expected at most one option" >&2; exit 2; }

link_config() {
    local src="$1" dst="$2" backup suffix=0
    [[ -e "$src" ]] || { printf '  [skip missing] %s\n' "$src"; return 0; }
    if [[ -L "$dst" && "$src" -ef "$dst" ]]; then
        printf '  [unchanged] %s\n' "$dst"
        return 0
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        backup="$dst.bak"
        while [[ -e "$backup" || -L "$backup" ]]; do
            ((suffix+=1))
            backup="$dst.bak.$suffix"
        done
        printf '  [backup] %s -> %s\n' "$dst" "$backup"
        if (( ! DRY_RUN )); then mv -T -- "$dst" "$backup"; fi
    fi
    printf '  [link] %s -> %s\n' "$dst" "$src"
    if (( ! DRY_RUN )); then
        mkdir -p -- "$(dirname -- "$dst")"
        ln -sT -- "$src" "$dst"
    fi
}

# These top-level directories are the current backup layout. Legacy .config
# entries remain usable only when there is no current counterpart.
configs=(quickshell quickshell-alt quickshell-mango hypr rofi kitty nvim swaync
         matugen waybar mpv uwsm gtk-3.0 gtk-4.0 wal wlogout)
declare -A managed=()
for name in "${configs[@]}"; do
    if [[ -d "$DOTFILES/$name" ]]; then
        managed["$name"]=1
        link_config "$DOTFILES/$name" "$CONFIG/$name"
    fi
done
shopt -s nullglob
for source in "$DOTFILES/.config/"*; do
    name="${source##*/}"
    [[ ${managed[$name]:-} == 1 ]] && continue
    # The current shell uses ~/.zshrc, not the archived ZDOTDIR setup.
    [[ "$name" == zsh && -f "$DOTFILES/zsh/.zshrc" ]] && continue
    link_config "$source" "$CONFIG/$name"
done
for source in "$DOTFILES/systemd/user/"*; do
    link_config "$source" "$CONFIG/systemd/user/${source##*/}"
done
link_config "$DOTFILES/.scripts" "$HOME/.scripts"
link_config "$DOTFILES/.themes/presets" "$HOME/.themes/presets"
link_config "$DOTFILES/icons/default/index.theme" "$HOME/.icons/default/index.theme"
for name in dwm slstatus; do
    link_config "$DOTFILES/$name" "$HOME/$name"
done
if [[ -f "$DOTFILES/zsh/.zshrc" ]]; then
    link_config "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
else
    link_config "$DOTFILES/.zshrc" "$HOME/.zshrc"
    link_config "$DOTFILES/.zshenv" "$HOME/.zshenv"
fi

if (( DRY_RUN )); then
    echo '==> Dry run complete; nothing changed.'
else
    echo '==> Configs linked. Existing files were backed up beside their originals.'
    echo '==> Start a new desktop session to load session settings and user services.'
    echo '==> Dependencies and dwm/slstatus builds are managed separately.'
fi
