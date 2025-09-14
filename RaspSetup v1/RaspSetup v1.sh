#!/bin/bash

# RaspSetup v1 by Orwae Enterprise LLC
TITLE="RaspSetup Menu v1"
BACKTITLE="Orwae Enterprise LLC | RaspSetup v1"

# --- Progress bar: Initializing ---
{
    echo 10; sleep 1
    echo 30; sleep 1
    echo 60; sleep 1
    echo 100; sleep 1
} | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Initializing script..." 6 60 0

# --- Check & install whiptail if not available ---
if ! command -v whiptail >/dev/null 2>&1; then
    echo "Installing whiptail..." >/dev/null
    sudo apt-get install -y whiptail >/dev/null 2>&1
fi

# --- Detect OS + Board Info ---
OS_INFO=$(lsb_release -d 2>/dev/null | awk -F"\t" '{print $2}')
BOARD_INFO=$(cat /proc/device-tree/model 2>/dev/null)

# --- Step 1: Update ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "System: $OS_INFO\nDevice: $BOARD_INFO\n\nDo you want to update and upgrade the system now?" 15 60); then
    {
        echo 20
        sudo apt update >/dev/null 2>&1
        echo 60
        sudo apt upgrade -y >/dev/null 2>&1
        echo 100
    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Updating system..." 6 60 0
fi

# --- Step 2: Install Apps ---
OPTIONS=(
    1 "Sysbench" OFF
    2 "Stress-ng" OFF
    3 "Neofetch" OFF
    4 "Pi-Apps" OFF
    5 "RealVNC" OFF
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
                    {
                        echo 30
                        sudo apt install -y sysbench >/dev/null 2>&1
                        echo 100
                    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Installing Sysbench..." 6 60 0
                fi
                ;;
            "\"2\"")
                if ! command -v stress-ng >/dev/null 2>&1; then
                    {
                        echo 30
                        sudo apt install -y stress-ng >/dev/null 2>&1
                        echo 100
                    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Installing Stress-ng..." 6 60 0
                fi
                ;;
            "\"3\"")
                if ! command -v neofetch >/dev/null 2>&1; then
                    {
                        echo 30
                        sudo apt install -y neofetch >/dev/null 2>&1
                        echo 100
                    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Installing Neofetch..." 6 60 0
                fi
                ;;
            "\"4\"")
                if [ ! -d "$HOME/pi-apps" ]; then
                    {
                        echo 30
                        wget -qO- https://raw.githubusercontent.com/Botspot/pi-apps/master/install | bash >/dev/null 2>&1
                        echo 100
                    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Installing Pi-Apps..." 6 60 0
                fi
                ;;
            "\"5\"")
                if ! dpkg -l | grep -q realvnc-vnc-server; then
                    {
                        echo 30
                        sudo apt install -y realvnc-vnc-server realvnc-vnc-viewer >/dev/null 2>&1
                        echo 100
                    } | whiptail --title "$TITLE" --backtitle "$BACKTITLE" --gauge "Installing RealVNC..." 6 60 0
                fi
                ;;
        esac
    done
fi

# --- Step 3: Raspi-config ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "Do you want to open raspi-config to configure SSH/VNC?" 10 60); then
    sudo raspi-config >/dev/null 2>&1
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
