#!/bin/bash
# KHÔNG sử dụng set -e để tránh thoát sớm do các lệnh kiểm tra thất bại

# --- Biến toàn cục ---
TITLE="RaspSetup by Orwae"
BACKTITLE="Orwae Enterprise LLC | RaspSetup v2"

# --- Hàm: Kiểm tra và sửa lỗi dpkg ---
fix_dpkg() {
    echo "--- Checking for dpkg issues and attempting to fix them... ---"
    if sudo dpkg --configure -a; then
        echo "dpkg configuration completed successfully or no issues found."
        return 0
    else
        echo "Error: dpkg configuration failed. Please run 'sudo dpkg --configure -a' manually and fix any issues before proceeding." >&2
        return 1
    fi
}

# --- Hàm: Kiểm tra ứng dụng đã cài ---
# Trả về 0 nếu đã cài, 1 nếu chưa
check_app_installed() {
    local app_name="$1"
    case "$app_name" in
        "sysbench")
            command -v sysbench >/dev/null 2>&1 && sysbench --version >/dev/null 2>&1
            ;;
        "stress-ng")
            command -v stress-ng >/dev/null 2>&1 && stress-ng --version >/dev/null 2>&1
            ;;
        "neofetch")
            command -v neofetch >/dev/null 2>&1 && neofetch --version >/dev/null 2>&1
            ;;
        "htop")
            command -v htop >/dev/null 2>&1 && htop --version >/dev/null 2>&1
            ;;
        "node")
            command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
            ;;
        "ufw")
            command -v ufw >/dev/null 2>&1
            ;;
        "fail2ban")
            command -v fail2ban-client >/dev/null 2>&1
            ;;
        "realvnc")
            dpkg -s realvnc-vnc-server >/dev/null 2>&1
            ;;
        "webmin")
            # Kiểm tra xem gói webmin có được cài đặt hay không
            dpkg -s webmin >/dev/null 2>&1
            ;;
        "pi-apps")
            [ -d "$HOME/pi-apps" ]
            ;;
        *)
            echo "Unknown app: $app_name" >&2
            return 1
            ;;
    esac
    return $?
}

# --- Hàm: Cập nhật apt ---
update_apt() {
    echo "--- Updating package lists... ---"
    # Sử dụng gauge để hiển thị tiến độ apt update
    (
    sudo apt-get update 2>&1 | \
    stdbuf -o0 awk '/\[/{print $3}' | \
    stdbuf -o0 awk 'BEGIN{progress=0} {progress=progress+1; print int(progress*100/NR) "\n# Updating package lists..."}' | \
    whiptail --gauge "Updating package lists..." 6 60 0
    ) || return 1
    echo "Package lists updated successfully."
    return 0
}

# --- Hàm: Cài đặt ứng dụng qua apt ---
install_via_apt() {
    local packages="$1"
    local app_name="$2" # Tên để hiển thị
    echo "--- Installing $app_name... ---"
    # Sử dụng gauge để hiển thị tiến độ apt install
    (
    sudo apt-get install -y $packages 2>&1 | \
    stdbuf -o0 awk '/\[/{print $3}' | \
    stdbuf -o0 awk 'BEGIN{progress=0} {progress=progress+1; print int(progress*100/NR) "\n# Installing '$app_name'..."}' | \
    whiptail --gauge "Installing $app_name..." 6 60 0
    ) || return 1
    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "$app_name has been installed successfully." 10 60
    return 0
}

# --- Hàm: Cài đặt Pi-Apps (SỬA DỰA TRÊN SCRIPT CHÍNH THỨC, CHẠY DƯỚI NGƯỜI DÙNG THƯỜNG) ---
install_pi_apps() {
    local temp_script="$HOME/pi-apps-install-temp.sh"
    echo "--- Installing Pi-Apps (using official script, running as regular user)... ---"

    # Tải script chính thức
    if ! wget -qO "$temp_script" https://raw.githubusercontent.com/Botspot/pi-apps/master/install; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to download Pi-Apps install script using wget." 10 60
        rm -f "$temp_script"
        return 1
    fi

    # Kiểm tra và chạy script
    if [ -f "$temp_script" ]; then
        chmod +x "$temp_script"
        # Ghi log đầu ra vào một tệp tạm để kiểm tra lỗi chi tiết hơn nếu cần
        local log_file="$HOME/pi-apps-install.log"

        # Xác định người dùng thường để chạy script
        local regular_user
        if [ -n "$SUDO_USER" ]; then
            regular_user="$SUDO_USER"
        else
            # Nếu không chạy qua sudo, sử dụng người dùng hiện tại
            regular_user="$(logname 2>/dev/null || echo "$USER")"
        fi

        # Kiểm tra xem người dùng có tồn tại không
        if ! id "$regular_user" >/dev/null 2>&1; then
            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Cannot determine regular user account. Please run this script as a regular user or ensure SUDO_USER is set." 10 60
            rm -f "$temp_script"
            return 1
        fi

        # Chạy script dưới quyền người dùng thường
        if sudo -u "$regular_user" "$temp_script" > "$log_file" 2>&1; then
            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Pi-Apps has been installed successfully." 10 60
            rm -f "$temp_script" # Dọn dẹp sau khi chạy thành công
            rm -f "$log_file" # Dọn dẹp log
            return 0
        else
            # Nếu thất bại, có thể hiển thị một phần log lỗi cho người dùng biết
            local error_msg=$(tail -n 20 "$log_file" 2>&1)
            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Pi-Apps install script failed. Last 20 lines of log:\n\n$error_msg" 15 70
            rm -f "$temp_script" # Dọn dẹp sau khi chạy thất bại
            rm -f "$log_file" # Dọn dẹp log
            return 1
        fi
    else
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to download Pi-Apps install script." 10 60
        rm -f "$temp_script"
        return 1
    fi
}


# --- Hàm: Cài đặt Webmin (SỬA CHO BOOKWORM & TRIXIE - DÙNG SCRIPT CHÍNH THỨC) ---
install_webmin() {
    echo "--- Installing Webmin using the official setup script for Bookworm/Trixie... ---"

    # 1. Cập nhật apt
    if ! update_apt; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to update package lists before installing Webmin. Cannot proceed." 10 60
        return 1
    fi

    # 2. Cài đặt phụ thuộc cần thiết (wget, curl, gnupg, apt-transport-https)
    echo "--- Installing Webmin setup dependencies... ---"
    if ! sudo apt-get install -y wget curl gnupg apt-transport-https; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to install Webmin setup dependencies (wget, curl, gnupg, apt-transport-https). Cannot proceed." 10 60
        return 1
    fi

    # 3. Tải script thiết lập kho lưu trữ chính thức từ GitHub
    local setup_script="/tmp/webmin-setup-repo.sh"
    echo "--- Downloading official Webmin setup script... ---"
    if ! wget -qO "$setup_script" https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to download the official Webmin setup script. Cannot proceed." 10 60
        rm -f "$setup_script"
        return 1
    fi
    chmod +x "$setup_script"

    # 4. Chạy script thiết lập kho lưu trữ (script này sẽ tự động thêm khóa, repo, và cập nhật apt)
    echo "--- Running Webmin setup script (this may take a moment)... ---"
    if sudo "$setup_script"; then
        echo "Webmin repository setup completed by script."
        rm -f "$setup_script" # Dọn dẹp script sau khi chạy thành công
    else
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Webmin setup script failed. Cannot proceed with installation." 10 60
        rm -f "$setup_script" # Dọn dẹp script sau khi chạy thất bại
        return 1
    fi

    # 5. Cập nhật lại apt sau khi script thiết lập repo
    if ! update_apt; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to update package lists after Webmin repository setup. Cannot proceed." 10 60
        return 1
    fi

    # 6. Cài đặt gói Webmin
    echo "--- Installing Webmin package... ---"
    if sudo apt-get install -y webmin; then
        IP_ADDRESS=$(hostname -I | awk '{print $1}')
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Webmin installed!\n\nOpen your web browser and go to:\nhttps://$IP_ADDRESS:10000\n\nLogin with your current username and password." 15 60
        return 0
    else
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Webmin did not finish installing. Please check the output above for errors." 10 60
        return 1
    fi
}


# --- Hàm: Cấu hình Fail2Ban cho Webmin ---
configure_fail2ban_for_webmin() {
    local webmin_auth_file="/etc/webmin/miniserv.users"
    local fail2ban_jail_file="/etc/fail2ban/jail.local"
    local fail2ban_service_file="/etc/systemd/system/fail2ban.service.d/override.conf"

    # Kiểm tra Webmin có tồn tại không
    if ! check_app_installed "webmin"; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Webmin is not installed. Cannot configure Fail2Ban for Webmin." 10 60
        return 1
    fi

    # Tạo tệp jail.local nếu chưa có
    if [ ! -f "$fail2ban_jail_file" ]; then
        sudo touch "$fail2ban_jail_file"
    fi

    # Kiểm tra xem cấu hình Webmin đã tồn tại trong jail.local chưa
    if grep -q "^\[webmin\]" "$fail2ban_jail_file" 2>/dev/null; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Fail2Ban is already configured for Webmin." 10 60
        return 0
    fi

    # Thêm cấu hình Webmin vào jail.local
    sudo tee -a "$fail2ban_jail_file" > /dev/null <<EOF

[webmin]
enabled = true
port = 10000
filter = webmin-auth
logpath = /var/webmin/miniserv.log
maxretry = 3
bantime = 600
findtime = 600
EOF

    # Tạo tệp filter nếu chưa có
    local fail2ban_filter_dir="/etc/fail2ban/filter.d"
    local webmin_filter_file="$fail2ban_filter_dir/webmin-auth.conf"
    if [ ! -f "$webmin_filter_file" ]; then
        sudo mkdir -p "$fail2ban_filter_dir"
        sudo tee "$webmin_filter_file" > /dev/null <<EOF
[Definition]
failregex = ^.*webmin - - \[.*\] "POST /session_login.cgi HTTP/1\..*" 403 .*
ignoreregex =
EOF
    fi

    # Khởi động lại dịch vụ fail2ban để áp dụng cấu hình
    echo "--- Restarting Fail2ban service to apply Webmin configuration... ---"
    sudo systemctl restart fail2ban

    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Fail2Ban has been configured to protect Webmin.\n\nIt will ban IP addresses after 3 failed login attempts for 10 minutes." 12 60
    return 0
}

# --- Khởi tạo ---
whiptail --title "$TITLE" --backtitle "$BACKTITLE" --infobox "Initializing script..." 6 60
sleep 1

# --- Kiểm tra và cài đặt whiptail ---
if ! command -v whiptail >/dev/null 2>&1; then
    clear
    echo "--- Whiptail is not installed. Installing it now... ---"
    # Cố gắng sửa dpkg trước khi cài whiptail
    if ! fix_dpkg; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "dpkg is in a broken state. Cannot install whiptail. Please fix dpkg manually first." 10 60
        exit 1
    fi
    if ! update_apt || ! sudo apt-get install -y whiptail; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to install whiptail. Exiting." 10 60
        exit 1
    fi
fi

# --- Thu thập thông tin hệ thống ---
if command -v lsb_release >/dev/null 2>&1; then
    OS_INFO=$(lsb_release -d | cut -f2)
else
    OS_INFO="N/A"
fi
BOARD_INFO=$(cat /proc/device-tree/model 2>/dev/null || echo "N/A")

# --- Cập nhật hệ thống ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "System: $OS_INFO\nDevice: $BOARD_INFO\n\nDo you want to update and upgrade the system now?" 15 60); then
    clear
    echo "--- Starting system update and upgrade. This may take a while... ---"
    # Cố gắng sửa dpkg trước khi cập nhật hệ thống
    if ! fix_dpkg; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "dpkg is in a broken state. Cannot proceed with system update. Please fix dpkg manually first." 10 60
        # Có thể chọn tiếp tục hoặc thoát
        # exit 1
    else
        if update_apt && sudo apt-get upgrade -y; then
            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "System update and upgrade completed successfully." 10 60
        else
            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "System update failed. Please check your internet connection and sources.list file." 10 60
            # Không thoát, tiếp tục cho phép chọn ứng dụng
        fi
    fi
else
    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Script aborted by user." 10 60
    clear
    exit 0
fi

# --- Bước 2: Chọn ứng dụng ---
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
)

CHOICES=$(whiptail --title "$TITLE" --backtitle "$BACKTITLE" --checklist \
"Select applications to install (SPACE to select, ENTER to confirm):" 20 70 10 \
"${OPTIONS[@]}" 3>&1 1>&2 2>&3)

if [ $? -eq 0 ]; then
    # Cố gắng sửa dpkg trước khi bắt đầu cài đặt các ứng dụng đã chọn
    if ! fix_dpkg; then
        whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "dpkg is in a broken state. Cannot proceed with installing applications. Please fix dpkg manually first." 10 60
        # Có thể chọn exit ở đây nếu muốn
        # exit 1
    else
        # Cập nhật apt một lần trước khi bắt đầu cài đặt các ứng dụng đã chọn
        if ! update_apt; then
            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Failed to update package lists before installing applications. Cannot proceed with installations." 10 60
            # Có thể chọn exit ở đây nếu muốn
            # exit 1
        else
            for choice in $CHOICES; do
                case $choice in
                    "\"1\"")
                        if check_app_installed "sysbench"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Sysbench is already installed." 10 60
                        else
                            install_via_apt "sysbench" "Sysbench"
                        fi
                        ;;
                    "\"2\"")
                        if check_app_installed "stress-ng"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Stress-ng is already installed." 10 60
                        else
                            install_via_apt "stress-ng" "Stress-ng"
                        fi
                        ;;
                    "\"3\"")
                        if check_app_installed "neofetch"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Neofetch is already installed." 10 60
                        else
                            install_via_apt "neofetch" "Neofetch"
                        fi
                        ;;
                    "\"4\"")
                        if check_app_installed "pi-apps"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Pi-Apps is already installed." 10 60
                        else
                            install_pi_apps
                        fi
                        ;;
                    "\"5\"")
                        if check_app_installed "realvnc"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "RealVNC is already installed." 10 60
                        else
                            install_via_apt "realvnc-vnc-server realvnc-vnc-viewer" "RealVNC"
                        fi
                        ;;
                    "\"6\"")
                        if check_app_installed "htop"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Htop is already installed." 10 60
                        else
                            install_via_apt "htop" "Htop"
                        fi
                        ;;
                    "\"7\"")
                        if check_app_installed "ufw"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "UFW Firewall is already installed." 10 60
                        else
                            install_via_apt "ufw" "UFW Firewall"
                        fi
                        ;;
                    "\"8\"")
                        if check_app_installed "node"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Node.js and NPM are already installed." 10 60
                        else
                            install_via_apt "nodejs npm" "Node.js and NPM"
                        fi
                        ;;
                    "\"9\"")
                        if check_app_installed "webmin"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Webmin is already installed." 10 60
                        else
                            install_webmin
                        fi
                        ;;
                    "\"10\"")
                        if check_app_installed "fail2ban"; then
                            whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Fail2ban is already installed." 10 60
                        else
                            install_via_apt "fail2ban" "Fail2ban"
                            # Sau khi cài đặt thành công, hỏi người dùng có muốn cấu hình với Webmin không
                            if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "Fail2ban has been installed. Do you want to configure it to protect Webmin (if Webmin is installed)?" 10 60); then
                                configure_fail2ban_for_webmin
                            fi
                        fi
                        ;;
                esac
            done
        fi
    fi
else
    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Script aborted by user." 10 60
    clear
    exit 0
fi

# --- Bước 3: Raspi-config ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "Do you want to open raspi-config to configure SSH/VNC?" 10 60); then
    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --infobox "Opening raspi-config..." 6 60
    sleep 2
    sudo raspi-config
fi

# --- Bước 4: Hoàn thành ---
whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Installation Completed!\n\nPress OK to continue." 10 60

# --- Bước 5: Khởi động lại? ---
if (whiptail --title "$TITLE" --backtitle "$BACKTITLE" --yesno "Do you want to reboot the system now?" 10 60); then
    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "System will reboot now..." 10 60
    sudo reboot
else
    whiptail --title "$TITLE" --backtitle "$BACKTITLE" --msgbox "Exit script.\n\nYou can reboot manually later." 10 60
fi

clear
