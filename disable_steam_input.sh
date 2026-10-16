#!/bin/bash
# Steam Deck Auto Disable Steam Controller - überarbeitete Version
# Basis: https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller (DBAD-Lizenz)
#
# Aufruf durch udev:  disable_steam_input.sh <disable|enable> <kernelname> <PRODUCT> [NAME...]
# NAME steht bewusst ganz hinten, weil er Leerzeichen enthalten kann und sonst die
# Argument-Positionen verschiebt (das war der "bad escaping"-Bug im Original).

set -u

tmp_dir="${SDADSC_TMP:-/tmp/scawp/SDADSC}"
usb_drv="${SDADSC_USB_DRV:-/sys/bus/usb/drivers/usbhid}"
# USB-Interfaces der eingebauten Deck-Controls (wie im Original)
deck_ifaces=("3-3:1.0" "3-3:1.1" "3-3:1.2")

mkdir -p "$tmp_dir"
log="$tmp_dir/debug.log"
id_file="$tmp_dir/controller_id.txt"

action="${1:-}"
kname="${2:-}"
product="${3:-}"
name="${*:4}"

echo "$(date +%T) action=$action kernel=$kname product=$product name=$name" >> "$log"

# --- Geräte ignorieren, die nicht "extern" sind ---------------------------------
case "$product" in
  3/28de/1205/*) echo "  -> Steam Deck Built-in, ignoriert" >> "$log"; exit 0 ;;
  3/28de/11ff/*) echo "  -> Steam Virtual 360 Pad, ignoriert" >> "$log"; exit 0 ;;
  11/1/1/ab83)   echo "  -> Steam Deck Virtual Keyboard, ignoriert" >> "$log"; exit 0 ;;
esac

[ -z "$kname" ] && exit 0

deck_ctl() { # $1 = bind | unbind
  local i
  for i in "${deck_ifaces[@]}"; do
    echo "$i" > "$usb_drv/$1" 2>>"$log" || true
  done
}

# Mehrere udev-Events laufen parallel (ein BT-Gerät erzeugt oft mehrere input-Nodes)
exec 9>"$tmp_dir/lock"
flock 9

if [ "$action" = "disable" ]; then
  first=0
  [ -s "$id_file" ] || first=1
  grep -qxF "$kname" "$id_file" 2>/dev/null || echo "$kname" >> "$id_file"
  if [ "$first" = 1 ]; then
    echo "  -> Deck-Controls AUS" >> "$log"
    deck_ctl unbind
  fi

elif [ "$action" = "enable" ]; then
  if [ -s "$id_file" ] && grep -qxF "$kname" "$id_file"; then
    grep -vxF "$kname" "$id_file" > "$id_file.new" || true
    mv "$id_file.new" "$id_file"
    if [ ! -s "$id_file" ]; then
      echo "  -> Deck-Controls AN" >> "$log"
      rm -f "$id_file"
      deck_ctl bind
    fi
  fi
fi

exit 0
