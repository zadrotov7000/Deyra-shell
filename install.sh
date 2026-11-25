#!/bin/sh
set -eu
cd "$(dirname "$0")"
config=${XDG_CONFIG_HOME:-"$HOME/.config"}
target="$config/quickshell/deyra"
state="$config/deyra-shell"
if ! command -v qs >/dev/null 2>&1; then
    printf '%s\n' "Install Quickshell (qs) with Wayland, PipeWire and Notifications support first." >&2
    exit 1
fi
mkdir -p "$target" "$state" "$state/upstream"
if [ -e "$target/shell.qml" ] || [ -L "$target/shell.qml" ]; then
    backup="$state/backups/$(date +%Y%m%d-%H%M%S)-$$"
    mkdir -p "$backup"
    cp -L "$target/shell.qml" "$backup/"
    printf 'Backup: %s\n' "$backup"
fi
mkdir -p "$target/ports"
cp -R ports/. "$target/ports/"
mkdir -p "$target/matugen"
install -m 644 matugen/config.toml "$target/matugen/config.toml"
if ! command -v matugen >/dev/null 2>&1; then
    printf '%s\n' "Optional dependency missing: matugen. Install it to enable wallpaper-based colors." >&2
fi
tmp=$(mktemp "$target/.shell.XXXXXX")
trap 'rm -f "$tmp"' EXIT HUP INT TERM
cat shell.qml > "$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$target/shell.qml"
printf '%s\n' "Installed Deyra Shell. Start from a Wayland session: qs -c deyra" "No existing rice, compositor config or packages were changed."
