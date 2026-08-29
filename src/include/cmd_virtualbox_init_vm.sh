#!/usr/bin/env bash

set -Eeuo pipefail

COMMANDS_LIST+=("virtualbox_init_vm")

# shellcheck disable=SC2329
function virtualbox_extract_not_quoted_value() { 
    local input="$1"

    if [ -z "$input" ]; then
        echo -n ""
        return 0
    fi

    local -a val_parts=()

    IFS="=" read -ra val_parts <<<"$input"

    if [[ "${#val_parts[@]}" != "2" ]]; then
        echo_red "incorrect input key/val $raw_key_val Have no 2 parts"
        return 1
    fi

    local res="${val_parts[1]#\"}"
    res="${res%\"}"

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_extract_value_for_key_human() { 
    local raw_out="$1"
    local key="$2"
    local can_not_found="${3-false}"

    local raw_key_val=""
    if ! raw_key_val="$(grep --color=never "$key:" <<<"$raw_out")"; then
        if [[ "$can_not_found" == "true" ]]; then
            echo -n ""
            return 0
        fi
        echo_red "Cannot extract $key"
        return 1
    fi

    local -a val_parts=()

    IFS=":" read -ra val_parts <<<"$raw_key_val"

    if [[ "${#val_parts[@]}" != "2" ]]; then
        echo_red "incorrect input key/val $raw_key_val Have no 2 parts"
        return 1
    fi

    echo -n "$(remove_begin_spaces "${val_parts[1]}")"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_extract_value_for_key() { 
    local raw_out="$1"
    local key="$2"
    local can_not_found="${3-false}"

    local raw_key_val=""
    if ! raw_key_val="$(grep --color=never "$key=" <<<"$raw_out")"; then
        if [[ "$can_not_found" == "true" ]]; then
            echo -n ""
            return 0
        fi
        echo_red "Cannot extract $key"
        return 1
    fi

    local res=""

    if ! res="$(virtualbox_extract_not_quoted_value "$raw_key_val")"; then
        echo_red "Cannot extract value for key ${key}: $res"
        return 1
    fi

    echo -n "$res"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_extract_mac_address() { 
    local raw_out="$1"
    local index="$2"

    local key="macaddress${index}"

    local mac=""
    if ! mac="$(virtualbox_extract_value_for_key "$raw_out" "$key")"; then
        echo_red "Cannot extract mac-addres for $key: $mac"
        return 1
    fi

    echo -n "$mac"
    return 0
}

# shellcheck disable=SC2329
function validate_arg_octet() {
    local val="$1"
    local passed="$2"

    if [[ "$passed" == "$CONST_ARG_NOT_PASSED" ]]; then
        echo "Arg not passed"
        return 1
    fi

    if [ -z "$val" ]; then
        echo "Empty arg val"
        return 1 
    fi

    if (( "$val" > 1 && "$val" < 254 )); then
        echo -n "$val"
        return 0
    fi

    echo "$val should be octet from 2 to 253"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_extract_host_iface() {
    local user_passed_ip="${1-}"
    local passed_iface="${2-}"
    local raw_out=""

    if ! raw_out="$(vboxmanage list hostonlyifs)"; then
        echo_red "Cannot get list hostonlyifs"
        return 1
    fi

    if [ -z "$raw_out" ]; then 
        echo_red "Hostonly adapters not found!"
        return 1
    fi

    raw_out="${raw_out//$'\n\n'/$'\1'}"

    local -a ifaces_raw_list=()
    IFS=$'\1' read -r -d '' -a ifaces_raw_list <<< "$raw_out"

    local -A ifaces=()
    local single_iface_name=""

    for iface_raw in "${ifaces_raw_list[@]}"; do
        if [ -z "$iface_raw" ]; then
            continue
        fi

        local name=""
        if ! name="$(virtualbox_extract_value_for_key_human "$iface_raw" "Name")"; then
            echo_red "Cannot extract hostonly interface name from $iface_raw :: $name"
            return 1
        fi

        local address=""
        if ! address="$(virtualbox_extract_value_for_key_human "$iface_raw" "IPAddress")"; then
            echo_red "Cannot extract hostonly interface name from $iface_raw :: $address"
            return 1
        fi

        single_iface_name="$name"

        ifaces["$name"]="$address"
    done

    local choiced_iface=""

    if [ -z "$passed_iface" ]; then
        case "${#ifaces[@]}" in
            "0")
                echo_red "Not found any hostonly interfaces"
                return 1
            ;;
            "1")
                choiced_iface="$single_iface_name"
                echo_green "Found single hostonly interface $choiced_iface with address ${ifaces[$choiced_iface]}" >&2
            ;;
            *)
                local -a indexes=()
                local cur_index=0
                local -A index_to_name=()
                for iface_name in "${!ifaces[@]}"; do
                    indexes+=("$cur_index")
                    index_to_name["$cur_index"]="$iface_name"
                    echo_green "[$cur_index] Found interface $iface_name with address ${ifaces[$iface_name]}" >&2
                    ((cur_index++))
                done

                local choiced_index="-1"
                if ! choiced_index="$(ask_user_choice "Enter interface number to attach" "${indexes[@]}")"; then
                    echo_red "Interface not choiced: $choiced_index"
                    return 1
                fi
                choiced_iface="${index_to_name[$choiced_index]}"
            ;;
        esac
    else
        if ! [[ -v ifaces["$passed_iface"] ]]; then
            echo_red "Not found interface $passed_iface"
            return 1
        fi
        choiced_iface="$passed_iface"
    fi

    local iface_address="${ifaces[$choiced_iface]}"

    local choiced_ip="$user_passed_ip"

    local -a gw_ip_parts=()
    IFS="." read -ra gw_ip_parts <<< "$iface_address"

    if [ -z "$choiced_ip" ]; then
        local octet=""
        if ! octet="$(ask_user_raw "Enter last octet number to assign address" "validate_arg_octet")"; then
            echo_red "Invalid inputed octet: $octet"
            return 1
        fi

        choiced_ip="${gw_ip_parts[0]}.${gw_ip_parts[1]}.${gw_ip_parts[2]}.$octet"
    else
        local -a choiced_ip_parts=()
        IFS="." read -ra choiced_ip_parts <<< "$choiced_ip"
        unset 'choiced_ip_parts[-1]'
        unset 'gw_ip_parts[-1]'
        if [[ "${gw_ip_parts[*]}" != "${choiced_ip_parts[*]}" ]]; then
            echo_red "Input IP $choiced_ip not in hostonly gw net $iface_address"
            return 1
        fi
    fi

    echo ""
    echo "Output;${choiced_iface};$choiced_ip"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_get_vm_info_json() {
    local vm_name="$1"
    local raw_out=""

    if ! raw_out="$(vboxmanage showvminfo "$vm_name" --machinereadable)"; then
        echo_red "Cannot get info for vm $vm_name"
        return 1
    fi

    local nics_index=1

    local res_json='
{
    "ifaces": {},
    "opticals": []
}'

    local nat_consumed=""
    local host_consumed=""

    while true; do
        local cur_nic_index="$nics_index"
        ((nics_index++))

        local nic_type_raw=""
        if ! nic_type_raw="$(grep --color=never "nic${cur_nic_index}=" <<<"$raw_out")"; then
            break
        fi

        local nic_type=""

        if ! nic_type="$(virtualbox_extract_not_quoted_value "$nic_type_raw")"; then
            echo_red "Cannot to extract nic type for index $cur_nic_index: $nic_type"
            return 1
        fi

        case "$nic_type" in
            "nat")
                if [[ "$nat_consumed" == "true" ]]; then
                    echo_red "NAT interface already consumed"
                    echo_red "$res_json"
                    return 1
                fi
                local mac=""
                if ! mac="$(virtualbox_extract_mac_address "$raw_out" "$cur_nic_index")"; then
                    echo_red "$mac"
                    return
                fi
                local nat_json=".ifaces += {\"nat\":{\"mac\":\"$mac\",\"indx\":\"$cur_nic_index\"}}"
                if ! res_json="$(jq "$nat_json" <<<"$res_json")"; then
                    echo_red "Cannot append nat iface"
                    return 1
                fi
                nat_consumed="true"
            ;;

            "hostonly")
                if [[ "$host_consumed" == "true" ]]; then
                    echo_red "Hostonly interface already consumed"
                    echo_red "$res_json"
                    return 1
                fi

                local mac=""
                if ! mac="$(virtualbox_extract_mac_address "$raw_out" "$cur_nic_index")"; then
                    echo_red "$mac"
                    return
                fi

                local adapter=""
                if ! adapter="$(virtualbox_extract_value_for_key "$raw_out" "hostonlyadapter${cur_nic_index}")"; then
                    echo_red "Cannot extract hostonly adapter: $adapter"
                    return 1
                fi
                

                local host_json=".ifaces += {\"host\":{\"mac\":\"$mac\",\"adapter\":\"$adapter\",\"indx\":\"$cur_nic_index\"}}"
                if ! res_json="$(jq "$host_json" <<<"$res_json")"; then
                    echo_red "Cannot append hostonly iface"
                    return 1
                fi
                host_consumed="true"
            ;;
            *)
                continue
            ;;
        esac
    done

    local ides_index=0
    local -a opticals=()
    while true; do
        local cur_ide_index="$ides_index"
        ((ides_index++))

        local minor=0

        local ide_type=""
        if ! ide_type="$(virtualbox_extract_value_for_key "$raw_out" "\"IDE-${cur_ide_index}-${minor}\"" "true")"; then
            echo_red "Cannot extract IDE-${cur_ide_index}-${minor} : $ide_type"
            return 1
        fi

        if [ -z "$ide_type" ]; then
            break
        fi

        if [ "$ide_type" != "none" ]; then
            opticals+=("${cur_ide_index}-${minor}")
        fi

        while true; do
            ((minor++))
            local ide_major=""
            if ! ide_major="$(virtualbox_extract_value_for_key "$raw_out" "\"IDE-${cur_ide_index}-${minor}\"" "true")"; then
                echo_red "Cannot extract IDE-${cur_ide_index}-${minor}: $ide_major"
                return 1
            fi
            
            if [ -z "$ide_major" ]; then
                break
            fi

            if [ "$ide_major" != "none" ]; then
                opticals+=("${cur_ide_index}-${minor}")
            fi
        done
    done

    for opt in "${opticals[@]}"; do
        local opt_json=".opticals += [\"$opt\"]"
        if ! res_json="$(jq "$opt_json" <<<"$res_json")"; then
            echo_red "Cannot append optical $opt"
            return 1
        fi
    done

    echo -n "$res_json"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_vm_is_running() {
    local vm_name="${1}"

    local all_vms=""
    if ! all_vms="$(vboxmanage list runningvms)"; then
        echo_red "Cannot get list running vms!"
        return 1
    fi

    if grep "$vm_name" <<<"$all_vms"; then
        return 0
    fi

    return 1
}

# shellcheck disable=SC2329
function virtualbox_stop_vm() {
    local vm_name="$1"

    if ! virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    if ! vboxmanage controlvm "$vm_name" poweroff; then
        echo_red "Cannot stop vm $vm_name"
        return 1 
    fi

    local attempts=5

    for i in $(seq 1 $attempts); do
        if virtualbox_vm_is_running "$vm_name"; then
            echo_yellow "Waiting 5 seconds to stop vm $vm_name Attempt $i"
            sleep 5 
            continue
        fi
        return 0
    done

    if ! virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    echo_red "Vm $vm_name is not stopped after $attempts attempts"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_start_vm() {
    local vm_name="$1"

    if virtualbox_vm_is_running "$vm_name"; then
        return 0
    fi

    local attempts=5

    for i in $(seq 1 $attempts); do
        if ! vboxmanage startvm "$vm_name"; then
            echo_yellow "Waiting 5 seconds to start vm $vm_name Attempt $1"
            sleep 5
            continue
        fi

        return 0 
    done

    if vboxmanage startvm "$vm_name"; then
        return 0
    fi

    echo_red "Vm $vm_name is not started after $attempts attempts"
    return 1
}

# shellcheck disable=SC2329
function virtualbox_prepare_viso() {
    local vm_name="$1"
    local nat_mac="$2"
    local static_mac="$3"
    local ip_static="$4"
    local ssh_key="${5-}"

    local vm_name_sum=""
    if ! vm_name_sum=$(sha256sum <<<"$vm_name"); then
        echo_red "Cannot calculate sum from vm"
        return 1
    fi

    if ! vm_name_sum=$(cut -c 1-12 <<<"$vm_name_sum"); then
        echo_red "Cannot trim sum for vm"
        return 1
    fi

    local vm_dir="virtualbox/${vm_name_sum}"

    if ! mkdir -p "$vm_dir"; then
        echo_red "Cannot create tmp dir for vm $vm_name $vm_dir"
        return 1
    fi

    local bundle_file="${vm_dir}/init_bundle.sh"

    local -a files_to_viso=()

    # shellcheck disable=SC2154
    if ! cp "$bin_name" "$bundle_file"; then
        echo_red "Cannot copy init script $bin_name to $vm_dir"
        return 1
    fi

    files_to_viso+=("$bundle_file")

    local auth_keys_file="${vm_dir}/authorized_keys"

    if [ -n "$ssh_key" ] && [ -s "$ssh_key" ]; then
        if ! cp "$ssh_key" "$auth_keys_file"; then
            echo_red "Cannot copy ssh key $ssh_key to $vm_dir"
            return 1
        fi
    else
        echo -n "" > "$auth_keys_file"
    fi

    files_to_viso+=("$auth_keys_file")

    local vm_name_file="${vm_dir}/vmname.txt"

    echo "$vm_name" > "$vm_name_file"

    files_to_viso+=("$vm_name_file")

    local init_file="${vm_dir}/init.sh"

    # bash not correct handle shebang and set 
    # when write file! 
    {
        echo -n "#"
        echo '!/usr/bin/env bash'
        echo -n 'se'
        echo 't -Eeuo pipefail'
    } > "$init_file"

    cat <<EOF >> "$init_file"
run_dir=\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" &> /dev/null && pwd)
run_dir="\$(realpath "\$run_dir")"

bundle_file="\${run_dir}/init_bundle.sh"

"\$bundle_file" cmd virtualbox_init_vm_itself \\
  --virtualbox-nat-mac "$nat_mac" \\
  --virtualbox-static-mac "$static_mac" \\
  --virtualbox-static-ip "$ip_static" \\
  --virtualbox-ssh-key "\${run_dir}/authorized_keys" \\
  --virtualbox-sudo-no-password

if [[ \$? != "0" ]]; then
    echo "Failed!"
    exit 1
fi

echo "Success"
exit 0

EOF
    files_to_viso+=("$init_file")

    if ! chmod 755 "${vm_dir}/init.sh"; then
        echo_red "Cannot chmod ${vm_dir}/init.sh"
        return 1
    fi

    local viso_file="${vm_dir}/image.viso"

    local -a create_args=(
        "--name-setup" 
        "iso"
        "--iprt-iso-maker-file-marker-bourne-sh=$(uuidgen)"
        "--strict-attribs"
        "--volid=initvm"
        "-o"
        "$viso_file"
    )

    for v_file in "${files_to_viso[@]}"; do
        local base=""
        if ! base="$(basename "$v_file")"; then
            echo_red "Cannot get base for $v_file"
            return 1
        fi
        create_args+=("/${base}=${v_file}")
    done

    if ! vbox-img createiso "${create_args[@]}" >&2; then
        echo_red "Cannot create viso $viso_file"
        return 1 
    fi

    if ! viso_file="$(realpath "$viso_file")"; then
        echo_red "Cannot get real path for $viso_file"
        return 1
    fi

    echo -n "$viso_file"
    return 0
}

# shellcheck disable=SC2329
function virtualbox_unmount_opticals() {
    local vm_name="$1"

    shift

    if [[ "$#" == 0 ]]; then
        echo_green "Nothing to unmount"
        return 0 
    fi

    for opt in "$@"; do
        local -a opt_dev=()
        IFS="-" read -ra opt_dev <<<"$opt"
        if [[ "${#opt_dev[@]}" != "2" ]]; then
            echo_red "Failed to parse optical $opt Should have 0-0 for example"
            return 1
        fi


        local port="${opt_dev[0]}"
        local device="${opt_dev[1]}"

        echo_green "Unmount IDE on $vm_name port $port device $device"

        if ! vboxmanage storageattach "$vm_name" --storagectl "IDE" --port "$port" --device "$device" --type dvddrive --medium none; then
            echo_red "Failed to unmount optical $opt"
            return 1
        fi
    done

    return 0
}


# shellcheck disable=SC2329
function virtualbox_unmount_cleanup_after_init() {
    local vm_name="$1"
    local viso_file="$2"

    local viso_real=""
    if ! viso_real="$(realpath "$viso_file")"; then
        echo_red "Cannot real path for $viso_file"
        return 1
    fi

    local cleanup_dir=""
    if ! cleanup_dir="$(dirname "$viso_real")"; then
        echo_red "Cannot get cleanup dir from $viso_real"
        return 1
    fi

    echo_green "Stop vm to unmount init opticals..."
    if ! virtualbox_stop_vm "$vm_name"; then
        echo_red "Failed to stop vm?"
    fi

    local vm_info_json=""

    if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
        echo_red "Cannot get vm info: $vm_info_json"
        return 1
    fi

    local opticals_str=""
    if ! opticals_str="$(jq_get_key_or_empty "$vm_info_json" '.opticals | join(";")' "false")"; then
        echo_red "Cannot get opticals from vm info: $vm_info_json"
        return 1
    fi

    local -a opticals_to_unmount=()
    IFS=";" read -ra opticals_to_unmount <<< "$opticals_str"

    echo_green "Unmount init opticals..."

    if ! virtualbox_unmount_opticals "$vm_name" "${opticals_to_unmount[@]}"; then
        return 1
    fi

    if ask_user "Do you want to remove dir $cleanup_dir"; then
        if ! rm -rfv "$cleanup_dir"; then
            echo_red "Dir $cleanup_dir not removed!"
            return 1
        fi
    else
        echo_yellow "Disallow remove dir $cleanup_dir"
    fi

    echo_green "Start vm..."

    if ! virtualbox_start_vm "$vm_name"; then
        echo_red "Vm not started!"
        return 1
    fi

    return 0
}

# shellcheck disable=SC2329
function virtualbox_mount_opticals() {
    local vm_name="$1"

    shift

    if [[ "$#" == 0 ]]; then
        echo_red "Nothing to mount"
        return 1 
    fi

    if [ "$#" -gt  4 ]; then
        echo_red "To many mounts should be <= 4"
        return 1 
    fi

    local port=0
    local device=0

    for iso in "$@"; do
        echo_green "Mount $iso to $vm_name port $port device $device"
        if ! vboxmanage storageattach "$vm_name" --storagectl "IDE" --port "$port" --device "$device" --type dvddrive --medium "$iso"; then
            echo_red "Failed mount $iso to $vm_name port $port device $device"
            return 1
        fi

        ((port++))
        ((device++))

        if ((device > 1)); then
            device=0
        fi
    done

    return 0
}

# shellcheck disable=SC2329
function cmd_virtualbox_init_vm_run() {
    if ! command -v vboxmanage &> /dev/null; then
        echo_red "vboxmanage executable not found!"
        echo_red "Probably you run virtualbox_init_vm command inside vm"
        echo_red "If you want to init vm from vm, use virtualbox_init_vm_itself"
        return 1
    fi 
    
    if ! command -v vbox-img &> /dev/null; then
        echo_red "vbox-img executable not found!"
        echo_red "Probably you run virtualbox_init_vm command inside vm"
        echo_red "If you want to init vm from vm, use virtualbox_init_vm_itself"
        return 1
    fi

    if ! command -v jq &> /dev/null; then
        echo_red "virtualbox_init_vm command require jq"
        echo_red "Please install jq"
        return 1
    fi

    local vm_name=""
    if ! vm_name="$(extract_argument "--virtualbox-vm-name" "VIRTUALBOX_VM_NAME" "$CONST_NOT_FLAG" "validate_arg_not_empty" "$@")"; then
        echo_red "Vm name not passed: $vm_name"
        return 1
    fi

    local attach_address=""
    if ! attach_address="$(extract_argument "--virtualbox-attach-address" "VIRTUALBOX_ATTACH_ADDRESS" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "Attach address incorrect: $attach_address"
        return 1
    fi

    local ssh_key_file=""
    if ! ssh_key_file="$(extract_argument "--virtualbox-ssh-key" "VIRTUALBOX_SSH_KEY" "$CONST_NOT_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "SSH key file incorrect: $ssh_key_file"
        return 1
    fi

    local skip_vsio=""
    if ! skip_vsio="$(extract_argument "--virtualbox-skip-prepare-init-iso" "VIRTUALBOX_SKIP_PREPARE_INIT_ISO" "$CONST_IS_FLAG" "$CONST_NO_VALIDATE" "$@")"; then
        echo_red "Skip VSIO flag parse error"
        return 1
    fi

    if [ -n "$attach_address" ]; then
        if ! attach_address="$(validate_arg_ipv4 "$attach_address" "$CONST_ARG_PASSED")"; then
            echo_red "Attach address incorrect: $attach_address"
            return 1
        fi
    fi

    echo_green "Init virtualbox vm $vm_name ..."

    local all_vms=""
    if ! all_vms="$(vboxmanage list vms)"; then
        echo_red "Cannot get all vms!"
        return 1
    fi

    if ! grep -q "$vm_name" <<<"$all_vms"; then
        echo_red "Vm $vm_name not found!"
        echo_red "Have next vms:"
        echo "$all_vms"
        return 1
    fi

    echo_green "Stop vm $vm_name ..."
    if ! virtualbox_stop_vm "$vm_name"; then
        echo_red "Cannot stop vm $vm_name!"
        return 1
    fi

    local vm_info_json=""

    if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
        echo_red "Cannot get vm info: $vm_info_json"
        return 1
    fi

    local nat_mac=""
    local nat_index=""
    local host_mac=""
    local host_adapter=""

    if ! nat_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.mac" "false")"; then
        echo_red "Cannot extract NAT mac: $nat_mac"
        return 1
    fi

    if [ -z "$nat_mac" ]; then
        echo_yellow "NAT interface not found! Create..."

        local host_index=""
        if ! host_index="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.indx" "false")"; then
            echo_red "Cannot extract index for host iface"
            return 1
        fi
        
        if [ -n "$host_indx" ]; then
            nat_index="$(($host_index + 1))"
            echo_green "Found host interface with index ${host_index}. NAT interface will create with index $nat_index"
        else
            nat_index="1"
            echo_green "Host interface not found. NAT iface will create with index $nat_index"
        fi

        if ! vboxmanage modifyvm "$vm_name" "--nic$nat_index" nat; then
            echo_red "Cannot add NAT interface"
            return 1
        fi

        nat_index=""
        if ! vm_info_json="$(virtualbox_get_vm_info_json "$vm_name")"; then
            echo_red "Cannot get vm info after add NAT: $vm_info_json"
            return 1
        fi

        if ! nat_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.mac" "true")"; then
            echo_red "Cannot extract NAT mac: $nat_mac"
            return 1
        fi
    fi

    if ! nat_index="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.nat.indx" "true")"; then
        echo_red "Cannot extract NAT index: $nat_index"
        return 1
    fi

    if ! host_mac="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.mac" "false")"; then
        echo_red "Cannot extract hostonly mac: $host_mac"
        return 1
    fi

    if [ -n "$host_mac" ]; then
        if ! host_adapter="$(jq_get_key_or_empty "$vm_info_json" ".ifaces.host.adapter" "true")"; then
            echo_red "Cannot extract hostonly adapter: $host_adapter"
            return 1
        fi
        
        local host_iface=""
        if ! host_iface="$(virtualbox_extract_host_iface "$attach_address" "$host_adapter")"; then
            echo_red "$host_iface"
            return 1
        fi

        if ! host_iface="$(grep --color=never "Output" <<<"$host_iface")"; then
            echo_red "Cannot exctract output for host interface"
            return 1
        fi

        local -a host_iface_part=()
        IFS=";" read -r -a host_iface_part <<< "$host_iface"

        if [[ "${#host_iface_part[@]}" != "3" ]]; then
            echo_red "incorrect host interface result '$host_iface'. Have no 2 parts"
            return 1
        fi

        host_adapter="${host_iface_part[1]}"
        attach_address="${host_iface_part[2]}"
    else
        echo_green "Host interface not found for vm. Try to extract..."
        local host_iface=""
        if ! host_iface="$(virtualbox_extract_host_iface "$attach_address")"; then
            echo_red "$host_iface"
            return 1
        fi

        if ! host_iface="$(grep --color=never "Output" <<<"$host_iface")"; then
            echo_red "Cannot exctract output for host interface"
            return 1
        fi

        local -a host_iface_part=()
        IFS=";" read -r -a host_iface_part <<< "$host_iface"

        echo "$host_iface"

        if [[ "${#host_iface_part[@]}" != "3" ]]; then
            echo_red "incorrect host interface result '$host_iface'. Have no 2 parts"
            return 1
        fi

        host_adapter="${host_iface_part[1]}"
        attach_address="${host_iface_part[2]}"

        local iface_indx="$(($nat_index + 1))"

        echo_green "Attach $host_adapter with index $iface_indx ..."

        if ! vboxmanage modifyvm "$vm_name" "--nic$iface_indx" hostonly "--host-only-adapter$iface_indx" "$host_adapter" "--cable-connected${iface_indx}" on; then
            echo_red "Failed attach $host_adapter with index $iface_indx"
            return 1
        fi

        local vm_info_json_after_add=""

        if ! vm_info_json_after_add="$(virtualbox_get_vm_info_json "$vm_name")"; then
            echo_red "Cannot get vm info: $vm_info_json_after_add"
            return 1
        fi

        if ! host_mac="$(jq_get_key_or_empty "$vm_info_json_after_add" ".ifaces.host.mac" "false")"; then
            echo_red "Cannot extract hostonly mac: $host_mac"
            return 1
        fi
    fi

    echo_green "Got next vm info:"
    echo_green "  NAT mac:          $nat_mac"
    echo_green "  Host adapter mac: $host_mac"
    echo_green "  Attach address:   $attach_address"

    if [[ "$skip_vsio" != "$CONST_FLAG_SET" ]]; then
        local opticals_str=""
        if ! opticals_str="$(jq_get_key_or_empty "$vm_info_json" '.opticals | join(";")' "false")"; then
            echo_red "Cannot get opticals from vm info: $vm_info_json"
            return 1
        fi

        local -a opticals_to_unmount=()
        IFS=";" read -ra opticals_to_unmount <<< "$opticals_str"
        
        echo_green "Prepare vsio..."

        local viso_file=""
        if ! viso_file="$(virtualbox_prepare_viso "$vm_name" "$nat_mac" "$host_mac" "$attach_address" "$ssh_key_file")"; then
            echo_red "Cannot prepare viso: $viso_file"
            return 1
        fi

        echo_green "Unmount opticals '${opticals_to_unmount[*]}' ..."

        if ! virtualbox_unmount_opticals "$vm_name" "${opticals_to_unmount[@]}"; then
            return 1
        fi

        echo_green "Mount init viso..."

        if ! virtualbox_mount_opticals "$vm_name" "$viso_file"; then
            return 1
        fi

        echo_green "Start vm..."

        if ! virtualbox_start_vm "$vm_name"; then
            return 1
        fi

        echo_green "Vm started and init viso mount"
        echo_green "Please run in vm for initialize:"
        echo_green "sudo -i"
        echo_green "mkdir -p /root/init && mount /dev/sr0 /root/init && /root/init/init.sh | tee /root/init.log"
        echo_green "After init please verify connection"

        if ask_user "Vm init and initialize? Do you want to cleanup?"; then
            if ! virtualbox_unmount_cleanup_after_init "$vm_name" "$viso_file"; then
                echo_yellow "^^^ Cleanup failed"
            fi
            echo_green "Virtualbox vm initialized!"
            return 0
        fi

        echo_yellow "Virtualbox vm initialized but not cleanuped!"
    fi

    return 0
}

# shellcheck disable=SC2329
function cmd_virtualbox_init_vm_help() {
    echo -n "
    Init virtualbox vm.
    This command SHOULD run on host!
    Find hostonly adapter in vm and add if not found.
    Find Hostonly adapter for connect, if have multiple,
    ask user for choice adapter. 
    Also get last octet for assign address and get
    interfaces mac's.
    Prepare virtual iso image with init scripts, mount it
    and start vm.
    After start vm you need mount sr0 interface and run
    init.sh script that called cmd virtualbox_init_vm_itself command
    with consumed params.
    Init script install sshd, prepare users (copy public keys for users
    and remove sudo passwords for users) and call netplan
    with init interfaces. After all unmount sr0
    This command waiting for user init vm and run cleanup
    (stop vm, remove init optical from vm and start vm).
    Options:
      --virtualbox-vm-name NAME
         Name for init vm.
         Can be set with env VIRTUALBOX_VM_NAME
      --virtualbox-attach-address IP_ADDRESS
         Full ipv4 address to set to hostonly interface.
         Optional. 
         If not passed get hostonly interface to connect 
         and get last octet for fill full address.
         If passed find hostonly interface to connect
         and check that address in subnet (script means
         that adapter has /24 network).
         Can be set with env VIRTUALBOX_ATTACH_ADDRESS
      --virtualbox-ssh-key PATH
         Path to ssh public key to set for all logable users,
         expected of root.
         Optional. 
         If not pass, prepare empty file for init viso.
         virtualbox_init_vm_itself checks that file exists and not empty.
         Can be set with env VIRTUALBOX_SSH_KEY
      --virtualbox-skip-prepare-init-iso
         If pass optical drive with init not preparead and mount
         Optional. 
         Can be set with env VIRTUALBOX_SKIP_PREPARE_INIT_ISO

"
}