{ pkgs }:

pkgs.testers.nixosTest {
  name = "bagevm-us-vm-test";
  
  nodes.server = { config, lib, ... }: {
    imports = [ ../configuration.nix ];

    # 1. 环境适配：禁用生产环境特有的网络接口配置，改用 VM 默认网络
    base.hardware.network.single-interface.enable = lib.mkForce false;
    
    # 2. 调试增强：允许通过密码登录，方便使用 driver 手动调试
    base.auth.root.mode = lib.mkForce "permit_passwd";
    users.users.root.password = "test";

    # 3. 性能优化：在虚拟机中禁用耗时的磁盘操作（可选）
    # exts.hardware.disk.btrfs.enable = lib.mkForce false;
  };

  testScript = ''
    # 等待系统启动完成
    server.wait_for_unit("multi-user.target")
    
    # 验证核心服务：Podman
    server.wait_for_unit("podman.socket")
    
    # 验证 Web 服务器：Nginx
    server.wait_for_unit("nginx.service")
    server.wait_for_open_port(80)
    
    # 验证内核调优：检查 BBR 是否启用 (CachyOS 默认启用)
    sysctl_bbr = server.succeed("sysctl net.ipv4.tcp_congestion_control")
    assert "bbr" in sysctl_bbr
    
    # 验证主机名
    hostname = server.succeed("hostname").strip()
    assert hostname == "bagevm-us"
    
    print("VM 测试全部通过！")
  '';
}
