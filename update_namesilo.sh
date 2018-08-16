# Distributed under the terms of the GNU General Public License (GPL) version 2.0
#
# A DDNS script to send updates to NameSilo for OpenWrt/LEDE
#

# Check configurations
[ -z "$WGET_SSL" ] && write_log 13 "GNU Wget with SSL support not found"
[ -z "$password" ] && write_log 13 "Missing API token"
[ -z "$domain" ] && write_log 13 "Missing domain"

# Force HTTPS
[ $use_https -eq 0 ] && use_https=1

# API token
local KEY=$password

# The type of resources record to add
[ $use_ipv6 -eq 0 ] && local RRTYPE="A" || local RRTYPE="AAAA"

# The value for the resource record (aka IP address)
local RRVALUE=$__IP

# The TTL for the new record (would not change if not provided)
[ -z "$param_opt" ] || local RRTTL=$param_opt

# The response from NameSilo
local RESPONSE

# The unique ID of the resource record
local RRID

# Copied from acme.sh
# Search a string using Regex
# Parameters    $1  Regex
_egrep_o() {
    if ! egrep -o "$1" 2>/dev/null; then
        sed -n 's/.*\('"$1"'\).*/\1/p'
    fi
}

# Modified from acme.sh
# Return a string that contains a sub-string
# Parameters    $1  A string
#               $2  A sub-string
_contains() {
    local _str="$1"
    local _sub="$2"
    echo "$_str" | grep -- "$_sub" >/dev/null 2>&1
}

# Get things from NameSilo using GUN Wget
# Parameters    $1          Operation
#               $2          Request string (no need to parse "version=1&type=xml&key=$KEY")
# Will get      $RESPONSE   Response
get_namesilo() {
    local URL="https://www.namesilo.com/api/$1?version=1&type=xml&key=$KEY&$2"
    local ERR=0
    local CMD="$WGET_SSL -nv -t 1 -O $DATFILE -o $ERRFILE '$URL'"
    eval "$CMD"
    ERR=$?
    [ $ERR -eq 0 ] && RESPONSE=$(cat $DATFILE) && return 0
    write_log 3 "$CMD Error: '$ERR'"

    # Here I want to use "write_log 17 '$(cat $ERRFILE)'", but I found out that it won't stop DDNS. So I
    # combine 7 and 16 to keep the output format and stop DDNS. The following code is also used like this.
    write_log 7 "$(cat $ERRFILE)"
    write_log 16
}

# Modified from dns_namesilo.sh _get_root()
# A function to split FQDN
# Will get  $RRHOST The hostname for the record
#           $DOMAIN The domain being requested and associated with the DNS resource record to modify
split_domain() {
    local i=2
    local p=1

    # Domain part
    local domain_part

    # Get FQDN string parts count e.g. "www.namesilo.com" have 3 parts
    local numfields=$(echo "$domain" | _egrep_o "\." | wc -l)

    # Get active domains
    get_namesilo "listDomains" ""

    # Compare them
    # Need to exclude the last field (tld)
    while [ $i -le "$numfields" ]; do
        domain_part=$(printf "%s" "$domain" | cut -d . -f $i-100)
        if [ -z "$domain_part" ]; then
            write_log 3 "Unable to find domain specified"
            write_log 15 "Response from NameSilo: $RESPONSE"
        fi
        if _contains "$RESPONSE" "$domain_part"; then
            RRHOST=$(printf "%s" "$domain" | cut -d . -f 1-$p)
            DOMAIN="$domain_part"
            write_log 7 "Domain $DOMAIN in NameSilo found"
            write_log 7 "The host name is $RRHOST"
            return 0 # Find a match
        fi
        p=$i
        i=$(($i + 1))
    done

    # Check if it is naked domain
    if _contains "$RESPONSE" "<domain>$domain</domain>"; then
        DOMAIN="$domain"
        write_log 7 "Domain $DOMAIN in NameSilo found"
        return 0 # Naked domain
    fi

    write_log 3 "Unable to find domain specified"
    write_log 7 "Response from NameSilo: $RESPONSE"
    write_log 16
}

# Update a record
update_namesilo() {
    local retcode

    split_domain

    # Modified from dns_namesilo.sh dns_namesilo_rm()
    # Retrieve the record id
    if get_namesilo "dnsListRecords" "domain=$DOMAIN"; then
        retcode=$(printf "%s\n" "$RESPONSE" | _egrep_o "<code>300")
        # Escape * wildcard
        if [ "$RRHOST" == "*" ]; then
            domain="\\"${domain}
        fi
        if [ "$retcode" ]; then
            local has_value=$(printf "%s\n" "$RESPONSE" |
                _egrep_o "<host>$domain</host><value>$__IP</value>")
            if [ "$has_value" ]; then
                write_log 4 "Skip this time since your device IP is the same as NameSilo recorded"
                return 0
            else
                RRID=$(printf "%s\n" "$RESPONSE" |
                    _egrep_o "<record_id>([^<]*)</record_id><type>$RRTYPE</type><host>$domain</host>" |
                    _egrep_o "<record_id>([^<]*)</record_id>" |
                    sed -r "s/<record_id>([^<]*)<\/record_id>/\1/" | tail -n 1)
                if [ -z "$RRTTL" ]; then
                    RRTTL=$(printf "%s\n" "$RESPONSE" |
                        _egrep_o "<host>$domain</host><value>$__IP</value><ttl>([^<]*)</ttl>" |
                        _egrep_o "<ttl>([^<]*)</ttl>" | sed -r "s/<ttl>([^<]*)<\/ttl>/\1/" | tail -n 1)
                fi
                write_log 7 "Successfully retrieved the record id from NameSilo"
            fi
        else
            write_log 3 "Unable to retrieve the record id."
            write_log 7 "Response from NameSilo: $RESPONSE"
            write_log 16
        fi
    fi

    # Update record
    if get_namesilo "dnsUpdateRecord" "domain=$DOMAIN&rrid=$RRID&rrhost=$RRHOST&rrvalue=$RRVALUE&rrttl=$RRTTL"; then
        retcode=$(printf "%s\n" "$RESPONSE" | _egrep_o "<code>300")
        if [ "$retcode" ]; then
            write_log 7 "Successfully update the record"
            # Once update success it may take up to 15 minutes to complete process
            if [ $CHECK_SECONDS -lt 900 ]; then
                local sleep_sec=$((900 - $CHECK_SECONDS))
                write_log 6 "It may take up to 15 minutes to complete process but check_interval is less than 15 minuite"
                write_log 7 "Waiting for additional $sleep_sec seconds"
                sleep "$sleep_sec"
            fi
        else
            write_log 3 "Failed to update the record"
            write_log 7 "Response from NameSilo: $RESPONSE"
            write_log 16
        fi
    fi
}

# Start update
update_namesilo
