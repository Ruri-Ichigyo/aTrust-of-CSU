# csuVPN-for-linux
中南大学VPN的Linux客户端

## 方法一（推荐）：自动检测架构并下载最新客户端

脚本会自动识别当前机器的 CPU 架构（x86_64 / ARM64 / ARM / x86），然后从
[门户下载页](https://vpn.csu.edu.cn/portal/#/down_client_new?moreClient=1)
获取对应的最新客户端并完成安装。

```bash
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
sudo bash install.sh
```

支持的架构：

| `uname -m` 输出 | 对应客户端 |
|---|---|
| `x86_64` / `amd64` | anyconnect-linux64 |
| `aarch64` / `arm64` | anyconnect-linux-arm64 |
| `armv7*` / `armhf` | anyconnect-linux-arm |
| `i386` / `i686` | anyconnect-linux |

## 方法二：手动下载（网页）

登录 <https://vpn.csu.edu.cn>，输入用户名和密码后，可根据系统自动下载并安装VPN客户端。

## 方法三：使用仓库内已有的 x86\_64 安装包

```bash
git clone https://github.com/lanshi17/csuVPN-for-linux.git
cd csuVPN-for-linux
sudo sh anyconnect-linux64-4.9.01095-core-vpn-webdeploy-k9.sh
```

> 注意：此安装包版本固定（4.9.01095），仅适用于 x86\_64 架构。
> 如需最新版本或其他架构，请使用方法一。
