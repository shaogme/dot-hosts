let
  # 导入本地 npins 依赖项
  sources = import ../npins;
  # 使用 npins 中的 nixpkgs
  pkgs = import sources.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
in
{
  # 静态检查：验证 Nix 配置逻辑
  staticCheck = import ./static.nix { inherit pkgs; };

  # 虚拟机测试：验证运行时状态
  vmTest = import ./vmtest.nix { inherit pkgs; };
}
