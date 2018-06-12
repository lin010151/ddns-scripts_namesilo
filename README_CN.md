# 用于 NameSilo 的 OpenWrt/LEDE 动态 DNS（DDNS）客户端脚本扩展

向 NameSilo 提交更新的，用于 OpenWrt/LEDE 的 DDNS 脚本。

For English version, see [README.md](/README.md).

## 使用须知

[NameSilo](https://www.namesilo.com) 并不是一个 DDNS 提供商。

如果你的公共 IP 地址的变化时间太快（大概 5 至 15 分钟以内或者以下，具体情况见[注释](#注释)），那么不建议使用这个脚本，除非你很了解 [DNS 的一些原理和解决方法](https://zh.wikipedia.org/wiki/%E5%9F%9F%E5%90%8D%E7%B3%BB%E7%BB%9F)，知道怎么做。

## 使用前提

- 动态公共 IP
- NameSilo API 令牌，可从 https://www.namesilo.com/account_api.php 获得；
- 含有 SSL 支持的 GNU Wget，可通过 `opkg install wget` 安装。

## 程序大致流程

先用 [`listDomains`](https://www.namesilo.com/api_reference.php#listDomains) 获取在 NameSilo 的所有有效的域名列表，然后将你填入的[全限定域名（FQDN）](https://zh.wikipedia.org/wiki/%E5%AE%8C%E6%95%B4%E7%B6%B2%E5%9F%9F%E5%90%8D%E7%A8%B1)和该域名列表进行匹配，如果匹配成功，则将 FQDN 拆分成主机名和域名。

之后将域名传递给 [`dnsListRecords`](https://www.namesilo.com/api_reference.php#dnsListRecords) 来获取需要进行更新的域名的所有 DNS 记录列表，然后将 FQDN 和该列表进行匹配，如果匹配成功，则获取对应的记录 ID。

最后将记录 ID 和 DDNS 客户端获取到的 IP 传递给 [`dnsUpdateRecord`](https://www.namesilo.com/api_reference.php#dnsUpdateRecord) 进行更新。

## 已知问题

- 在进行额外暂停的时候，没办法用 DDNS 客户端自带的程序来中止 DDNS 进程，只能先在系统进程中结束 `sleep` 进程才能进而结束 DDNS 进程。

## 文件说明

- [LICENSE](/LICENSE) GNU 通用公共许可证（GPL）2.0 版本文本
- [README_CN.md](/README_CN.md) 说明（中文）
- [README.md](/README.md) 说明（默认语言，也就是英语）
- [update_namesilo_cn.sh](/update_namesilo_cn.sh) 中文脚本
- [update_namesilo.sh](/update_namesilo.sh) 默认语言脚本

## 使用方法

在 `/etc/config/ddns` 相应的条目添加如下配置：

```
option update_script    "/path/to/update_namesilo_cn.sh"    # 该脚本文件的绝对路径
option password         "API_token"                         # 你唯一的 NameSilo API 令牌
option domain           "www.example.com"                   # 需要实时更新的 FQDN
option param_opt        "7207"                              # 记录的存活时间 (TTL，不填则不修改原有设置)
```

其他参数请参阅[动态 DNS 客户端配置（英文）](https://openwrt.org/docs/guide-user/base-system/ddns)。

完整的配置方法请参阅[DDNS 客户端（英文）](https://openwrt.org/docs/guide-user/services/ddns/client)。

也可以在 [UCI](https://openwrt.org/start?id=zh/docs/guide-user/base-system/uci)或者 OpenWrt/LEDE 网页界面进行配置。

## 待做事项

- 将 DDNS 客户端的其他选项（例如强制更新）整合进来，让 DDNS 客户端更好地控制该脚本的运行

## 参考链接

- [NameSilo API 参考（英文）](https://www.namesilo.com/api_reference.php)
- [ACME Shell 脚本](https://acme.sh)，以及 [dns_namesilo.sh](https://github.com/Neilpang/acme.sh/blob/master/dnsapi/dns_namesilo.sh) 文件
- https://github.com/openwrt/packages/tree/master/net/ddns-scripts

## 注释

当你在 NameSilo 的 DNS 管理器上修改一个记录后，会出现该提示：

> We publish DNS changes every 15 minutes. However, your change(s) may take a good deal longer to appear like they are working. This seeming delay is typically due to browser and/or DNS cache. Unfortunately, these issues are completely out of our control. You can read more about these issues on our [DNS Troubleshooting page](https://www.namesilo.com/Support/DNS-Troubleshooting).<br><br>
> Rest assured that there are absolutely no delays on our end. Your DNS change(s) will be published in no longer than 15 minutes, but cache issues could take up to 48 hours to resolve permanently.

然而在 NameSilo 的 [DNS 疑难解答页面](https://www.namesilo.com/Support/DNS-Troubleshooting)上，NameSilo 又说道：

> ...
> Next, please remember that we only push DNS changes every 5 minutes. If your DNS change does not appear to be working after 5 minutes, and you have not recently updated the applicable domain(s) to use our name servers, it is very likely the result of browser and/or DNS caching.
> ...

## 许可证和其他

@Neilpang 的 [acme.sh](https://acme.sh)（特别是 @meowthink 在 [acme.sh](https://acme.sh) 上提交的 [dns_namesilo.sh](https://github.com/Neilpang/acme.sh/blob/master/dnsapi/dns_namesilo.sh)）脚本可以很好地利用 NameSilo API，在 OpenWrt/LEDE 上申请到 [Let’s Encrypt](https://letsencrypt.org) 的 SSL 证书。鉴于此（也鉴于我是 Bash 菜鸟，有思路但转换不成脚本），该脚本参考了他们的代码，来和 NameSilo 进行交互。

同时，该脚本也参阅了[动态 DNS 客户端脚本在 GitHub 上的代码和示例](https://github.com/openwrt/packages/tree/master/net/ddns-scripts)，可以使得脚本能被动态 DNS 客户端脚本中插入。

真心感谢你们。

欢迎各位提出意见，或者帮忙调试修改（可以的话也帮忙检查一下翻译，本人英语水平，特别是中文翻译成英语，不高🤦‍），谢谢~

在 GNU 通用公共许可证（GPL）2.0 版本条款下发布。
