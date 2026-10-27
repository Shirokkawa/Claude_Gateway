# Claude Gateway

Windows 10 虚拟机通过 Ubuntu 网关访问宿主机 Clash Verge 的菲律宾代理。此仓库记录现有环境的看门器、DNS 转发器和安装脚本，不负责从零安装 VMware、Clash 或 Redsocks。

## 网络拓扑

- 宿主机 VMnet1：`192.168.50.1`；Clash 混合代理端口：`7897`。
- Ubuntu LAN：`192.168.50.2`；健康端口：宿主机 `7898`。
- Windows 客户机：`192.168.50.10`；网关和 DNS：`192.168.50.2`。

宿主机看门器检查 Mihomo 网卡和代理出口位置，并控制到代理端口的入站阻断规则。Ubuntu 每约 2 秒检查宿主机健康状态，定期独立复核出口国家，仅在两项通过时启动 Redsocks。dnsmasq 将客户机 DNS 转给本机 DoH 服务；DoH 服务只通过宿主机代理连接 Cloudflare。

## 部署

先在宿主机管理员 PowerShell 运行：

```powershell
& 'E:\Vibe Coding\Claude_Gateway\Install-HostGuard.ps1'
```

在已有 Ubuntu 网关配置的前提下，把 `check-ph-proxy`、`install-ubuntu.sh`、`proxy-doh.py`、`install-doh.sh` 传到 Ubuntu 用户主目录，依次运行：

```sh
sudo sh ~/install-ubuntu.sh
sudo sh ~/install-doh.sh
```

`install-doh.sh` 仅适用于 `/etc/dnsmasq.d/gateway.conf` 仍含 `server=1.1.1.1` 和 `server=8.8.8.8` 的首次迁移。脚本不保存代理凭据。

## 已验证

- 菲律宾节点、TUN 开启时，客户机出口为 `PH`，DNS 正常解析。
- 非菲律宾节点、TUN 关闭、Clash 退出时，客户机外网 TCP 连接失败。
- 客户机直连宿主机代理端口的 IPv4 和 IPv6 测试失败。
- Ubuntu 与 Windows 客户机重启后，服务、REDIRECT 规则、DNS 和菲律宾出口恢复。

出口判断依赖 Cloudflare 的位置响应和轮询，切换故障时存在检测延迟。地理位置检查不能保证 Claude 账号不受风控；宿主机自身重启后的计划任务自启尚未实测。
