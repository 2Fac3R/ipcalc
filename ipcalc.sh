#!/usr/bin/env bash
# IPv4 subnet calculator inspired by https://jodies.de/ipcalc

set -o nounset

usage() {
    cat <<'EOF'
Usage: ipcalc.sh ADDRESS [NETMASK [SUBNET_MASK [SUBNET_INDEX|ADDRESS]]]

NETMASK and SUBNET_MASK may be CIDR prefixes (/24 or 24), dotted decimal
masks, or inverse (wildcard) masks. If NETMASK is omitted, the classful
default is used. A SUBNET_MASK lists the subnet ranges within the network;
the optional final argument selects a subnet by zero-based index or address.
EOF
}

fail() { printf 'ipcalc: %s\n' "$*" >&2; exit 2; }

ip_to_int() {
    local ip=$1 part octet result=0
    [[ $ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    IFS=. read -r -a parts <<< "$ip"
    for part in "${parts[@]}"; do
        [[ $part =~ ^[0-9]+$ ]] || return 1
        # Force decimal interpretation (leading zeroes are allowed).
        octet=$((10#$part))
        (( octet <= 255 )) || return 1
        result=$(( (result << 8) | octet ))
    done
    REPLY=$result
}

int_to_ip() {
    local n=$1
    REPLY="$(( (n >> 24) & 255 )).$(( (n >> 16) & 255 )).$(( (n >> 8) & 255 )).$(( n & 255 ))"
}

int_to_bin() {
    local n=$1 i result='' octet
    for ((i=3; i>=0; i--)); do
        octet=$(( (n >> (i * 8)) & 255 ))
        printf -v result '%s%s%s' "$result" "$([[ $i -lt 3 ]] && printf '.')" "$(to_binary "$octet")"
    done
    REPLY=$result
}

to_binary() {
    local n=$1 i out=''
    for ((i=7; i>=0; i--)); do out+=$(( (n >> i) & 1 )); done
    printf '%s' "$out"
}

mask_for_prefix() {
    local p=$1
    [[ $p =~ ^[0-9]{1,2}$ ]] || return 1
    (( p >= 0 && p <= 32 )) || return 1
    if (( p == 0 )); then REPLY=0; else REPLY=$(( (0xffffffff << (32-p)) & 0xffffffff )); fi
}

parse_mask() {
    local value=${1#/} n inv p
    if [[ $value =~ ^[0-9]{1,2}$ ]]; then
        mask_for_prefix "$value" || return 1
        REPLY=$value
        return 0
    fi
    ip_to_int "$value" || return 1
    n=$REPLY
    # Accept either a contiguous netmask or a contiguous wildcard mask.
    for ((p=0; p<=32; p++)); do
        mask_for_prefix "$p"
        if (( REPLY == n )); then REPLY=$p; return 0; fi
        inv=$(( (~REPLY) & 0xffffffff ))
        if (( inv == n )); then REPLY=$p; return 0; fi
    done
    return 1
}

prefix_of() {
    local mask=$1 p
    for ((p=0; p<=32; p++)); do mask_for_prefix "$p"; (( REPLY == mask )) && { REPLY=$p; return; }; done
}

is_private() {
    local ip=$1
    (( (ip & 0xff000000) == 0x0a000000 ||
       (ip & 0xfff00000) == 0xac100000 ||
       (ip & 0xffff0000) == 0xc0a80000 ))
}

print_network() {
    local addr=$1 prefix=$2 label=${3:-} mask wildcard network broadcast hosts min max class
    mask_for_prefix "$prefix"; mask=$REPLY
    wildcard=$(( (~mask) & 0xffffffff ))
    network=$(( addr & mask )); broadcast=$(( network | wildcard ))
    if (( prefix <= 30 )); then min=$((network+1)); max=$((broadcast-1)); hosts=$(( (1 << (32-prefix)) - 2 ));
    elif (( prefix == 31 )); then min=$network; max=$broadcast; hosts=2
    else min=$network; max=$network; hosts=1; fi
    int_to_ip "$addr"; local addr_s=$REPLY; int_to_bin "$addr"; local addr_b=$REPLY
    int_to_ip "$mask"; local mask_s=$REPLY; int_to_bin "$mask"; local mask_b=$REPLY
    int_to_ip "$wildcard"; local wild_s=$REPLY; int_to_bin "$wildcard"; local wild_b=$REPLY
    int_to_ip "$network"; local net_s=$REPLY; int_to_bin "$network"; local net_b=$REPLY
    int_to_ip "$broadcast"; local broad_s=$REPLY; int_to_bin "$broadcast"; local broad_b=$REPLY
    int_to_ip "$min"; local min_s=$REPLY; int_to_bin "$min"; local min_b=$REPLY
    int_to_ip "$max"; local max_s=$REPLY; int_to_bin "$max"; local max_b=$REPLY
    local first=${addr_s%%.*}; first=$((10#$first))
    if (( first < 128 )); then class=A; elif (( first < 192 )); then class=B; elif (( first < 224 )); then class=C; elif (( first < 240 )); then class=D; else class=E; fi
    [[ -n $label ]] && printf '%s\n' "$label"
    printf 'Address:   %-18s %s\n' "$addr_s" "$addr_b"
    printf 'Netmask:   %-18s %s\n' "$mask_s = $prefix" "$mask_b"
    printf 'Wildcard:  %-18s %s\n' "$wild_s" "$wild_b"
    printf '=>\n'
    printf 'Network:   %-18s %s (Class %s)\n' "$net_s/$prefix" "$net_b" "$class"
    printf 'Broadcast: %-18s %s\n' "$broad_s" "$broad_b"
    printf 'HostMin:   %-18s %s\n' "$min_s" "$min_b"
    printf 'HostMax:   %-18s %s\n' "$max_s" "$max_b"
    printf 'Hosts/Net: %s' "$hosts"
    is_private "$addr" && printf ' (Private Internet)'
    printf '\n'
}

(( $# >= 1 && $# <= 4 )) || { usage >&2; exit 2; }
[[ $1 == -h || $1 == --help ]] && { usage; exit 0; }
ip_to_int "$1" || fail "invalid IPv4 address: $1"
address=$REPLY

if (( $# >= 2 )) && [[ -n $2 ]]; then
    parse_mask "$2" || fail "invalid netmask: $2"
    prefix=$REPLY
else
    first=${1%%.*}; first=$((10#$first))
    if (( first < 128 )); then prefix=8; elif (( first < 192 )); then prefix=16; else prefix=24; fi
fi
print_network "$address" "$prefix"

if (( $# >= 3 )) && [[ -n $3 ]]; then
    parse_mask "$3" || fail "invalid subnet mask: $3"
    subprefix=$REPLY
    mask_for_prefix "$prefix"; parentmask=$REPLY
    parent=$(( address & parentmask ))
    mask_for_prefix "$subprefix"; submask=$REPLY
    if (( subprefix >= prefix )); then
        count=$(( 1 << (subprefix-prefix) ))
        size=$(( 1 << (32-subprefix) ))
        printf '\nSubnets: %s networks of /%s within %s/%s\n' "$count" "$subprefix" "$(int_to_ip "$parent"; printf '%s' "$REPLY")" "$prefix"
        if (( count > 256 )); then printf 'Showing first 256; use a subnet index to select any subnet.\n'; limit=256; else limit=$count; fi
        selected=-1
        if (( $# == 4 )); then
            if [[ $4 =~ ^[0-9]+$ ]]; then selected=$((10#$4));
            else ip_to_int "$4" || fail "invalid subnet selector: $4"; selected=$(( (REPLY-parent) / size )); fi
            (( selected >= 0 && selected < count )) || fail "subnet selector is outside the parent network"
        fi
        if (( $# == 4 )); then start=$selected; end=$((selected+1)); else start=0; end=$limit; fi
        for ((i=start; i<end; i++)); do
            subnet=$(( parent + i*size )); last=$(( subnet + size - 1 ));
            int_to_ip "$subnet"; subnet_s=$REPLY; int_to_ip "$last"; last_s=$REPLY
            printf 'Subnet[%s]: %s/%s  range %s - %s\n' "$i" "$subnet_s" "$subprefix" "$subnet_s" "$last_s"
        done
    else
        supernet=$(( address & submask )); int_to_ip "$supernet"; super_s=$REPLY
        printf '\nSupernet: %s/%s contains %s/%s\n' "$super_s" "$subprefix" "$(int_to_ip "$parent"; printf '%s' "$REPLY")" "$prefix"
    fi
fi
