#!/bin/bash
#Steam Deck Auto Disable Steam Controller by scawp (Fork: Kritz0)
#License: DBAD: https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller/blob/main/LICENSE.md
#Source: https://github.com/scawp/Steam-Deck.Auto-Disable-Steam-Controller
# Use at own Risk!

#curl -sSL https://raw.githubusercontent.com/Kritz0/Steam-Deck.Auto-Disable-Steam-Controller/main/curl_install.sh | bash

#stop running script if anything returns an error (non-zero exit )
set -e

repo_url="https://raw.githubusercontent.com/Kritz0/Steam-Deck.Auto-Disable-Steam-Controller/main"

tmp_dir="/tmp/scawp.SDADSC.install"

rules_install_dir="/etc/udev/rules.d"
script_install_dir="/home/deck/.local/share/scawp/SDADSC"

# for debugging installer
#rules_install_dir="$tmp_dir/script"
#script_install_dir="$tmp_dir/script"

device_name="$(uname --nodename)"

if [ "$device_name" != "steamdeck" ] || [ "$(whoami)" != "deck" ]; then
  zenity --question --width=400 \
  --text="This code has been written specifically for the Steam Deck with user Deck \
  \nIt appears you are running on a different system/non-standard configuration. \
  \nAre you sure you want to continue?"
  if [ "$?" != 0 ]; then
    echo "bye then! xxx"
    exit 1;
  fi
fi

zenity --question --width=400 \
  --text="Read $repo_url/README.md before proceeding. \
\nDo you want to proceed?"
if [ "$?" != 0 ]; then
  echo "bye then! xxx"
  exit 0;
fi
echo "Making tmp folder $tmp_dir"
mkdir -p "$tmp_dir"

echo "Downloading Required Files"
curl -o "$tmp_dir/disable_steam_input.sh" "$repo_url/disable_steam_input.sh"

echo "Making script folder $script_install_dir"
mkdir -p "$script_install_dir"

echo "Copying $tmp_dir/disable_steam_input.sh to $script_install_dir/disable_steam_input.sh"
sudo cp "$tmp_dir/disable_steam_input.sh" "$script_install_dir/disable_steam_input.sh"

echo "Adding Execute and Removing Write Permissions"
sudo chmod 555 $script_install_dir/disable_steam_input.sh

#remove old installed files if found
if [ -d "$script_install_dir/conf" ]; then
  echo "deleting old install files"
  sudo rm -f "$script_install_dir/conf/simple_device_list.txt"
  sudo rm -d "$script_install_dir/conf"
fi
if [ -f "$rules_install_dir/99-disable-steam-input.rules" ]; then
  echo "Removing old rule"
  sudo rm "$rules_install_dir/99-disable-steam-input.rules"
fi

result=$(zenity --list \
  --title="What functionallity do you desire? Select any or all" \
  --checklist --column="Select" --width=840 --height=380 \
  --column="Device Type" --column="Description" \
    TRUE "Controller" "Disable Deck controls when connecting any USB or Bluetooth Controller (incl. Steam Controller 2 via Bluetooth)" \
    FALSE "Keyboard" "Disable Deck controls when connecting any USB or Bluetooth Keyboard" \
    FALSE "Mouse" "Disable Deck controls when connecting any USB or Bluetooth Mouse")

if [[ "$result" == "" ]]; then
  echo "None selected"
fi

# Argument order passed to the script: <action> <kernel name> <PRODUCT> <NAME>
script="$script_install_dir/disable_steam_input.sh"

add_rule() { # $1 = match expression
  echo "KERNEL==\"input*\", SUBSYSTEM==\"input\", $1, ACTION==\"add\", RUN+=\"$script disable %k %E{PRODUCT} %E{NAME}\"" | sudo tee -a "$rules_install_dir/99-disable-steam-input.rules"
  echo "KERNEL==\"input*\", SUBSYSTEM==\"input\", $1, ACTION==\"remove\", RUN+=\"$script enable %k %E{PRODUCT} %E{NAME}\"" | sudo tee -a "$rules_install_dir/99-disable-steam-input.rules"
}

if [[ "$result" =~ "Controller" ]]; then
  echo "Add Controller Rules"
  add_rule 'ENV{ID_INPUT_JOYSTICK}=="1"'
  # Valve devices over Bluetooth (e.g. Steam Controller 2) often show up only as generic
  # mouse/keyboard without kernel driver, so they never match ID_INPUT_JOYSTICK
  add_rule 'ENV{PRODUCT}=="5/28de/*"'
fi
if [[ "$result" =~ "Keyboard" ]]; then
  echo "Add Keyboard Rules"
  add_rule 'ENV{ID_INPUT_KEYBOARD}=="1"'
fi
if [[ "$result" =~ "Mouse" ]]; then
  echo "Add Mouse Rules"
  add_rule 'ENV{ID_INPUT_MOUSE}=="1"'
fi

echo "Reloading Services"
sudo udevadm control --reload

echo "Done."
