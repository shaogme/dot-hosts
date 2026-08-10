{ config, pkgs, lib, modulesPath, ... }:

let
  # 导入由 npins 管理的依赖源
  sources = import ./npins;
  
  # 注入当前 pkgs 到基础库和扩展库
  dot-base = import sources.dot-base { inherit pkgs; };
  dot-exts = import sources.dot-exts { inherit pkgs; };

  # 主机基础配置信息
  hostConfig = {
    name = "coding";
    domainRoot = "shaog.me";
    email = "hi@shaog.me";
    diskDevice = "/dev/vda";

    auth = {
      rootHash = "$6$wM7R/YUYdtHKYejM$Farw61wodEA1hOi5jfNn2W6Cnil7PhgYF4aHx1rBYkjwZiHG7XoXvq5K2C9I.xflHkvoTPVltt3I3oYtByf6q1";
      sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFNCU2PbTCr6HbrCdthvfbfTeXBePXNei7ER13hwotjr hi@shaog.me" ];
    };
  };
in
{
  imports = [
    # 1. 引入模块库
    dot-base.nixosModules.default
    dot-exts.nixosModules.kernel.cachyos
    dot-exts.nixosModules.hardware.disk.btrfs
    ../../vps/common.nix
  ];

  # ==========================================
  # 通用系统配置 (Base)
  # ==========================================
  system.stateVersion = "25.11"; 
  
  # 启用 Lix 代替默认的 CppNix
  nix.package = pkgs.lixPackageSets.git.lix;

  # 应用 rust-overlay
  nixpkgs.overlays = [ (import sources.rust-overlay) ];
  
  # 基础功能启用
  base.enable = true;
  
  # Hardware 配置
  base.hardware.type = "vps";
  base.hardware.network = {
    enable = true;
    interfaces = {
      enp0s3 = {
        dhcp = "yes";
      };
      enp0s8 = {
        dhcp = "no";
        ipv4.addresses = [
          {
            address = "192.168.56.10";
            prefixLength = 24;
          }
        ];
      };
    };
  };
  exts.hardware.disk.btrfs = {
      enable = true;
      device = hostConfig.diskDevice;
      swapSize = 2048;
      imageBaseSize = 2048; 
  };
  
  # 性能与内存调优
  base.performance.tuning.enable = true;
  base.memory.mode = "aggressive";
  
  # DNS 服务
  base.dns.smartdns.mode = "oversea";

  # 容器引擎
  base.container.podman.enable = true;
  
  # 关闭系统自动更新
  base.update = {
      enable = false;
  };

  # ==========================================
  # 主机特有配置
  # ==========================================
  networking.hostName = hostConfig.name;
  
  # 硬件报告路径
  hardware.facter.reportPath = ./facter.json;

  # 开发工具集：Rust, Node.js LTS, C++ 工具链, Python 3 等
  environment.systemPackages = with pkgs; [
    # 1. 最新 Rust 工具链（包含 Stable 与 Nightly 版本，使用 symlinkJoin 忽略非关键同名脚本冲突）
    (symlinkJoin {
      name = "rust-toolchains-combined";
      paths = [
        (rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        })
        (rust-bin.nightly.latest.default.override {
          extensions = [ "rust-src" ];
        })
      ];
      ignoreCollisions = true;
    })
    cargo-nextest
    cargo-expand
    cargo-watch
    cargo-edit
    cargo-audit
    cargo-deny
    cargo-binstall

    # 2. Node.js LTS（使用 nixpkgs 默认 Node.js LTS 别名，无需硬编码大版本）
    nodejs

    # 3. C++ 工具链
    gcc
    gnumake
    cmake
    clang
    gdb
    pkg-config
    ninja

    # 4. Python 3 环境
    python3
    python3Packages.pip
    python3Packages.setuptools

    # 5. AI 工具链
    codex
    claude-code
    opencode

    # 6. 常用开发与实用工具
    git
    git-lfs
    gh
    curl
    wget
    ripgrep
    fd
    jq
    tmux
    htop
    zip
    unzip
    p7zip
  ];

  # 内核优化: 启用 CachyOS 内核
  exts.kernel.cachyos.enable = true;

  # 认证与安全: Root 用户配置
  base.auth.root = {
      mode = "default";
      initialHashedPassword = hostConfig.auth.rootHash;
      authorizedKeys = hostConfig.auth.sshKeys;
  };

  # 静态测试与合法性断言
  assertions = [
    {
      assertion = config.networking.hostName == hostConfig.name;
      message = "主机名配置错误，预期为 ${hostConfig.name}，实际为 ${config.networking.hostName}";
    }
    {
      assertion = config.base.update.enable == false;
      message = "更新服务配置错误：自动更新应当处于关闭状态";
    }
    {
      assertion = config.exts.kernel.cachyos.enable == true;
      message = "内核配置错误：CachyOS 内核未启用";
    }
  ];
}
