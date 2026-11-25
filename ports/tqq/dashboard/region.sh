#!/bin/sh
set -eu
dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/deyra-shell
file="$dir/weather-city"
case "${1:-get}" in
 get) if [ -s "$file" ]; then cat "$file"; fi ;;
 set) city=${2:-}; [ -n "$city" ] && [ "${#city}" -le 120 ] || exit 2
      mkdir -p "$dir"; printf '%s\n' "$city" > "$file" ;;
 weather) [ -s "$file" ] || exit 0
          city=$(cat "$file"); encoded=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1],safe=""))' "$city"); exec curl --fail --silent --show-error --max-time 12 --get --data-urlencode "format=j1" "https://wttr.in/$encoded" ;;
 *) exit 2 ;;
esac
