# aTrust-of-CSU
中南大学VPN客户端（aTrust）自动安装脚本 — 支持 Windows / macOS / Linux

## 快速开始

### Linux / macOS

```bash
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
sudo bash install.sh
```

脚本会自动检测操作系统（Linux 或 macOS）和 CPU 架构，从门户获取并安装对应的最新 aTrust 客户端。

### Windows（PowerShell，管理员运行）

```powershell
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install.ps1
```

---

## 各平台说明

### Linux（`install.sh`）

客户端：`aTrust_ubuntu` v2.5.16.30 Stable（**不局限于 Ubuntu**，适用于主流 Linux 发行版，`aTrust_ubuntu` 为厂商命名）

| `uname -m` 输出 | 架构 |
|---|---|
| `x86_64` / `amd64` | x86_64 |
| `aarch64` / `arm64` | arm64 |
| `armv7*` / `armhf` | arm |
| `i386` / `i686` | x86 |

| 发行版 | 安装包格式 |
|---|---|
| Debian / Ubuntu 及衍生版 | `.deb`（dpkg） |
| RHEL / CentOS / Fedora / openSUSE | `.rpm`（rpm） |
| 其他 Linux | `.sh` / `.bin`（直接运行） |

### macOS（`install.sh`）

客户端：`aTrust_mac` v2.5.16.20 Stable

支持 Intel（x86_64）和 Apple Silicon（arm64）。
脚本使用 `installer -pkg` 安装 `.pkg` 包，或自动挂载 `.dmg` 后安装其中的 `.pkg`。

需要通过 Terminal 以管理员权限运行（`sudo`）。

### Windows（`install.ps1`）

客户端：`aTrust_windows` v2.5.16.20 Stable

支持 AMD64 / ARM64 / x86 架构。
脚本使用 PowerShell，需要以**管理员身份**运行。
安装 `.exe` 时使用静默参数 `/S`，安装 `.msi` 时使用 `msiexec /qn`。

---

## 客户端版本一览

门户当前提供的客户端版本（以管理员指导为准）：

| 平台 | 客户端 | 版本 | 状态 |
|---|---|---|---|
| Linux（不限发行版） | `aTrust_ubuntu` | 2.5.16.30 | **Stable** |
| macOS | `aTrust_mac` | 2.5.16.20 | **Stable** |
| macOS | `aTrust_mac` | 2.5.10.32 | Beta |
| macOS | `aTrust_mac` | 2.3.10.73 | Beta |
| macOS（VDI） | `aTrust_vdi_mac` | 2.5.16.20 | **Stable** |
| Windows | `aTrust_windows` | 2.5.16.20 | **Stable** |
| Windows | `aTrust_windows` | 2.5.10.32 | Beta |
| Windows | `aTrust_windows` | 2.3.10.73 | Beta |
| Windows（VDI） | `aTrust_vdi_windows` | 2.5.16.20 | **Stable** |

> Beta 版本适用于需要测试新功能的场景，Stable 版本为日常推荐使用版本。

---

## 方法二：手动下载（网页）

登录 <https://vpn.csu.edu.cn>，输入用户名和密码后，可根据系统自动下载并安装VPN客户端。

## 方法三：使用仓库内已有的 Cisco AnyConnect x86_64 安装包（旧版）

```bash
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
sudo sh anyconnect-linux64-4.9.01095-core-vpn-webdeploy-k9.sh
```

> 注意：此安装包为旧版 Cisco AnyConnect 4.9.01095，仅适用于 Linux x86_64 架构。
> 如需最新 aTrust 客户端，请使用方法一。
