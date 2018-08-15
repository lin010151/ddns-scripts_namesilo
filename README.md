# OpenWrt/LEDE Dynamic DNS (DDNS) Client scripts extension for NameSilo

A DDNS script to send updates to NameSilo for OpenWrt/LEDE.

中文版本请参阅 [README_CN.md](/README_CN.md)。

## Before Read...

My English is rough. If you are misguided by my word, I'm sorry, and I will help explain it~~

## Before Use...

[NameSilo](https://www.namesilo.com) is not a DDNS provider.

If your public IP address changes too frequent (like about 5 to 15 minutes or less, details see [notes](#Notes)), I don't recommend you to use this script, unless you are so familiar with [the theories of DNS](https://en.wikipedia.org/wiki/Domain_Name_System) and solutions related, and know what to do.

## Requirements

- A dynamic public IP address
- NameSilo API token, can generate one at https://www.namesilo.com/account_api.php
- GNU Wget with SSL support, can install it using `opkg install wget` command

## General Process Flow

First, use [`listDomains`](https://www.namesilo.com/api_reference.php#listDomains) to get the active domain list in NameSilo. Then the script will compare the [fully qualified domain name (FQDN)](https://en.wikipedia.org/wiki/Fully_qualified_domain_name) you filled in with the domain list. If success, then split the FQDN into host name and domain.

Next, submit domain name to [`dnsListRecords`](https://www.namesilo.com/api_reference.php#dnsListRecords) to get the DNS record list which related to the domain needed to update. Then it will compare the FQDN with the list. If success, then get record ID related.

Finally, update by submitting the record ID and the IP address aquired by DDNS client to [`dnsUpdateRecord`](https://www.namesilo.com/api_reference.php#dnsUpdateRecord).

## Known Issuse

- Can not use DDNS client to stop DDNS process while doing extra timeout (sleep). But it can be stopped by first stop `sleep` process.

## Files

- [LICENSE](/LICENSE) The full document of GNU General Public License（GPL）v2.0
- [README_CN.md](/README_CN.md) Readme (Simplified Chinese)
- [README.md](/README.md) Readme（default language, aka English）
- [update_namesilo_cn.sh](/update_namesilo_cn.sh) Script in Simplified Chinese
- [update_namesilo.sh](/update_namesilo.sh) Script in default language

## Instructions

Activated inside `/etc/config/ddns` by setting

```
option update_script    "/path/to/update_namesilo.sh"   # Absolute path to the script

option password         "API_token"                     # Your unique NameSilo API

option domain           "www.example.com"               # The FQDN that needs to update real time
                                                        # DNS wildcard records via the "*" character are supported
                                                        # Multiple hostnames not supported for now
                                                        
option param_opt        "7207"                          # Record's time-to-live (TTL，would not change if not provided)
```

DNS wildcard records see [NameSilo support page for DNS Manager](https://www.namesilo.com/Support/DNS-Manager).

Other options see [Dynamic DNS Client configuration](https://openwrt.org/docs/guide-user/base-system/ddns).

Complete configurations see [DDNS Client](https://openwrt.org/docs/guide-user/services/ddns/client).

You can also configure it using [UCI](https://openwrt.org/start?id=zh/docs/guide-user/base-system/uci) or using OpenWrt/LEDE Web Interface.

## To-do List

- Merge all the other DDNS client configurations (like force update) into the script to let the DDNS client have a better control.
- Multiple hostnames support.

## References

- [NameSilo API references](https://www.namesilo.com/api_reference.php)
- [ACME Shell script](https://acme.sh), and [dns_namesilo.sh](https://github.com/Neilpang/acme.sh/blob/master/dnsapi/dns_namesilo.sh) file
- https://github.com/openwrt/packages/tree/master/net/ddns-scripts

## Notes

After you modify one record in NameSilo's DNS manager, it shows up:

> We publish DNS changes every 15 minutes. However, your change(s) may take a good deal longer to appear like they are working. This seeming delay is typically due to browser and/or DNS cache. Unfortunately, these issues are completely out of our control. You can read more about these issues on our [DNS Troubleshooting page](https://www.namesilo.com/Support/DNS-Troubleshooting).<br><br>
> Rest assured that there are absolutely no delays on our end. Your DNS change(s) will be published in no longer than 15 minutes, but cache issues could take up to 48 hours to resolve permanently.

However, in NameSilo's [DNS Troubleshooting page](https://www.namesilo.com/Support/DNS-Troubleshooting), it saids:

> ...
> Next, please remember that we only push DNS changes every 5 minutes. If your DNS change does not appear to be working after 5 minutes, and you have not recently updated the applicable domain(s) to use our name servers, it is very likely the result of browser and/or DNS caching.
> ...

## License & Others

[acme.sh](https://acme.sh) written by @Neilpang (specially [dns_namesilo.sh](https://github.com/Neilpang/acme.sh/blob/master/dnsapi/dns_namesilo.sh) written by @meowthink) can apply an SSL certificate from [Let’s Encrypt](https://letsencrypt.org) in OpenWrt/LEDE by making good use of NameSilo API. Because of that (and also because I am a newbie in bash that I can't translate my thoughts into scripts), my script is referencing by their scripts, to interact with NameSilo.

At the same time, the script is also referencing by [codes and samples from dynamic DNS client script in github](https://github.com/openwrt/packages/tree/master/net/ddns-scripts). They make my script parsable with dynamic DNS client.

Thank you all.

You are welcomed to give suggestions (or help debug and modify it). Thanks.

Distributed under the terms of the GNU General Public License (GPL) version 2.0.
