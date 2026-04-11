# csuVPN-for-linux
中南大学VPN的Linux客户端（aTrust）

## 方法一（推荐）：自动检测架构并下载最新客户端

脚本会自动识别当前机器的 CPU 架构和 Linux 发行版，然后从
[门户下载页](https://vpn.csu.edu.cn/portal/#/down_client_new?moreClient=1)
获取对应的最新 aTrust 客户端并完成安装。aTrust Linux 客户端（`aTrust_ubuntu`）**不局限于 Ubuntu**，可用于主流 Linux 发行版。

```bash
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
sudo bash install.sh
```

支持的架构：

| `uname -m` 输出 | 架构标识 |
|---|---|
| `x86_64` / `amd64` | x86_64 |
| `aarch64` / `arm64` | arm64 |
| `armv7*` / `armhf` | arm |
| `i386` / `i686` | x86 |

支持的发行版与包格式：

| 发行版 | 安装包格式 |
|---|---|
| Debian / Ubuntu 及衍生版 | `.deb`（dpkg 安装） |
| RHEL / CentOS / Fedora / openSUSE | `.rpm`（rpm 安装） |
| 其他 Linux | `.sh` / `.bin`（直接运行） |

## 客户端版本说明

门户当前提供的客户端版本（以管理员指导为准）：

| 客户端 | 版本 | 状态 |
|---|---|---|
| `aTrust_ubuntu`（Linux，不限发行版） | 2.5.16.30 | **Stable** |
| `aTrust_windows` | 2.5.16.20 | Stable |
| `aTrust_windows` | 2.5.10.32 | Beta |
| `aTrust_windows` | 2.3.10.73 | Beta |
| `aTrust_vdi_windows` | 2.5.16.20 | Stable |
| `aTrust_mac` | 2.5.16.20 | Stable |
| `aTrust_mac` | 2.5.10.32 | Beta |
| `aTrust_mac` | 2.3.10.73 | Beta |
| `aTrust_vdi_mac` | 2.5.16.20 | Stable |

> Windows 和 macOS 客户端请登录 <https://vpn.csu.edu.cn> 后手动下载安装。

## 方法二：手动下载（网页）

登录 <https://vpn.csu.edu.cn>，输入用户名和密码后，可根据系统自动下载并安装VPN客户端。

## 方法三：使用仓库内已有的 Cisco AnyConnect x86_64 安装包（旧版）

```bash
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
sudo sh anyconnect-linux64-4.9.01095-core-vpn-webdeploy-k9.sh
```

> 注意：此安装包为旧版 Cisco AnyConnect 4.9.01095，仅适用于 x86_64 架构。
> 如需最新 aTrust 客户端，请使用方法一。
