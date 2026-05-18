let
  # 定义项目中所有的 VPS 名称
  vpsList = [
    "bagevm-jp"
    "bagevm-us"
    "cloudcone"
    "colocrossing"
  ];

  # 为单个 VPS 生成静态和运行时测试的辅助函数
  makeVpsTests = name:
    let
      # 动态引入各自目录底下的 npins 依赖项以保持版本的一致性
      sources = import (../vps + "/${name}/npins");
      # 实例化对应的 nixpkgs
      pkgs = import sources.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
      configuration = ../vps + "/${name}/configuration.nix";
    in
    {
      # 静态检查
      staticCheck = import ./static.nix { inherit pkgs configuration name; };

      # 虚拟机集成测试
      vmTest = import ./vmtest.nix { inherit pkgs configuration name; };
    };

  # 映射 VPS 列表到测试集字典
  allTests = builtins.listToAttrs (map (name: {
    name = name;
    value = makeVpsTests name;
  }) vpsList);
in
allTests
