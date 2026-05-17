#!/usr/bin/env bash

set -Eeuo pipefail

COMMANDS_LIST+=("init_virtualbox_vm")

function validate_arg_mac_address() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo -n "Not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo "Empty address"
        return 1 
    fi

    if [[ "$val" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
        echo -n "${val,,}"
        return 0
    fi

    if [[ "$val" =~ ^([0-9A-Fa-f]{12})$ ]]; then
        local -a parts=()
        
        for (( i=0; i<${#val}; i+=2 )); do 
            parts+=("${val:i:2}"); 
        done
        
        local res=""
        IFS=":" res="${parts[*]}" 

        echo -n "${res,,}"	
        
        return 0
    fi

    echo -n "Invalid MAC address $val"
    return 1
}

# shellcheck disable=SC2329
function cmd_init_virtualbox_vm_run() {
    echo_green "Init virtualbox vm..."

    local package="openssh-server"

    if ! check_packages_installed "$package"; then
        echo_green "Install sshd..."
        if ! install_packages "openssh-server"; then
            echo_red "SSHD not installed!"
            return 1
        fi
    fi

    local nat_mac=""

    if ! nat_mac="$(extract_argument "--virtualbox-nat-mac" "VIRTUALBOX_NAT_MAC" "$CONST_NOT_FLAG" "validate_arg_mac_address" "$@")"; then
        echo_red "NAT MAC address: $nat_mac"
        return 1
    fi

    local static_mac=""

    if ! static_mac="$(extract_argument "--virtualbox-static-mac" "VIRTUALBOX_STATIC_MAC" "$CONST_NOT_FLAG" "validate_arg_mac_address" "$@")"; then
        echo_red "Static MAC address: $static_mac"
        return 1
    fi

    local ip_static=""

    if ! ip_static="$(extract_argument "--virtualbox-static-ip" "VIRTUALBOX_STATIC_IP" "$CONST_NOT_FLAG" "validate_arg_ipv4" "$@")"; then
        echo_red "Static IP address: $ip_static"
        return 1
    fi

    if [[ "$nat_mac" == "$static_mac" ]]; then
        echo_red "NAT and STATIC MACs should be different"
        return 1
    fi

    local -a ip_parts=()
    IFS="." read -ra ip_parts <<< "$ip_static"

    local gateway="${ip_parts[0]}.${ip_parts[1]}.${ip_parts[2]}.1"

    if [[ "$ip_static" == "$gateway" ]]; then
        echo_red "IP $ip_static should not gateway $gateway"
        return 1
    fi

    echo_green "Got NAT mac: $nat_mac Static mac $static_mac IP $ip_static Gateway $gateway"

    # shellcheck disable=SC2155
    local config_tmp="$(mktemp)"

    if ! chmod 600 "$config_tmp"; then
        echo_red "Cannot chmod temp file for config"
        return 1
    fi

    if ! chown "root:root" "$config_tmp"; then
        echo_red "Cannot chown temp file for config"
        return 1
    fi

    local backup_netplan="/root/backup_netplans"

    echo_green "Move old netplan configs to $backup_netplan"

    if ! mkdir -p "$backup_netplan"; then
        echo_red "Cannot create old netplans backup dir $backup_netplan"
        return 1
    fi

    local netplan_dir="/etc/netplan"
    local target_file="${netplan_dir}/00-static.yaml"

    local -a backup_files=()
    local cur_backup_file=""
    while IFS= read -r -d '' cur_backup_file; do
        if [ -z "$cur_backup_file" ]; then
            continue
        fi

        if [[ "$cur_backup_file" == "$target_file" ]]; then
            continue
        fi

        backup_files+=("$cur_backup_file") 
    done < <(find "$netplan_dir" -name '*.yaml' -type f -print0)

    if [[ "${#backup_files[@]}" == "0" ]]; then
        echo_green "Nothing to backup"
    else
        for to_bkp in "${backup_files[@]}"; do
            if ! mv "$to_bkp" "$backup_netplan"; then
                echo_red "Cannot backup file $to_bkp"
                return 1
            fi
        done
    fi

        local content=""
    content=$(cat <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: true
      dhcp6: true
      match:
        macaddress: $nat_mac
      set-name: enp0s3
      dhcp4-overrides:
        route-metric: 100
      dhcp6-overrides:
        route-metric: 100
    enp0s8:
      dhcp4: no
      dhcp6: no
      match:
        macaddress: $static_mac
      set-name: enp0s8
      addresses: [${ip_static}/24]
      routes:
        - to: default
          via: $gateway
          metric: 200
      nameservers:
        addresses: []

EOF
    )

    local not_ask=""
    not_ask="$(parse_not_ask "$@")"

    echo "$content" > "$config_tmp"

    if ! replace_file "$config_tmp" "$target_file" "Change netplan config" "true" "$not_ask"; then
        return 1
    fi

    echo_green "Applly netplan..."

    if ! netplan apply; then
        echo_red "Netplan config does not applyed! Backups in $backup_netplan"
        return 1
    fi

    local remote_host="google.com"

    if command -v ping &> /dev/null; then
        echo_green "Netplan applyed! Verify internet connection with ping $remote_host"
        echo_green "Sleep 5 seconds before check..."
        sleep 5
        
        if ! ping -W 4 -c 4 "$remote_host"; then
            echo_red "Host $remote_host not accessable!"
            return 1
        fi
        echo_green "Internet connection success!" 
    else
        echo_yellow "Ping is not installed. Skip verify internet connection"
    fi

    if ask_user "Remove backup dir $backup_netplan ?" "$not_ask"; then
        if ! rm -rfv "$backup_netplan"; then
            echo_yellow "$backup_netplan not removed!"
        fi
    fi

    echo_green "Virtualbox vm initialized!"

    return 0
}

# shellcheck disable=SC2329
function cmd_init_virtualbox_vm_help() {
    echo -n "
    Init virtual box vm.
    Install sshd and init interfaces with static ip for vm.
    Options:
      --virtualbox-nat-mac MAC_ADDRESS
         MAC address for nat interface.
         MAC address can simple 12 len string without : separator
         or 17 len string with separators.
         Can be set with env VIRTUALBOX_NAT_MAC
      --virtualbox-static-mac MAC_ADDRESS
         MAC address for static interface.
         MAC address can simple 12 len string without : separator
         or 17 len string with separators.
         Can be set with env VIRTUALBOX_STATIC_MAC
      --virtualbox-static-ip IP_ADDRESS
         IP address for set to static interface.
         Can be set with env VIRTUALBOX_STATIC_IP
"
}