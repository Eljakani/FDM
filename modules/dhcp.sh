#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    whiptail --title "Error" --msgbox "Please run as root." 8 50
    exit 1
fi

# Install net-tools if not already installed
if ! command -v ifconfig &>/dev/null; then
    apt-get update
    apt-get install -y net-tools
fi

# Function to validate IP address format
validate_ip() {
    if ! [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# Function to validate numeric input
validate_numeric() {
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# Check if DHCP server is installed
if command -v dhcpd &>/dev/null; then
    # DHCP server is installed
    whiptail --title "ISC DHCP Server Installed" --yesno "ISC DHCP server is already installed. Do you want to reinstall it?" 12 50 3 --yes-button "Reinstall" --no-button "Cancel"

    if [ $? -eq 0 ]; then
        # Reinstall DHCP server
        apt-get remove --purge -y isc-dhcp-server
        apt-get install -y isc-dhcp-server
        whiptail --title "Reinstall Complete" --msgbox "ISC DHCP server has been reinstalled." 8 50
    else
        whiptail --title "No Changes Made" --msgbox "No changes made." 8 50
    fi
else
    # DHCP server is not installed
    whiptail --title "ISC DHCP Server Not Installed" --yesno "ISC DHCP server is not installed. Do you want to install it?" 12 50 3 --yes-button "Install" --no-button "Cancel"

    if [ $? -eq 0 ]; then
        # Install DHCP server
        apt-get update
        apt-get install -y isc-dhcp-server
        whiptail --title "Install Complete" --msgbox "ISC DHCP server has been installed." 8 50
    else
        whiptail --title "No Changes Made" --msgbox "No changes made." 8 50
    fi
fi

# Identify available network interfaces
interfaces=$(ip -o link show | awk -F': ' '{print $2}')

# Create an array for whiptail
choices=()
while read -r interface; do
    choices+=("$interface" "")
done <<< "$interfaces"

# Prompt user to choose an interface
chosen_interface=$(whiptail --title "Choose Network Interface" --menu "Select the network interface for DHCP server" 20 60 10 "${choices[@]}" 3>&1 1>&2 2>&3)

if [ -z "$chosen_interface" ]; then
    whiptail --title "Error" --msgbox "No interface selected. Exiting." 8 50
    exit 1
fi

# Update the DHCP server configuration file
sed -i "/INTERFACESv4=/c\INTERFACESv4=\"$chosen_interface\"" /etc/default/isc-dhcp-server

# Notify the user about the update
whiptail --title "Configuration Updated" --msgbox "DHCP server configuration updated for interface: $chosen_interface" 8 50

# Prompt user for the IP address to assign
while true; do
    ip_address=$(whiptail --title "Enter IP Address" --inputbox "Enter the IP address to assign to $chosen_interface:" 10 60 3>&1 1>&2 2>&3)
    if validate_ip "$ip_address"; then
        break
    else
        whiptail --title "Error" --msgbox "Invalid IP address format. Please enter a valid format." 8 50
    fi
done

# Prompt user for the subnet mask
while true; do
    subnet_mask=$(whiptail --title "Enter Subnet Mask" --inputbox "Enter the subnet mask for $chosen_interface:" 10 60 3>&1 1>&2 2>&3)
    if ! validate_ip "$subnet_mask"; then
        whiptail --title "Error" --msgbox "Invalid subnet mask format. Please enter a valid format." 8 50
    else
        break
    fi
done

# Set the IP address and subnet mask using ifconfig
ifconfig "$chosen_interface" "$ip_address" netmask "$subnet_mask"

# Notify the user about the update
whiptail --title "Configuration Updated" --msgbox "Network interface configuration updated for $chosen_interface\nIP address assigned: $ip_address\nSubnet mask: $subnet_mask" 12 70

# Prompt user for DHCP configuration settings
subnet_mask=$(whiptail --inputbox "Enter subnet mask:" 10 60 255.255.255.0 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$subnet_mask"; then
    whiptail --title "Error" --msgbox "Invalid subnet mask format. Please enter a valid format." 8 50
    exit 1
fi

broadcast_address=$(whiptail --inputbox "Enter broadcast address:" 10 60 192.168.1.255 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$broadcast_address"; then
    whiptail --title "Error" --msgbox "Invalid broadcast address format. Please enter a valid format." 8 50
    exit 1
fi

domain_name=$(whiptail --inputbox "Enter domain name:" 10 60 server.local --title "DHCP Configuration" 3>&1 1>&2 2>&3)

subnet=$(whiptail --inputbox "Enter subnet:" 10 60 192.168.1.0 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$subnet"; then
    whiptail --title "Error" --msgbox "Invalid subnet format. Please enter a valid format." 8 50
    exit 1
fi

subnet_netmask=$(whiptail --inputbox "Enter subnet netmask:" 10 60 255.255.255.0 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$subnet_netmask"; then
    whiptail --title "Error" --msgbox "Invalid subnet netmask format. Please enter a valid format." 8 50
    exit 1
fi

range_start=$(whiptail --inputbox "Enter DHCP range start:" 10 60 192.168.1.10 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$range_start"; then
    whiptail --title "Error" --msgbox "Invalid DHCP range start format. Please enter a valid format." 8 50
    exit 1
fi

range_end=$(whiptail --inputbox "Enter DHCP range end:" 10 60 192.168.1.100 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$range_end"; then
    whiptail --title "Error" --msgbox "Invalid DHCP range end format. Please enter a valid format." 8 50
    exit 1
fi

router_ip=$(whiptail --inputbox "Enter router IP address:" 10 60 192.168.1.1 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$router_ip"; then
    whiptail --title "Error" --msgbox "Invalid router IP address format. Please enter a valid format." 8 50
    exit 1
fi

dns_server_ip=$(whiptail --inputbox "Enter DNS server IP address:" 10 60 192.168.1.1 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_ip "$dns_server_ip"; then
    whiptail --title "Error" --msgbox "Invalid DNS server IP address format. Please enter a valid format." 8 50
    exit 1
fi

# Prompt user for lease time settings
default_lease_time=$(whiptail --inputbox "Enter default lease time:" 10 60 600 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_numeric "$default_lease_time"; then
    whiptail --title "Error" --msgbox "Invalid default lease time. Please enter a numeric value." 8 50
    exit 1
fi

max_lease_time=$(whiptail --inputbox "Enter max lease time:" 10 60 7200 --title "DHCP Configuration" 3>&1 1>&2 2>&3)
if ! validate_numeric "$max_lease_time"; then
    whiptail --title "Error" --msgbox "Invalid max lease time. Please enter a numeric value." 8 50
    exit 1
fi

# Create a backup of the original dhcpd.conf
cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak

# Append the new settings to dhcpd.conf
cat <<EOL >> /etc/dhcp/dhcpd.conf
subnet ${subnet} netmask ${subnet_netmask} {
    range ${range_start} ${range_end};
    option routers ${router_ip};
    option domain-name-servers ${dns_server_ip};
    option subnet-mask ${subnet_mask};
    option broadcast-address ${broadcast_address};
    option domain-name "${domain_name}";
    default-lease-time ${default_lease_time};
    max-lease-time ${max_lease_time};
}
EOL

# Notify the user about the update
whiptail --title "Configuration Updated" --msgbox "DHCP server configuration updated." 8 50
