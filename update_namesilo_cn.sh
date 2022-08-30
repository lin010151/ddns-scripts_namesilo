# 在 GNU 通用公共许可证（GPL）2.0 版本条款下发布
#
# 向 NameSilo 提交更新的，用于 OpenWrt/LEDE 的 DDNS 脚本
#

# 检查配置
[ -z "$WGET_SSL" ] && write_log 13 "含有 SSL 支持的 GNU Wget 未找到"
[ -z "$password" ] && write_log 13 "缺少 API 令牌"
[ -z "$domain" ] && write_log 13 "缺少 FQDN"

# 强制使用 HTTPS
[ $use_https -eq 0 ] && use_https=1

# API 令牌
local KEY=$password

# 记录类型
[ $use_ipv6 -eq 0 ] && local RRTYPE="A" || local RRTYPE="AAAA"

# 记录的值，也就是当前 IP 地址
local RRVALUE=$__IP

# 修改后的 TTL，如果没有提供，则保留原来的值
[ -z "$param_opt" ] || local RRTTL=$param_opt

# NameSilo 的响应
local RESPONSE

# 记录的唯一 ID
local RRID

# 拷贝自 acme.sh
# 用正则表达式来搜索字符串
# 参数  $1  正则表达式
_egrep_o() {
    if ! egrep -o "$1" 2>/dev/null; then
        sed -n 's/.*\('"$1"'\).*/\1/p'
    fi
}

# 修改自 acme.sh
# 返回一个含有子字符串的字符串
# 参数  $1  一个字符串
# 　　  $2  一个子字符串
_contains() {
    local _str="$1"
    local _sub="$2"
    echo "$_str" | grep -- "$_sub" >/dev/null 2>&1
}

# 用 GUN Wget 从 NameSilo 获取东西
# 参数  $1          操作
# 　　  $2          请求字符串 (没必要传递“version=1&type=xml&key=$KEY”)
# 得到  $RESPONSE   响应
get_namesilo() {
    local URL="https://www.namesilo.com/api/$1?version=1&type=xml&key=$KEY&$2"
    local ERR=0
    local CMD="$WGET_SSL -nv -t 1 -O $DATFILE -o $ERRFILE '$URL'"
    eval "$CMD"
    ERR=$?
    [ $ERR -eq 0 ] && RESPONSE=$(cat $DATFILE) && return 0
    write_log 3 "$CMD 错误：'$ERR'"
    
    # 这里本来想用“write_log 17 "$(cat $ERRFILE)"”，结果发现用 17 无法停止掉 DDNS，
    # 只好结合着用 7 和 16 来保持输出格式的同时，停止 DDNS，之后的代码也是这样用的
    write_log 7 "$(cat $ERRFILE)"
    write_log 16
}

# 修改自 dns_namesilo.sh 的 _get_root()
# 分割 FQDN
# 得到  $RRHOST 记录的主机名
# 　　  $DOMAIN 需要修改的用于请求和与 DNS 记录关联的域名
split_domain() {
    local i=2
    local p=1

    # 域名部分
    local domain_part

    # 分割 FQDN 字符串后的份数，例如“www.namesilo.com”有 3 部分
    local numfields=$(echo "$domain" | _egrep_o "\." | wc -l)

    # 获取处于活动状态中的域名
    get_namesilo "listDomains" ""

    # 比较两个域名
    # 需要排除掉最后一部分（顶级域名）
    while [ $i -le "$numfields" ]; do
        domain_part=$(printf "%s" "$domain" | cut -d . -f $i-100)
        if [ -z "$domain_part" ]; then
            write_log 3 "找不到指定的域名"
            write_log 15 "NameSilo 响应：$RESPONSE"
        fi
        if _contains "$RESPONSE" "$domain_part"; then
            RRHOST=$(printf "%s" "$domain" | cut -d . -f 1-$p)
            DOMAIN="$domain_part"
            write_log 7 "在 NameSilo 中找到域名 $DOMAIN"
            write_log 7 "对应的主机名是 $RRHOST"
            return 0 # 找到一个匹配
        fi
        p=$i
        i=$(($i + 1))
    done

    # 检查是否是裸域名
    if _contains "$RESPONSE" "<domain[^>]*>$domain</domain>"; then
        DOMAIN="$domain"
        write_log 7 "Domain $DOMAIN in NameSilo found"
        return 0 # 裸域名
    fi

    write_log 3 "找不到指定的域名"
    write_log 7 "NameSilo 响应：$RESPONSE"
    write_log 16
}

# 更新记录
update_namesilo() {
    local retcode

    split_domain

    # 修改自 dns_namesilo.sh 的 dns_namesilo_rm()
    # 获取记录 ID
    if get_namesilo "dnsListRecords" "domain=$DOMAIN"; then
        retcode=$(printf "%s\n" "$RESPONSE" | _egrep_o "<code>300")
        # 转义 * 通配符
        if [ "$RRHOST" == "*" ]; then
            domain="\\"${domain}
        fi
        if [ "$retcode" ]; then
            local has_value=$(printf "%s\n" "$RESPONSE" |
                _egrep_o "<host>$domain</host><value>$__IP</value>")
            if [ "$has_value" ]; then
                write_log 4 "由于设备 IP 和 NameSilo 记录的 IP 一致，跳过这次更新"
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
                write_log 7 "成功从 NameSilo 获取到记录 ID"
            fi
        else
            write_log 3 "无法从 NameSilo 获取到记录 ID"
            write_log 7 "NameSilo 响应: $RESPONSE"
            write_log 16
        fi
    fi

    # 更新记录
    if get_namesilo "dnsUpdateRecord" "domain=$DOMAIN&rrid=$RRID&rrhost=$RRHOST&rrvalue=$RRVALUE&rrttl=$RRTTL"; then
        retcode=$(printf "%s\n" "$RESPONSE" | _egrep_o "<code>300")
        if [ "$retcode" ]; then
            write_log 7 "成功更新记录"
            # 一旦更新成功，则需要等待至少 15 分钟来完成后续工作
            if [ $CHECK_SECONDS -lt 900 ]; then
                local sleep_sec=$((900 - $CHECK_SECONDS))
                write_log 6 "需要等待至少 15 分钟来完成后续工作，但 check_interval 小于 15 分钟"
                write_log 7 "额外等待 $sleep_sec 秒..."
                sleep "$sleep_sec"
            fi
        else
            write_log 3 "更新记录失败"
            write_log 7 "NameSilo 响应: $RESPONSE"
            write_log 16
        fi
    fi
}

# 执行更新
update_namesilo
