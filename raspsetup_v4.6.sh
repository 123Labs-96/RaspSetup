#!/bin/bash
# KHÔNG sử dụng set -e để tránh thoát sớm do các lệnh kiểm tra thất bại

# --- Biến toàn cục ---
TITLE="RaspSetup v4.6"
BACKTITLE="Orwae Enterprise LLC | RaspSetup v4.6"

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Hàm: Hiển thị Header ---
show_header() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}   $TITLE   ${NC}"
    echo -e "${GREEN}=================================================${NC}"
    echo ""
}

# --- Hàm: Kiểm tra và sửa lỗi dpkg ---
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

# --- Hàm: Kiểm tra ứng dụng đã cài ---
check_app_installed() {
    local app_name="$1"
    case "$app_name" in
        "sysbench") command -v sysbench >/dev/null 2>&1 ;;
        "stress-ng") command -v stress-ng >/dev/null 2>&1 ;;
        "neofetch") command -v neofetch >/dev/null 2>&1 ;;
        "htop") command -v htop >/dev/null 2>&1 ;;
        "node") command -v node >/dev/null 2>&1 || command -v nodejs >/dev/null 2>&1 ;;
        "ufw") command -v ufw >/dev/null 2>&1 ;;
        "fail2ban") command -v fail2ban-client >/dev/null 2>&1 ;;
        "realvnc") dpkg -s realvnc-vnc-server >/dev/null 2>&1 ;;
        "webmin") dpkg -s webmin >/dev/null 2>&1 ;;
        "pi-apps") [ -d "$HOME/pi-apps" ] ;;
        "pihole") command -v pihole >/dev/null 2>&1 ;;
        "adguardhome") [ -d "/opt/AdGuardHome" ] && [ -x "/opt/AdGuardHome/AdGuardHome" ] ;;
        "filebrowser") command -v filebrowser >/dev/null 2>&1 || [ -f "/FileBrowser/filebrowser" ] ;;
        "openmediavault") dpkg -s openmediavault >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
    return $?
}

# --- Hàm: Cập nhật apt ---
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

# --- Hàm: Cài đặt ứng dụng qua apt (Đã Fix Debug) ---
install_via_apt() {
    local packages="$1"
    local app_name="$2"
    
    show_header
    echo -e "${YELLOW}--- Installing $app_name... ---${NC}"
    
    # Thêm -y để auto confirm và --fix-missing để sửa lỗi gói tin
    if sudo apt-get install -y --fix-missing $packages; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "$app_name has been installed successfully." 10 60
        return 0
    else
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to install $app_name.\n\nPlease check your internet or package lists." 10 60
        return 1
    fi
}

# --- Hàm: Cài đặt OpenMediaVault (OMV) ---
install_omv() {
    show_header
    # Hộp thoại Cảnh báo quan trọng
    if whiptail --title "WARNING: OpenMediaVault Installation" --backtitle "$BACKTITLE" --yesno "WARNING:\n\nOpenMediaVault (OMV) will take a long time to install.\n\nIMPORTANT: The system will AUTOMATICALLY REBOOT immediately after installation finishes.\n\nDo you want to proceed?" 15 70; then
        echo -e "${YELLOW}--- Installing OpenMediaVault... ---${NC}"
        echo -e "${RED}Do not turn off the power!${NC}"
        sleep 2
        
        # Chạy lệnh cài đặt OMV
        wget -O - https://github.com/OpenMediaVault-Plugin-Developers/installScript/raw/master/install | sudo bash
        
        # Lưu ý: Script trên thường sẽ tự reboot máy khi xong.
        # Nếu script OMV không tự reboot, ta sẽ dừng script tại đây
        return 0
    else
        echo "OMV Installation cancelled by user."
        return 1
    fi
}

# --- Hàm: Cài đặt FileBrowser Quantum ---
install_filebrowser() {
    show_header
    local FB_MODE
    FB_MODE=$(whiptail --title "FileBrowser Installation Mode" --backtitle "$BACKTITLE" --menu "Choose how to install FileBrowser:" 15 70 2 \
        "1" "Download Binary Only (Current Directory)" \
        "2" "Full Install (Service + /FileBrowser/Data)" 3>&1 1>&2 2>&3)
    
    local exit_status=$?
    if [ $exit_status -ne 0 ]; then return 1; fi 

    local download_url="https://github.com/gtsteffaniak/filebrowser/releases/download/v1.0.3-stable/linux-arm64-filebrowser"

    if [ "$FB_MODE" == "1" ]; then
        echo -e "${YELLOW}--- Downloading FileBrowser Binary... ---${NC}"
        if wget -O "filebrowser" "$download_url"; then
            chmod +x "filebrowser"
            local current_dir=$(pwd)
            whiptail --title "$TITLE" --msgbox "Downloaded successfully!\n\nLocation: $current_dir/filebrowser\n\nRun it with: ./filebrowser" 12 60
            return 0
        else
             whiptail --title "$TITLE" --msgbox "Download failed." 10 60
             return 1
        fi
    elif [ "$FB_MODE" == "2" ]; then
        echo -e "${YELLOW}--- Installing FileBrowser Quantum (Full)... ---${NC}"
        if ! sudo mkdir -p /FileBrowser/Data; then
            whiptail --title "$TITLE" --msgbox "Failed to create directory /FileBrowser/Data" 10 60
            return 1
        fi
        local install_path="/FileBrowser/filebrowser"
        echo "Downloading binary to $install_path..."
        if sudo wget -O "$install_path" "$download_url"; then
            sudo chmod +x "$install_path"
        else
            whiptail --title "$TITLE" --msgbox "Failed to download FileBrowser." 10 60
            return 1
        fi
        echo "Configuring Database..."
        local db_path="/FileBrowser/filebrowser.db"
        if [ ! -f "$db_path" ]; then
            sudo "$install_path" config init --database "$db_path"
            sudo "$install_path" config set --address "0.0.0.0" --port 8080 --root "/FileBrowser/Data" --database "$db_path"
            sudo "$install_path" users add admin admin --perm.admin --database "$db_path" || echo "User might already exist"
        fi
        echo "Creating Systemd Service..."
        cat <<EOF | sudo tee /etc/systemd/system/filebrowser.service
[Unit]
Description=FileBrowser Quantum
After=network.target

[Service]
User=root
Group=root
ExecStart=$install_path --database $db_path
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable filebrowser
        if sudo systemctl restart filebrowser; then
            local ip_addr=$(hostname -I | awk '{print $1}')
            whiptail --title "$TITLE" --msgbox "FileBrowser installed successfully!\n\nStructure:\n- Binary: /FileBrowser/filebrowser\n- Data:   /FileBrowser/Data\n\nAccess: http://$ip_addr:8080\nLogin: admin / admin" 15 60
            return 0
        else
            whiptail --title "$TITLE" --msgbox "Failed to start FileBrowser service." 10 60
            return 1
        fi
    fi
}

# --- Các hàm cài đặt Script khác ---
install_pi_apps() {
    show_header
    echo -e "${YELLOW}--- Installing Pi-Apps... ---${NC}"
    local temp_script="$HOME/pi-apps-install-temp.sh"
    wget -qO "$temp_script" https://raw.githubusercontent.com/Botspot/pi-apps/master/install
    chmod +x "$temp_script"
    local run_user=${SUDO_USER:-$USER}
    if sudo -u "$run_user" "$temp_script"; then
        whiptail --title "$TITLE" --msgbox "Pi-Apps installed successfully." 10 60
        rm -f "$temp_script"
        return 0
    else
        whiptail --title "$TITLE" --msgbox "Pi-Apps installation failed." 10 60
        rm -f "$temp_script"
        return 1
    fi
}

install_webmin() {
    show_header
    echo -e "${YELLOW}--- Installing Webmin... ---${NC}"
    sudo apt-get install -y wget curl gnupg apt-transport-https
    local setup_script="/tmp/webmin-setup-repo.sh"
    wget -qO "$setup_script" https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
    chmod +x "$setup_script"
    if sudo "$setup_script"; then
        sudo apt-get install -y webmin
        local ip_addr=$(hostname -I | awk '{print $1}')
        whiptail --title "$TITLE" --msgbox "Webmin installed!\nURL: https://$ip_addr:10000" 12 60
    else
         whiptail --title "$TITLE" --msgbox "Webmin setup script failed." 10 60
    fi
    rm -f "$setup_script"
}

install_pihole() {
    show_header
    echo -e "${YELLOW}--- Installing Pi-Hole... ---${NC}"
    curl -sSL https://install.pi-hole.net | bash
    if [ $? -eq 0 ]; then
        whiptail --title "$TITLE" --msgbox "Pi-Hole installation finished." 10 60
    else
        whiptail --title "$TITLE" --msgbox "Pi-Hole installation failed." 10 60
    fi
}

install_adguardhome() {
    show_header
    echo -e "${YELLOW}--- Installing AdGuard Home... ---${NC}"
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    if [ $? -eq 0 ]; then
        local ip_addr=$(hostname -I | awk '{print $1}')
        whiptail --title "$TITLE" --msgbox "AdGuard Home installed!\nConfigure at: http://$ip_addr:3000" 12 60
    else
        whiptail --title "$TITLE" --msgbox "AdGuard Home installation failed." 10 60
    fi
}

configure_fail2ban_for_webmin() {
    if ! check_app_installed "webmin"; then return 1; fi
    echo -e "${YELLOW}Configuring Fail2Ban for Webmin...${NC}"
    local jail_file="/etc/fail2ban/jail.local"
    if ! grep -q "^\[webmin\]" "$jail_file" 2>/dev/null; then
        sudo touch "$jail_file"
        sudo tee -a "$jail_file" > /dev/null <<EOF

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
failregex = ^.*webmin - - \[.*\] "POST /session_login.cgi HTTP/1\..*" 403 .*
ignoreregex =
EOF
        sudo systemctl restart fail2ban
        whiptail --title "$TITLE" --msgbox "Fail2Ban configured for Webmin." 10 60
    fi
}

# ==============================================================================
# MAIN SCRIPT STARTS HERE
# ==============================================================================

# 1. Kiểm tra Whiptail
if ! command -v whiptail >/dev/null 2>&1; then
    echo "Whiptail not found. Installing..."
    sudo apt-get update && sudo apt-get install -y whiptail
fi

# 2. Fix dpkg đầu vào
fix_dpkg

# 3. Thông tin hệ thống
# --- OS Info ---
if command -v lsb_release >/dev/null 2>&1; then
    OS_INFO=$(lsb_release -d | cut -f2)
else
    OS_INFO="Linux Generic"
fi

# --- Board Model Info ---
if [ -f /sys/firmware/devicetree/base/model ]; then
    BOARD_MODEL=$(tr -d '\0' < /sys/firmware/devicetree/base/model)
else
    BOARD_MODEL=$(cat /proc/cpuinfo | grep 'Model' | head -1 | cut -d: -f2 | xargs)
    if [ -z "$BOARD_MODEL" ]; then BOARD_MODEL="Unknown Device"; fi
fi

# --- RAM Info ---
RAM_INFO=$(free -h | awk '/^Mem:/ {print $2}')

# 4. Hỏi Update hệ thống
MSG="OS: $OS_INFO\nModel: $BOARD_MODEL\nRAM: $RAM_INFO\n\nDo you want to UPDATE & UPGRADE the system now?\n\nSelect <No> to skip directly to App Install."

if whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "$MSG" 18 70; then
    show_header
    echo -e "${YELLOW}--- Updating System... ---${NC}"
    sudo apt-get update && sudo apt-get upgrade -y
    whiptail --title "$TITLE" --msgbox "System update completed." 10 60
else
    echo "Skipping system update."
fi

# 5. Menu chọn ứng dụng (Logic vòng lặp chính)
while true; do
    # Danh sách ứng dụng
    # Lưu ý: OpenMediaVault (14) phải nằm cuối cùng vì nó sẽ reboot máy
    OPTIONS=(
        1 "Sysbench" OFF
        2 "Stress-ng" OFF
        3 "Neofetch" OFF
        4 "Pi-Apps" OFF
        5 "RealVNC" OFF
        6 "Htop" OFF
        7 "UFW Firewall" OFF
        8 "Node.js & NPM" OFF
        9 "Webmin" OFF
        10 "Fail2ban" OFF
        11 "Pi-Hole" OFF
        12 "AdGuard Home" OFF
        13 "FileBrowser Quantum" OFF
        14 "OpenMediaVault (Auto Reboot)" OFF
    )

    CHOICES=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" \
        --checklist "Select applications to install (SPACE to select):" 22 75 14 \
        "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
    
    # Lấy mã thoát (Exit status) của Whiptail
    # 0 = OK, 1 = Cancel
    exit_status=$?

    if [ $exit_status -eq 0 ]; then
        # --- NGƯỜI DÙNG CHỌN OK ---
        if [ -z "$CHOICES" ]; then
            whiptail --msgbox "No application selected." 10 60
        else
            # Xử lý từng lựa chọn
            for choice in $CHOICES; do
                choice=$(echo $choice | tr -d '"') # Xóa dấu ngoặc kép
                case $choice in
                    1) check_app_installed "sysbench" || install_via_apt "sysbench" "Sysbench" ;;
                    2) check_app_installed "stress-ng" || install_via_apt "stress-ng" "Stress-ng" ;;
                    3) check_app_installed "neofetch" || install_via_apt "neofetch" "Neofetch" ;;
                    4) check_app_installed "pi-apps" || install_pi_apps ;;
                    5) check_app_installed "realvnc" || install_via_apt "realvnc-vnc-server realvnc-vnc-viewer" "RealVNC" ;;
                    6) check_app_installed "htop" || install_via_apt "htop" "Htop" ;;
                    7) check_app_installed "ufw" || install_via_apt "ufw" "UFW Firewall" ;;
                    8) check_app_installed "node" || install_via_apt "nodejs npm" "Node.js and NPM" ;;
                    9) check_app_installed "webmin" || install_webmin ;;
                    10) 
                        if ! check_app_installed "fail2ban"; then
                            install_via_apt "fail2ban" "Fail2ban"
                            if check_app_installed "webmin" && (whiptail --title "$TITLE" --yesno "Protect Webmin with Fail2Ban?" 10 60); then
                                configure_fail2ban_for_webmin
                            fi
                        fi
                        ;;
                    11) check_app_installed "pihole" || install_pihole ;;
                    12) check_app_installed "adguardhome" || install_adguardhome ;;
                    13) install_filebrowser ;; 
                    14) # OMV luôn được xử lý cuối cùng do tính chất reboot
                        install_omv ;;
                esac
            done
            whiptail --title "$TITLE" --msgbox "All selected tasks completed." 10 60
        fi
        # Thoát vòng lặp sau khi cài xong
        break
    else
        # --- NGƯỜI DÙNG CHỌN CANCEL (hoặc ESC) ---
        if whiptail --title "$TITLE" --yesno "Do you really want to exit?" 10 60; then
            clear
            echo "Exiting RaspSetup. Goodbye!"
            exit 0
        fi
        # Nếu chọn No ở hộp thoại Exit, vòng lặp while sẽ chạy lại và hiện menu
    fi
done

# 6. Raspi-config
if whiptail --title "$TITLE" --yesno "Open raspi-config for system settings (SSH, VNC, etc)?" 10 60; then
    sudo raspi-config
fi

# 7. Reboot
if whiptail --title "$TITLE" --yesno "Installation finished. Reboot now?" 10 60; then
    sudo reboot
else
    clear
    echo "Setup finished. Please reboot manually later."
fi
