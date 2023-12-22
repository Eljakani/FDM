#/bin/bash

check_root() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    else
        return 0
    fi
}

check_internet() {
    ping -c 1 8.8.8.8 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi 
}

get_system_info() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VER=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        OS=Debian
        VER=$(cat /etc/debian_version)
    elif [ -f /etc/SuSe-release ]; then
        ...
    elif [ -f /etc/redhat-release ]; then
        ...
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

check_system() {
    get_system_info
    if [ "$OS" != "Ubuntu" ] && [ "$OS" != "Debian" ] && [ "$OS" != "Kali" ]; then
        return 1
    else
        return 0
    fi
}

check_modules() {
    if [ -d ./modules ]; then
        if [ -f ./modules/ftp.sh ] && [ -f ./modules/dhcp.sh ] && [ -f ./modules/mail.sh ]; then
            chmod +x ./modules/ftp.sh
            chmod +x ./modules/dhcp.sh
            chmod +x ./modules/mail.sh
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

disclaimer() {
    whiptail --title "FDM" --msgbox "FDM is a script that installs and configures FTP, DHCP and Mail services on your system. This script is only for educational purposes. The author is not responsible for any damage caused by this script. Use this script at your own risk." 15 60
}

show_system_info() {
    get_system_info
    whiptail --title "System Info" --msgbox "OS: $OS\nVersion: $VER\n\nYour system is supported\n continue..." 12 60
}

installation() {
    if whiptail --title "FTP" --yesno "Do you want to install FTP?" 10 60; then
        ./modules/ftp.sh
    fi
    if whiptail --title "DHCP" --yesno "Do you want to install DHCP?" 10 60; then
        ./modules/dhcp.sh
    fi
    if whiptail --title "Mail" --yesno "Do you want to install Mailing service?" 10 60; then
        ./modules/mail.sh
    fi
}

main() {
    if check_root; then
        if check_system; then
            if check_modules; then
                if check_internet; then
                    disclaimer
                    show_system_info
                    installation
                else
                    whiptail --title "Error" --msgbox "No internet connection available. Please check your internet connection and try again." 10 60
                fi
            else
                whiptail --title "Error" --msgbox "The modules are missing. Please check the modules folder and try again." 10 60
            fi
        else
            whiptail --title "Error" --msgbox "Your system is not supported. Please use Ubuntu, Debian or Kali Linux." 10 60
        fi
    else
        whiptail --title "Warning" --yesno "You are not running this script as root. Do you want to run this script as root?" 10 60
        if [ $? -eq 0 ]; then
            sudo $0
        else
            exit 1
        fi
    fi
}

main