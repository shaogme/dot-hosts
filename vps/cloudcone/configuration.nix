{ config, pkgs, lib, modulesPath, ... }:

let
  # 导入由 npins 管理的依赖源
  sources = import ./npins;
  
  # 注入当前 pkgs 到基础库和扩展库
  dot-base = import sources.dot-base { inherit pkgs; };
  dot-exts = import sources.dot-exts { inherit pkgs; };

  # 主机基础配置信息
  hostConfig = {
    name = "cloudcone";
    domainRoot = "shaog.me";
    email = "hi@shaog.me";
    diskDevice = "/dev/vda";

    auth = {
      # 你的 Hash 密码
      rootHash = "$6$n1p6xsnD2xDbJbBg$WJ6wW2nwsi9UUSjTzN.oQVTWV9M05Qk3OGV2zjUXeembpUog.w3E5.uzu4XEoqtWVciRbz8UulJOo/jNwi6yY.";
      # SSH Keys
      sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGt4r+vxF5l4riWc9qqNmGG8qAeqxXXA6DaD+MWj14bZ ed25519 256-20251224 shaog@duck.com" ];
    };

    ipv4 = {
      address = "142.171.173.245";
      prefixLength = 26;
      gateway = "142.171.173.193";
    };
    ipv6 = {
      address = "2607:f130:0:161::3c23:5d0d";
      prefixLength = 64;
      gateway = "2607:f130:0:161::1";
    };
  };
in
{
  imports = [
    # 1. 引入模块库
    dot-base.nixosModules.default
    dot-exts.nixosModules.kernel.cachyos
    dot-exts.nixosModules.hardware.disk.btrfs
  ];

  # ==========================================
  # 通用系统配置 (Base)
  # ==========================================
  system.stateVersion = "25.11"; 
  
  # 基础功能启用
  base.enable = true;
  
  # Hardware 配置
  base.hardware.type = "vps";
  exts.hardware.disk.btrfs = {
      enable = true;
      device = hostConfig.diskDevice;
      swapSize = 2048;
      # 显式指定基础镜像大小（MB），用于 Disko 构建参考
      imageBaseSize = 2048; 
  };
  
  # 性能与内存调优
  base.performance.tuning.enable = true;
  base.memory.mode = "aggressive";
  
  # DNS 服务
  base.dns.smartdns.mode = "oversea";

  # 容器引擎
  base.container.podman.enable = true;
  
  # 系统自动更新与同步 (Legacy 模式)
  base.update = {
      enable = true;
      upgrade = {
          enable = true;
          type = "legacy";
          allowReboot = true;
      };
      sync = {
          enable = true;
          url = "https://github.com/shaogme/dot-hosts";
      };
      # 指定追踪 dot-hosts 仓库中的子路径
      path = "vps/${hostConfig.name}"; 
  };

  # ==========================================
  # 主机特有配置
  # ==========================================
  networking.hostName = hostConfig.name;
  
  # 硬件报告路径
  hardware.facter.reportPath = ./facter.json;

  # Nginx/ACME 证书联系邮箱 (强制要求)
  base.app.web.nginx.email = hostConfig.email;

  # 1. Web 应用: OpenList (原 alist)
  base.app.web.openlist = {
      enable = true;
      domain = "alist.${hostConfig.name}.${hostConfig.domainRoot}";
      backend = "podman";
  };

  # 2. Web 应用: Vaultwarden
  base.app.web.vaultwarden = {
      enable = true;
      domain = "vw.${hostConfig.name}.${hostConfig.domainRoot}";
      backend = "podman";
  };
  
  # 3. Web 应用: X-UI-YG
  # cat /var/lib/x-ui-yg/init.log 获取账号密码
  base.app.web.x-ui-yg = {
      enable = true;
      domain = "x-ui.${hostConfig.name}.${hostConfig.domainRoot}";
      backend = "podman";
      # 防火墙开放端口范围
      proxyPorts = {
        start = 16581;
        end = 16824;
      };
  };
  
  # 4. 代理服务: Hysteria
  # cat /run/hysteria/main/config.yaml 获取 auth 密码
  base.app.hysteria = {
    enable = true;
    backend = "podman";
    instances."main" = {
      domain = "hy.${hostConfig.name}.${hostConfig.domainRoot}";
      
      portHopping = {
        enable = true;
        range = "20000-50000";
        interface = "eth0"; 
      };
      settings = {
        listen = ":20000";
        bandwidth = {
          up = "1024 mbps";
          down = "1024 mbps";
        };
        auth = {
          type = "password";
          password = ""; # 保持为空，由系统生成或手动管理
        };
        outbounds = [
          {
            name = "default";
            type = "direct";
          }
        ];
      };
    };
  };

  # 内核优化: 启用 CachyOS 内核
  exts.kernel.cachyos.enable = true;

  # 网络配置: 静态单接口 IPv4 & IPv6
  base.hardware.network.single-interface = {
      enable = true;
      ipv4 = if hostConfig ? ipv4 then {
          enable = true;
          inherit (hostConfig.ipv4) address prefixLength gateway;
      } else {
          enable = false;
      };
      ipv6 = if hostConfig ? ipv6 then {
          enable = true;
          inherit (hostConfig.ipv6) address prefixLength gateway;
      } else {
          enable = false;
      };
  };
  
  # 认证与安全: Root 用户配置
  base.auth.root = {
      mode = "default";
      initialHashedPassword = hostConfig.auth.rootHash;
      authorizedKeys = hostConfig.auth.sshKeys;
  };

  # 静态测试与合法性断言 (与配置同模块维护)
  assertions = [
    {
      assertion = config.networking.hostName == hostConfig.name;
      message = "主机名配置错误，预期为 ${hostConfig.name}，实际为 ${config.networking.hostName}";
    }
    {
      assertion = config.base.update.upgrade.type == "legacy";
      message = "更新模式配置错误，预期为 legacy，实际为 ${config.base.update.upgrade.type}";
    }
    {
      assertion = config.base.app.web.nginx.email == hostConfig.email;
      message = "ACME 邮箱配置错误，当前为 ${config.base.app.web.nginx.email}";
    }
    {
      assertion = config.exts.kernel.cachyos.enable == true;
      message = "内核配置错误：CachyOS 内核未启用";
    }
  ];
}

