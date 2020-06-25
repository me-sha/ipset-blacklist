#!/bin/bash
#
# usage ipset-fw.sh <configuration file>
# eg: ipset-fw.sh /etc/ipset-fw/ipset-fw.conf
#
CONFIG_FILE="/etc/ipset-fw/ipset-fw.conf"
if [[ ! -z "$1" ]]; then
    CONFIG_FILE="$1"
fi
if [[ ! -e "$CONFIG_FILE" ]]; then
    echo "Error: please provide a configuration file at the default path: '/etc/ipset-fw/ipset-fw.conf'" \
         "or as an argument e.g.: $0 /path/to/ipset-fw.conf"
    exit 1
fi

if ! source "$CONFIG_FILE"; then
    echo "Error: can't load configuration file $2"
    exit 1
fi

if ! which curl egrep grep ipset iptables sed sort wc &> /dev/null; then
    echo >&2 "Error: searching PATH fails to find executables among: curl egrep grep ipset iptables sed sort wc"
    exit 1
fi

if [[ ! -d $(dirname "$IP_BLACKLIST") || ! -d $(dirname "$IP_WHITELIST") || ! -d $(dirname "$IPSET_RESTORE") ]]; then
    echo >&2 "Error: missing directory(s): $(dirname "$IP_BLACKLIST" "$IP_WHITELIST" "$IPSET_RESTORE"|sort -u)"
    exit 1
fi

touch $IP_BLACKLIST $IP_WHITELIST

if [[ -n "$DEBUG" ]]; then
    echo "DEBUG='$DEBUG'"
    set -ex
fi

# create the ipset if needed (or abort if does not exists and FORCE=no)
function create_ipset(){
IPSET_NAME=${1}
if ! ipset list -n|command grep -q "$IPSET_NAME"; then
    if [[ ${FORCE:-no} != yes ]]; then
        echo >&2 "Error: ipset does not exist yet, add it using:"
        echo >&2 "# ipset create $IPSET_NAME -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}"
        exit 1
    fi
    if ! ipset create "$IPSET_NAME" -exist hash:net family inet hashsize "${HASHSIZE:-16384}" maxelem "${MAXELEM:-65536}"; then
      	echo >&2 "Error: while creating the initial ipset"
      	exit 1
    fi
fi
}
create_ipset $IPSET_BLACKLIST_NAME
create_ipset $IPSET_WHITELIST_NAME


# create the iptables binding if needed (or abort if does not exists and FORCE=no)
function create_iptables(){
IPSET_NAME=${1}
ACTION=${2}

if ! iptables -nvL ipset-fw 2>&1 | command grep -q 'ipset-fw'; then
    if [[ ${FORCE:-no} != yes ]]; then
        echo >&2 "Error: iptables does not have the needed ipset-f chain, add it using:"
        echo >&2 "# iptables -N ipset-fw"
        exit 1
    fi
    if ! iptables -N ipset-fw; then
        echo >&2 "Error: while adding the ipset-fw chain."
        exit 1
    fi
fi
if ! iptables -nvL ipset-fw 2>&1 | command grep -q "match-set $IPSET_NAME"; then
    if [[ ${FORCE:-no} != yes ]]; then
        echo >&2 "Error: iptables does not have the needed ipset INPUT rule, add it using:"
        echo >&2 "# iptables -I ipset-fw 1 -m set --match-set $IPSET_NAME src -j $ACTION"
        exit 1
    fi
    if ! iptables -I ipset-fw 1 -m set --match-set "$IPSET_NAME" src -j $ACTION; then
        echo >&2 "Error: while adding the --match-set $IPSET_NAME ipset rule to iptables ipset-fw chain"
        exit 1
    fi
fi

if ! iptables -nvL INPUT 2>&1 | command grep -q "ipset-fw"; then
    # we may also have assumed that INPUT rule n°1 is about packets statistics (traffic monitoring)
    if [[ ${FORCE:-no} != yes ]]; then
        echo >&2 "Error: iptables does not have the needed ipset-fw INPUT rule, add it using:"
        echo >&2 "# iptables -I INPUT ${IPTABLES_IPSET_RULE_NUMBER:-1} -j ipset-fw"
        exit 1
    fi
    if ! iptables -I INPUT "${IPTABLES_IPSET_RULE_NUMBER:-1}" -j ipset-fw; then
        echo >&2 "Error: while adding the INPUT ipset-fw rule to iptables"
        exit 1
    fi
fi

}
create_iptables $IPSET_BLACKLIST_NAME "DROP"
create_iptables $IPSET_WHITELIST_NAME "RETURN"

# fetch lists and add them to ipsets
function fetch_lists(){
declare -a SOURCES=("${!1}")
local IPSET_NAME=${2}
local IP_LIST=${3}

if [ ${#SOURCES[@]} -eq 0 ]; then
    [[ ${VERBOSE:-no} == yes ]] && echo "$0: No lists specified to fetch for $IPSET_NAME."
    return
fi

local TMP_LIST_FILE="/tmp/$IPSET_NAME$TMP_PFIX"

for i in "${SOURCES[@]}"
do
    IP_TMP=$(mktemp)
    let HTTP_RC=`curl -L -A "blacklist-update/script/github" --connect-timeout 10 --max-time 10 -o $IP_TMP -s -w "%{http_code}" "$i"`
    if (( $HTTP_RC == 200 || $HTTP_RC == 302 || $HTTP_RC == 0 )); then # "0" because file:/// returns 000
      command grep -Po '(?:\d{1,3}\.){3}\d{1,3}(?:/\d{1,2})?' "$IP_TMP" >> "$TMP_LIST_FILE"
      [[ ${VERBOSE:-yes} == yes ]] && echo -n "."
    elif (( $HTTP_RC == 503 )); then
        echo -e "\nUnavailable (${HTTP_RC}): $i"
    else
        echo >&2 -e "\nWarning: curl returned HTTP response code $HTTP_RC for URL $i"
    fi
    rm -f "$IP_TMP"
done

## extract ip4 adresses
#sed -r -e '/^(0\.0\.0\.0|10\.|127\.|172\.1[6-9]\.|172\.2[0-9]\.|172\.3[0-1]\.|192\.168\.|22[4-9]\.|23[0-9]\.)/d' "$IPSET_NAME$TMP_PFIX"|sort -n|sort -mu >| "$IP_LIST"
cat "$TMP_LIST_FILE"|sort -n|sort -mu >| "$IP_LIST"

rm -f "$TMP_LIST_FILE"

cat >> "$IPSET_RESTORE" <<EOF
create $IPSET_NAME$TMP_PFIX -exist hash:net family inet hashsize ${HASHSIZE:-16384} maxelem ${MAXELEM:-65536}
EOF

## create ipset restore file
sed -rn -e '/^#|^$/d' \
    -e "s/^([0-9./]+).*/add $IPSET_NAME$TMP_PFIX \1/p" "$IP_LIST" >> "$IPSET_RESTORE"

cat >> "$IPSET_RESTORE" <<EOF
swap $IPSET_NAME $IPSET_NAME$TMP_PFIX
destroy $IPSET_NAME$TMP_PFIX
EOF
}
echo "" > "$IPSET_RESTORE"
fetch_lists BLACKLISTS[@] $IPSET_BLACKLIST_NAME $IP_BLACKLIST
fetch_lists WHITELISTS[@] $IPSET_WHITELIST_NAME $IP_WHITELIST

# create ipsets from file and ensure persistance
ipset -file  "$IPSET_RESTORE" restore
## restored by ipset.service at reboot
ipset save > /etc/ipset.conf

if [[ ${VERBOSE:-no} == yes ]]; then
    echo
    echo "Number of blacklisted IP/networks found: `wc -l $IP_BLACKLIST | cut -d' ' -f1`"
    echo "Number of whitelisted IP/networks found: `wc -l $IP_WHITELIST | cut -d' ' -f1`"
fi
