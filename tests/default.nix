let
  # 动态获取 vps/ 目录下的所有含有 configuration.nix 的主机名称
  vpsList = builtins.filter (
    name:
    let
      catPath = rootDir + "/${category}";
      catEntries = builtins.readDir catPath;
    in
    builtins.concatLists (map (hostName:
      let
        hostDirPath = catPath + "/${hostName}";
        isDir = catEntries.${hostName} == "directory";
        hasConfig = isDir && builtins.pathExists (hostDirPath + "/configuration.nix");
      in
      if hasConfig then [{
        name = hostName;
        relPath = "${category}/${hostName}";
        dirPath = hostDirPath;
      }] else []
    ) (builtins.attrNames catEntries))
  ) categories);

  # 为单个主机生成静态和运行时测试
  makeHostTests = item:
    let
      sources = import (item.dirPath + "/npins");
      pkgs = import sources.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      configuration = item.dirPath + "/configuration.nix";
    in
    {
      # 静态检查
      staticCheck = import ./static.nix { inherit pkgs configuration; name = item.name; };

      # 虚拟机集成测试
      vmTest = import ./vmtest.nix { inherit pkgs configuration; name = item.name; };
    };

  # 映射 VPS 列表到测试集字典
  allTests = builtins.listToAttrs (map (name: {
    name = name;
    value = makeVpsTests name;
  }) vpsList);
in
allTests
