# dot-hosts

> 基于 NixOS + dot-base / dot-exts 的多主机 VPS 自动化维护与高性能服务器配置集。

---

## 核心特性与架构

本配置库深度集成并引入了两个底座组件，专为 VPS 和个人服务器提供极致调优和运维托管：
* **[dot-base](https://github.com/shaogme/dot-base)**: 提供极简开箱即用的系统基础（SmartDNS、自动同步、自动更新、容器服务底座等）。
* **[dot-exts](https://github.com/shaogme/dot-exts)**: 提供内核级优化（CachyOS）、自动化磁盘分区（Disko Btrfs）等进阶服务。

每个主机目录（如 `vps/bagevm-jp`）都包含一份高度解耦、自完备的 `configuration.nix`、硬件数据 `facter.json` 以及由 `npins` 独立管理的外部依赖源。

---

## 新增主机配置指引

当您需要为新 VPS 铺设配置时，请重点关注对应主机目录下 `configuration.nix` 中的 `hostConfig` 局部定义和相关选项：

### 1. 基础信息
在 `configuration.nix` 的 `hostConfig` 中填入名称、域名及证书邮箱：
```nix
hostConfig = {
  name = "bagevm-jp";       # 必须与当前目录名称保持严格一致
  domainRoot = "shaog.me";  # 您的主域名
  email = "hi@shaog.me";    # 用于申请 ACME SSL 证书的邮箱
  diskDevice = "/dev/vda";  # 目标磁盘设备路径
};
```

---

### 2. 用户认证与 SSH 安全 (Auth)

```nix
hostConfig = {
  auth = {
    rootHash = "$6$wM7R/YUYdtHKYejM$Farw61wodEA1hOi5jfNn2W6Cnil7PhgYF4aHx1rBYkjwZiHG7XoXvq5K2C9I.xflHkvoTPVltt3I3oYtByf6q1";
    sshKeys = [ 
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNCU2PbTCr6HbrCdthvfbfTeXBePXNei7ER13hwotjr hi@shaog.me" 
    ];
  };
};
```

> [!WARNING]
> **请务必不要直接使用默认的`rootHash`**！
> 为了系统安全，请务必在本地运行以下命令生成您独有的 SHA-512 散列密码并填入 `rootHash`：
> ```bash
> nix run nixpkgs#mkpasswd -- -m sha-512
> ```

#### 认证模式设置
您可以通过修改 `base.auth.root.mode`（默认值为 `"default"`）来调整 root 的登录安全级别：

| 模式 | SSH 密码登录 | SSH 密钥登录 | 适用场景 |
| :--- | :---: | :---: | :--- |
| `default` | 禁用 | 允许 | **生产环境（安全首选，默认值）** |
| `permit_passwd` | 允许 | 允许 | 临时本地开发 / 紧急救援调试 |

---

### 3. 静态网络配置 (IPv4 / IPv6)

如果您的 VPS 运行在需要静态 IP 的网络环境中，请先在远程主机上执行网络拓扑分析脚本，获取网卡配置：
```bash
curl -sSL https://github.com/shaogme/net-config/releases/latest/download/net-config-linux-$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/;s/arm64/arm64/') -o net-config && chmod +x net-config && ./net-config
```
参考其控制台输出的 `Address`（公网 IP）、`Gateway`（网关）和 `Subnet Mask (Prefix)`（掩码长度），在 `hostConfig` 中填写：
```nix
ipv4 = {
  address = "209.33.172.145";
  prefixLength = 24;
  gateway = "209.33.172.1";
};
ipv6 = {
  address = "2602:fd6f:1f:6ca::ded";
  prefixLength = 64;
  gateway = "2602:fd6f:1f::1";
};
```

---

### 4. 磁盘分区配置 (Btrfs)

本配置采用由 `dot-exts` 扩展库提供的现代自动化 Btrfs 磁盘模块进行分区。
在目标 VPS 运行 `lsblk` 确认主磁盘（如 `vda` 或 `sda`），并在主机配置中设置如下选项：

```nix
exts.hardware.disk.btrfs = {
  enable = true;
  device = hostConfig.diskDevice;  # 设备路径，如 "/dev/vda"
  swapSize = 2048;                 # 交换分区大小（MB）
  imageBaseSize = 2048;            # 基础镜像大小（MB），用于 Disko 镜像打包构建参考
};
```

---

## 依赖管理与升级 (npins)

根据项目开发规范，本仓库外部依赖（非 Flake 项目）统一由 **npins** 托管。禁止手动编写 `fetchFromGitHub`、`fetchTarball` 等，以确保哈希的版本可锁和绝对可追溯。

### 更新第三方依赖源
当需要将底层的 `dot-base` 或 `dot-exts` 库升级至最新提交时，请按如下流程操作：

```bash
# 1. 进入对应主机的配置目录
cd vps/bagevm-jp

# 2. 执行依赖更新
npins update

# 3. 运行静态解析测试，验证配置是否有语法错误
nix-instantiate --parse configuration.nix > /dev/null
```
> [!TIP]
> 更多关于 npins 的规范，请参阅 [AGENTS.md](AGENTS.md) 依赖管理指南。

---

## VPS 一键重装 (DD 系统)

**适用场景**：全新 VPS 部署、需要无本地 NixOS 环境的一键转投 NixOS。
**工作原理**：GitHub Actions 工作流 `.github/workflows/release.yml` 会自动构建系统镜像包并发布到 Releases 中。VPS 只需要一键下载重装脚本并指向该镜像包链接即可实现完全覆盖安装。

### 1. 获取镜像直链
镜像在构建完成后的最新直链格式为：
```text
https://github.com/<您的GitHub用户名>/dot-hosts/releases/latest/download/<主机名>.tar.zst
```

### 2. 在目标 VPS 执行一键 DD 重装
通过 SSH 登录现有 VPS（可以是任意主流 Linux 系统），执行以下指令：

```bash
# 1. 下载一键重装脚本
curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh || wget -O ${_##*/} $_

# 2. 声明您的镜像下载直链
export IMAGE_URL="https://github.com/<您的GitHub用户名>/dot-hosts/releases/latest/download/<主机名>.tar.zst"

# 3. 执行一键安全 DD 覆盖
bash reinstall.sh dd --img "$IMAGE_URL"
```

> [!CAUTION]
> - 执行 DD 覆盖将会**完全抹去目标磁盘中的所有现有数据**！在操作前请确认您的重要资料已妥善备份。
> - 系统重装完成后会自动重启。重启后，原有系统的密码将失效，您需使用配置中指定的 SSH 私钥登录。

---

## 系统维护与更新机制

### 自动同步与定时升级
一旦在配置中启用了 `base.update` 配置（如 `bagevm-jp` 示例所示），系统将开启完全托管免运维升级：
* **Git 配置定时拉取**：定时器会以每小时一轮（`interval = "hourly"`）的频次调用 `sync-config` 服务，将您在 GitHub `dot-hosts` 仓库的最新提交安全拉取并硬同步（`destructive = true`）至本地的 `/etc/nixos` 路径。
* **定时静默重构**：每天凌晨 `04:00` 伴随着最多 `1` 小时的消峰随机延迟，系统会自动执行 `nixos-rebuild`。若遇到内核更新且设置了 `allowReboot = true`，系统会在无活跃连接时安全自动重启。
* **定期垃圾清理 (GC)**：每周定时执行 Nix 存储清理，自动删除超过 `7` 天的旧版系统代数，且默认开启 `auto-optimise-store` 以合并重合的文件节点，保证小容量 VPS 不会被撑爆。

### 手动紧急更新
若您向仓库提交了新规则并希望其即刻在 VPS 上生效，无需等待后台定时触发，可直接连接至 VPS 运行以下命令：

```bash
# 1. 强制手动同步 Git 配置
sudo systemctl start sync-config

# 2. 手动执行 NixOS 配置重构 (使用当前主机绑定的 npins 锁定版本)
sudo nixos-rebuild switch \
  -I nixos-config=/etc/nixos/vps/$(hostname)/configuration.nix \
  -I nixpkgs=$(nix-instantiate --eval -E "toString (import /etc/nixos/vps/$(hostname)/npins).nixpkgs" | tr -d '"')
```
