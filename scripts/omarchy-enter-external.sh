#!/usr/bin/env bash
set -uo pipefail

mac_tailscale_ip=100.121.15.73

hyprctl_json() {
  local signature
  signature=$(basename "$(ls -td "/run/user/$(id -u)/hypr/"* 2>/dev/null | head -1)") || return 1
  HYPRLAND_INSTANCE_SIGNATURE=$signature hyprctl -j monitors
}

external_cursor_target() {
  jq -er '
    first(.[] | select(.name | startswith("eDP-") | not))
    | [
        (.x + (.width / .scale / 2) | floor),
        (.y + (.height / .scale / 2) | floor)
      ]
    | @tsv
  '
}

if [[ ${1:-} == --self-test ]]; then
  sample='[{"name":"eDP-1","x":0,"y":0,"width":2560,"height":1440,"scale":1.6},{"name":"DP-2","x":1600,"y":0,"width":2560,"height":1440,"scale":1}]'
  [[ $(external_cursor_target <<<"$sample") == $'2880\t720' ]]
  echo 'self-test passed'
  exit 0
fi

move_to_external() {
  local target x y signature
  target=$(hyprctl_json | external_cursor_target) || return 0
  read -r x y <<<"$target"
  signature=$(basename "$(ls -td "/run/user/$(id -u)/hypr/"* 2>/dev/null | head -1)") || return 0
  HYPRLAND_INSTANCE_SIGNATURE=$signature hyprctl dispatch movecursor "$x" "$y" >/dev/null
}

# ponytail: Lan Mouse has no enter hook; follow its stable INFO line until it
# exposes one. Matching Mac's Tailscale IP avoids reacting to other clients.
journalctl --user -u lan-mouse -f -n 0 -o cat | while IFS= read -r line; do
  if [[ $line == *"$mac_tailscale_ip"*" entered this device"* ]]; then
    move_to_external
  fi
done
