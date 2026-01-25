#!/bin/bash

# RaspSetup v3 by Orwae Enterprise LLC
TITLE="RaspSetup v3"
BACKTITLE="Orwae Enterprise LLC | RaspSetup v3"

# --- Hàm hỗ trợ: Hiển thị thanh tiến trình theo thời gian thực ---
function run_with_progress {
  local cmd="$1"
  local msg="$2"
  local total_lines=0

  total_lines=$(eval "$cmd" | wc -l)

  if [[ $total_lines -gt 0 ]]; then
    eval "$cmd" 2>&1 | while IFS= read -r line; do
      current_line=$((current_line + 1))
      progress=$((current_line * 100 / total_lines))
      echo "$progress"
    done | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "$msg" 6 60 0
  else
    {
      echo 50
      eval "$cmd"
      echo 100
    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "$msg" 6 60 0
  fi
}

# --- Check & install whiptail if not available ---
if ! command -v whiptail >/dev/null 2>&1; then
  run_with_progress "sudo apt-get install -y whiptail" "Installing whiptail..."
fi

# --- Detect OS + Board Info ---
OS_INFO=$(lsb_release -d 2>/dev/null | awk -F"\t" '{print $2}' || echo "N/A")
BOARD_INFO=$(cat /proc/device-tree/model 2>/dev/null || echo "N/A")

# --- Step 1: Update ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "System: $OS_INFO\nDevice: $BOARD_INFO\n\nDo you want to update and upgrade the system now?" 15 60); then
  run_with_progress "sudo apt-get update && sudo apt-get upgrade -y" "Updating and upgrading system..."
fi

# --- Step 2: Install Apps ---
OPTIONS=(
  1 "Sysbench" OFF
  2 "Stress-ng" OFF
  3 "Neofetch" OFF
  4 "Pi-Apps" OFF
  5 "RealVNC" OFF
  6 "Pi-Hole" OFF
  7 "AdGuard Home" OFF
)

CHOICES=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" --checklist \
"Select applications to install (SPACE to select, ENTER to confirm):" 20 70 10 \
"${OPTIONS[@]}" 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
  for choice in $CHOICES; do
    case $choice in
      "\"1\"")
        if ! command -v sysbench >/dev/null 2>&1; then
          run_with_progress "sudo apt-get install sysbench -y" "Installing Sysbench..."
        fi
        ;;
      "\"2\"")
        if ! command -v stress-ng >/dev/null 2>&1; then
          run_with_progress "sudo apt-get install stress-ng -y" "Installing Stress-ng..."
        fi
        ;;
      "\"3\"")
        if ! command -v neofetch >/dev/null 2>&1; then
          run_with_progress "sudo apt-get install neofetch -y" "Installing Neofetch..."
        fi
        ;;
      "\"4\"")
        if [ ! -d "$HOME/pi-apps" ]; then
          run_with_progress "wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash" "Installing Pi-Apps..."
        fi
        ;;
      "\"5\"")
        if ! dpkg -l | grep -q realvnc-vnc-server; then
          run_with_progress "sudo apt-get install realvnc-vnc-server realvnc-vnc-viewer -y" "Installing RealVNC..."
        fi
        ;;
      "\"6\"")
        if ! command -v pihole >/dev/null 2>&1; then
          run_with_progress "curl -sSL https://install.pi-hole.net | bash" "Installing Pi-Hole..."
          whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Pi-Hole installed!\n\nUse command 'pihole -c' to open the configuration menu." 10 60
        fi
        ;;
      "\"7\"")
        if ! command -v adguardhome >/dev/null 2>&1; then
          run_with_progress "curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh" "Installing AdGuard Home..."
          whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "AdGuard Home installed!\n\nPlease open your web browser and go to http://<IP_ADDRESS>:3000 to configure." 10 60
        fi
        ;;
    esac
  done
fi

# --- Step 3: Raspi-config ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "Do you want to open raspi-config to configure SSH/VNC?" 10 60); then
  whiptail --title "$TITLE" --backtitle "$BACKTITLE" --infobox "Opening raspi-config..." 6 60
  sleep 2
  sudo raspi-config
fi

# --- Step 4: Completed ---
whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Installation Completed!\n\nPress OK to continue." 10 60

# --- Step 5: Reboot? ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "Do you want to reboot the system now?" 10 60); then
  whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "System will reboot now..." 10 60
  sudo reboot
else
  whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Exit script.\n\nYou can reboot manually later." 10 60
fi

clear
