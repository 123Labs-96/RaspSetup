#!/bin/bash

# RaspSetup v4.8 by Orwae Enterprise LLC
#
# This script provides an interactive, menu‑driven installer for a variety
# of utilities and services on a Raspberry Pi.  It builds on previous
# versions (v4.7 and earlier) by simplifying the user interface,
# improving error handling and board detection, replacing the Neofetch
# option with Fastfetch, and providing more robust install routines for
# Node.js, Pi‑Hole and AdGuard Home.  The script also exposes the
# installed board model, operating system and available memory at
# startup, and uses consistent countdown gauges after successful
# installations.

# -------- Global variables --------
TITLE="RaspSetup v4"
BACKTITLE="Orwae Enterprise LLC | ${TITLE}"

# Colour definitions for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No colour

# -------- Helper: Clear the screen and print a header --------
show_header() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}   ${TITLE}   ${NC}"
    echo -e "${GREEN}=================================================${NC}"
    echo ""
}

# -------- Helper: Gauge countdown --------
# Display a gauge for a fixed number of seconds after a successful
# installation.  This gives the user visual feedback and allows
# sequential installations to proceed automatically without extra
# confirmations.
msg_countdown() {
    local app_name="$1"
    local seconds="${2:-6}"
    for ((i=1; i<=seconds; i++)); do
        local percent=$(( i * 100 / seconds ))
        local remaining=$(( seconds - i ))
        echo "$percent"
        echo -e "XXX\n\n${app_name} installed successfully!\n\nAuto‑continuing in ${remaining} seconds...\nXXX"
        sleep 1
    done | whiptail --title "Success" --gauge "Please wait..." 10 60 0
}

# -------- Helper: Display an error message --------
# Standardised error reporting so that all failures look the same.
msg_error() {
    local app_name="$1"
    local error_details="$2"
    whiptail --title "INSTALLATION FAILED" --msgbox "Error installing: ${app_name}\n\nDetails: ${error_details}\n\nPlease check your network or logs." 12 60
}

# -------- Helper: Attempt to repair dpkg --------
fix_dpkg() {
    if ! dpkg --configure -a > /dev/null 2>&1; then
        echo -e "${YELLOW}--- Checking for dpkg issues... ---${NC}"
        if sudo dpkg --configure -a; then
            echo -e "${GREEN}dpkg fixed successfully.${NC}"
            return 0
        else
            echo -e "${RED}Error: dpkg configuration failed.${NC}" >&2
            return 1
        fi
    fi
    return 0
}

# -------- Helper: Determine whether an app is already installed --------
# Each case statement checks for the existence of the relevant binary or
# package.  Returning success means the application is installed.
check_app_installed() {
    local app_name="$1"
    case "$app_name" in
        "sysbench")    command -v sysbench >/dev/null 2>&1 ;;
        "stress-ng")   command -v stress-ng >/dev/null 2>&1 ;;
        "fastfetch")   command -v fastfetch >/dev/null 2>&1 ;;
        "htop")        command -v htop >/dev/null 2>&1 ;;
        "node")        command -v node >/dev/null 2>&1 || command -v nodejs >/dev/null 2>&1 ;;
        "ufw")         command -v ufw >/dev/null 2>&1 ;;
        "fail2ban")    command -v fail2ban-client >/dev/null 2>&1 ;;
        "realvnc")     dpkg -s realvnc-vnc-server >/dev/null 2>&1 ;;
        "webmin")      dpkg -s webmin >/dev/null 2>&1 ;;
        "cockpit")     dpkg -s cockpit >/dev/null 2>&1 ;;
        "pi-apps")     [ -d "$HOME/pi-apps" ] ;;
        "pihole")      command -v pihole >/dev/null 2>&1 ;;
        "adguardhome") [ -d "/opt/AdGuardHome" ] && [ -x "/opt/AdGuardHome/AdGuardHome" ] ;;
        "filebrowser") command -v filebrowser >/dev/null 2>&1 || [ -f "/FileBrowser/filebrowser" ] ;;
        "openmediavault") dpkg -s openmediavault >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
    return $?
}

# -------- Helper: Update package lists --------
update_apt() {
    show_header
    echo -e "${YELLOW}--- Updating package lists... ---${NC}"
    if sudo apt-get update; then
        echo -e "${GREEN}Package lists updated successfully.${NC}"
        sleep 1
        return 0
    else
        echo -e "${RED}Failed to update package lists.${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi
}

# -------- Generic apt installer --------
# This helper installs the specified Debian packages via apt.  It will
# automatically call the countdown on success or show an error on
# failure.  It receives two parameters: the packages string and a
# human‑readable name used in UI messages.
install_via_apt() {
    local packages="$1"
    local app_name="$2"
    show_header
    echo -e "${YELLOW}--- Installing ${app_name}... ---${NC}"
    if sudo apt-get install -y --fix-missing ${packages}; then
        msg_countdown "${app_name}"
        return 0
    else
        msg_error "${app_name}" "Apt install failed."
        return 1
    fi
}

# -------- Specific: Install Cockpit --------
install_cockpit() {
    show_header
    echo -e "${YELLOW}--- Installing Cockpit (Web Admin)... ---${NC}"
    if sudo apt-get install -y cockpit; then
        sudo systemctl enable --now cockpit.socket
        local ip_addr=$(hostname -I | awk '{print $1}')
        whiptail --title "Cockpit Info" --infobox "Cockpit installed!\n\nAccess: https://${ip_addr}:9090\nUser: (your system user)\nPass: (your system password)" 10 60
        sleep 4
        msg_countdown "Cockpit"
        return 0
    else
        msg_error "Cockpit" "Installation failed via apt."
        return 1
    fi
}

# -------- Specific: Install OpenMediaVault (OMV) --------
install_omv() {
    show_header
    if whiptail --title "WARNING: OpenMediaVault Installation" --backtitle "${BACKTITLE}" --yesno "WARNING:\n\nOpenMediaVault (OMV) will take a long time to install.\n\nIMPORTANT: The system will AUTOMATICALLY REBOOT immediately after installation finishes.\n\nDo you want to proceed?" 15 70; then
        echo -e "${YELLOW}--- Installing OpenMediaVault... ---${NC}"
        echo -e "${RED}Do not turn off the power!${NC}"
        sleep 2
        wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash
        msg_countdown "OpenMediaVault"
        return 0
    else
        echo "OMV Installation cancelled by user."
        return 1
    fi
}

# -------- Specific: Install FileBrowser Quantum --------
install_filebrowser() {
    show_header
    local FB_MODE
    FB_MODE=$(whiptail --title "FileBrowser Installation Mode" --backtitle "${BACKTITLE}" --menu "Choose how to install FileBrowser:" 15 70 2 \
        "1" "Download Binary Only (Current Directory)" \
        "2" "Full Install (Service + /FileBrowser/Data)" 3>&1 1>&2 2>&3)
    local exit_status=$?
    if [ ${exit_status} -ne 0 ]; then return 1; fi
    local download_url="https://github.com/gtsteffaniak/filebrowser/releases/download/v1.0.3-stable/linux-arm64-filebrowser"
    if [ "${FB_MODE}" == "1" ]; then
        echo -e "${YELLOW}--- Downloading FileBrowser Binary... ---${NC}"
        if wget -O "filebrowser" "${download_url}"; then
            chmod +x "filebrowser"
            msg_countdown "FileBrowser Binary"
            return 0
        else
            msg_error "FileBrowser" "Download failed."
            return 1
        fi
    elif [ "${FB_MODE}" == "2" ]; then
        echo -e "${YELLOW}--- Installing FileBrowser Quantum (Full)... ---${NC}"
        if ! sudo mkdir -p /FileBrowser/Data; then
            msg_error "FileBrowser" "Failed to create directory /FileBrowser/Data"
            return 1
        fi
        local install_path="/FileBrowser/filebrowser"
        echo "Downloading binary to ${install_path}..."
        if sudo wget -O "${install_path}" "${download_url}"; then
            sudo chmod +x "${install_path}"
        else
            msg_error "FileBrowser" "Failed to download binary."
            return 1
        fi
        echo "Configuring Database..."
        local db_path="/FileBrowser/filebrowser.db"
        if [ ! -f "${db_path}" ]; then
            sudo "${install_path}" config init --database "${db_path}"
            sudo "${install_path}" config set --address "0.0.0.0" --port 8080 --root "/FileBrowser/Data" --database "${db_path}"
            sudo "${install_path}" users add admin admin --perm.admin --database "${db_path}" || echo "User might already exist"
        fi
        echo "Creating Systemd Service..."
        cat <<EOF | sudo tee /etc/systemd/system/filebrowser.service > /dev/null
[Unit]
Description=FileBrowser Quantum
After=network.target

[Service]
User=root
Group=root
ExecStart=${install_path} --database ${db_path}
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable filebrowser
        if sudo systemctl restart filebrowser; then
            msg_countdown "FileBrowser Quantum (Full)"
            return 0
        else
            msg_error "FileBrowser" "Failed to start service."
            return 1
        fi
    fi
}

# -------- Specific: Install Pi‑Apps --------
install_pi_apps() {
    show_header
    echo -e "${YELLOW}--- Installing Pi‑Apps... ---${NC}"
    local temp_script="$HOME/pi-apps-install-temp.sh"
    wget -qO "${temp_script}" https://raw.githubusercontent.com/Botspot/pi-apps/master/install
    chmod +x "${temp_script}"
    local run_user=${SUDO_USER:-${USER}}
    if sudo -u "${run_user}" "${temp_script}"; then
        rm -f "${temp_script}"
        msg_countdown "Pi‑Apps"
        return 0
    else
        msg_error "Pi‑Apps" "Installation script failed."
        rm -f "${temp_script}"
        return 1
    fi
}

# -------- Specific: Install Webmin --------
install_webmin() {
    show_header
    echo -e "${YELLOW}--- Installing Webmin... ---${NC}"
    sudo apt-get install -y wget curl gnupg apt-transport-https
    local setup_script="/tmp/webmin-setup-repo.sh"
    wget -qO "${setup_script}" https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
    chmod +x "${setup_script}"
    if sudo "${setup_script}"; then
        sudo apt-get install -y webmin
        msg_countdown "Webmin"
    else
        msg_error "Webmin" "Setup script failed."
    fi
    rm -f "${setup_script}"
}

# -------- Specific: Install Pi‑Hole (unattended) --------
install_pihole() {
    show_header
    echo -e "${YELLOW}--- Installing Pi‑Hole... ---${NC}"
    # Use the unattended flag to avoid interactive prompts.
    if curl -sSL https://install.pi-hole.net | sudo bash -s -- --unattended; then
        msg_countdown "Pi‑Hole"
    else
        msg_error "Pi‑Hole" "Installation failed."
    fi
}

# -------- Specific: Install AdGuard Home (quiet) --------
install_adguardhome() {
    show_header
    echo -e "${YELLOW}--- Installing AdGuard Home... ---${NC}"
    # Use the silent flag to prevent interactive prompts.
    if curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v --silent; then
        msg_countdown "AdGuard Home"
    else
        msg_error "AdGuard Home" "Installation failed."
    fi
}

# -------- Specific: Install Fastfetch --------
install_fastfetch() {
    show_header
    echo -e "${YELLOW}--- Installing Fastfetch... ---${NC}"
    # Attempt to install from apt first.  Some distributions provide
    # fastfetch packages in their repositories.  If apt fails, inform
    # the user; we could fall back to manual installation but that
    # requires a compiler and git, so we simply report failure.
    if sudo apt-get install -y fastfetch; then
        msg_countdown "Fastfetch"
        return 0
    else
        msg_error "Fastfetch" "Package not found or installation failed. Please install manually."
        return 1
    fi
}

# -------- Specific: Install Node.js & NPM --------
install_nodejs() {
    show_header
    echo -e "${YELLOW}--- Installing Node.js & NPM... ---${NC}"
    # Prefer NodeSource LTS script for up‑to‑date Node.js packages.  If
    # curl or the script fails then fall back to the distro packages.
    if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -; then
        if sudo apt-get install -y nodejs; then
            msg_countdown "Node.js & NPM"
            return 0
        fi
    fi
    # Fallback: install distro packages
    if sudo apt-get install -y nodejs npm; then
        msg_countdown "Node.js & NPM"
        return 0
    else
        msg_error "Node.js & NPM" "Installation failed."
        return 1
    fi
}

# -------- Optional: Configure Fail2Ban for Webmin --------
configure_fail2ban_for_webmin() {
    if ! check_app_installed "fail2ban"; then return 1; fi
    echo -e "${YELLOW}Configuring Fail2Ban for Webmin...${NC}"
    local jail_file="/etc/fail2ban/jail.local"
    if ! grep -q "^\[webmin\]" "${jail_file}" 2>/dev/null; then
        sudo touch "${jail_file}"
        sudo tee -a "${jail_file}" > /dev/null <<EOF

[webmin]
enabled = true
port = 10000
filter = webmin-auth
logpath = /var/webmin/miniserv.log
maxretry = 3
bantime = 600
EOF
        sudo mkdir -p "/etc/fail2ban/filter.d"
        sudo tee "/etc/fail2ban/filter.d/webmin-auth.conf" > /dev/null <<EOF
[Definition]
failregex = ^.*webmin - - \[.*\] "POST /session_login.cgi HTTP/1\.\..*" 403 .*\n+ignoreregex =
EOF
        sudo systemctl restart fail2ban
        msg_countdown "Fail2Ban Config for Webmin"
    fi
}

# ----------------------------------------------------------------------------
# MAIN SCRIPT STARTS HERE
# ----------------------------------------------------------------------------

# 1. Ensure whiptail is installed
if ! command -v whiptail >/dev/null 2>&1; then
    echo "Whiptail not found. Installing..."
    sudo apt-get update && sudo apt-get install -y whiptail
fi

# 2. Fix any dpkg issues before proceeding
fix_dpkg

# 3. Collect system information
# OS information
if command -v lsb_release >/dev/null 2>&1; then
    OS_INFO=$(lsb_release -d | cut -f2)
else
    OS_INFO="Linux Generic"
fi
# Board model information
if [ -f /sys/firmware/devicetree/base/model ]; then
    BOARD_MODEL=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
else
    BOARD_MODEL=$(grep 'Model' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
    [ -z "${BOARD_MODEL}" ] && BOARD_MODEL="Unknown Device"
fi
# RAM information
RAM_INFO=$(free -h | awk '/^Mem:/ {print $2}')

# 4. Offer to update/upgrade the system
MSG="OS: ${OS_INFO}\nModel: ${BOARD_MODEL}\nRAM: ${RAM_INFO}\n\nDo you want to UPDATE & UPGRADE the system now?\n\nSelect <No> to skip directly to App Install."
if whiptail --title "${TITLE}" --backtitle "${BACKTITLE}" --yesno "${MSG}" 18 70; then
    show_header
    echo -e "${YELLOW}--- Updating System... ---${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    msg_countdown "System Update"
else
    echo "Skipping system update."
fi

# 5. Main menu loop
while true; do
    # Define application options
    OPTIONS=(
        1 "Sysbench" OFF
        2 "Stress-ng" OFF
        3 "Fastfetch" OFF
        4 "Pi‑Apps" OFF
        5 "RealVNC" OFF
        6 "Htop" OFF
        7 "UFW Firewall" OFF
        8 "Node.js & NPM" OFF
        9 "Cockpit (Web Admin)" OFF
        10 "Webmin" OFF
        11 "Fail2Ban" OFF
        12 "Pi‑Hole" OFF
        13 "AdGuard Home" OFF
        14 "FileBrowser Quantum" OFF
        15 "OpenMediaVault (Auto Reboot)" OFF
    )
    CHOICES=$(whiptail --title "${TITLE}" --backtitle "${BACKTITLE}" \
        --checklist "Select applications to install (SPACE to select):" 22 80 14 \
        "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [ ${exit_status} -eq 0 ]; then
        if [ -z "${CHOICES}" ]; then
            whiptail --msgbox "No application selected." 10 60
        else
            for choice in ${CHOICES}; do
                choice=$(echo ${choice} | tr -d '"')
                case ${choice} in
                    1) check_app_installed "sysbench" || install_via_apt "sysbench" "Sysbench" ;;
                    2) check_app_installed "stress-ng" || install_via_apt "stress-ng" "Stress-ng" ;;
                    3) check_app_installed "fastfetch" || install_fastfetch ;;
                    4) check_app_installed "pi-apps" || install_pi_apps ;;
                    5) check_app_installed "realvnc" || install_via_apt "realvnc-vnc-server realvnc-vnc-viewer" "RealVNC" ;;
                    6) check_app_installed "htop" || install_via_apt "htop" "Htop" ;;
                    7) check_app_installed "ufw" || install_via_apt "ufw" "UFW Firewall" ;;
                    8) check_app_installed "node" || install_nodejs ;;
                    9) check_app_installed "cockpit" || install_cockpit ;;
                    10) check_app_installed "webmin" || install_webmin ;;
                    11)
                        if ! check_app_installed "fail2ban"; then
                            install_via_apt "fail2ban" "Fail2Ban"
                            # Ask to protect Webmin if both packages installed
                            if check_app_installed "webmin" && whiptail --title "${TITLE}" --yesno "Protect Webmin with Fail2Ban?" 10 60; then
                                configure_fail2ban_for_webmin
                            fi
                        fi
                        ;;
                    12) check_app_installed "pihole" || install_pihole ;;
                    13) check_app_installed "adguardhome" || install_adguardhome ;;
                    14) install_filebrowser ;;
                    15) install_omv ;;
                esac
            done
            # After all selected tasks complete, ask if user wishes to continue
            if whiptail --title "Queue Finished" --yesno "All selected tasks completed.\n\nProceed to System Configuration?" 10 60; then
                break
            fi
        fi
    else
        # Cancel pressed
        if whiptail --title "Exit Confirmation" --yesno "Do you really want to exit?" 10 60; then
            clear
            echo "Exiting RaspSetup. Goodbye!"
            exit 0
        fi
    fi
done

# 6. Open raspi-config
if whiptail --title "${TITLE}" --yesno "Open raspi-config for system settings (SSH, VNC, etc)?" 10 60; then
    sudo raspi-config
fi

# 7. Ask to reboot
if whiptail --title "${TITLE}" --yesno "Installation & Configuration finished. Reboot now?" 10 60; then
    sudo reboot
else
    clear
    echo "Setup finished. Please reboot manually later."
fi
