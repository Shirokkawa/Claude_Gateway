# Claude Gateway

**v0.9** · 面向中国大陆及其他 Claude 暂不支持地区用户的 Claude Code 虚拟机网关实验项目。

项目让 Windows 10 虚拟机通过 Ubuntu 网关，使用宿主机 Clash Verge 的菲律宾代理出口。它针对节点切换、TUN 关闭和代理退出等情况设置检查与断网保护，目的是降低 Claude Code 意外从非预期网络出口连接所带来的账号风控风险。**它不能保证账号不被限制或封禁，也不能改变 Claude 的服务地区、账号资格或服务条款。**使用前请自行确认当地法律及服务条款。

当前仓库记录的是一套已运行环境的看门器、DNS 转发器和安装脚本，不包含从零部署 VMware、Clash、Redsocks 或 Ubuntu 网关的完整流程。

## 工作原理

- 宿主机检查 TUN 网卡和代理出口国家，按检查结果控制 Ubuntu 到 Clash 代理端口的防火墙规则，并向 Ubuntu 提供健康状态。
- Ubuntu 定期读取宿主机状态，且每约 5 分钟独立复核代理出口；两项检查通过时才启动 Redsocks，否则停止。
- Windows 客户机的 TCP 流量由 Ubuntu 重定向至 Redsocks；DNS 由 dnsmasq 转给本机 DoH 服务，再经宿主机代理访问 Cloudflare。
- 客户机不能直接访问宿主机的代理端口，以免绕过网关检查。

## 网络拓扑

- 宿主机 VMnet1：`192.168.50.1`；Clash 混合代理端口：`7897`。
- Ubuntu LAN：`192.168.50.2`；健康端口：宿主机 `7898`。
- Windows 客户机：`192.168.50.10`；网关和 DNS：`192.168.50.2`。

这些地址、端口和接口名均写在脚本中。复用前必须按自己的网络拓扑逐项核对；不要在其他环境直接执行安装脚本。

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

## 限制

- 出口国家判断依赖 Cloudflare 的位置响应和轮询，故障切换时存在检测延迟；检查通过也不代表 Claude 会接受该连接或账号。
- 当前仅在上述固定的 VMware、Ubuntu、Windows 10、Clash Verge 和菲律宾出口组合中验证；其他配置需要自行适配和重新测试。
- 宿主机自身重启后的计划任务自启尚未实测。
