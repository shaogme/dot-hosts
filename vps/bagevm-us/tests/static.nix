{ pkgs }:

let
  # 评估 configuration.nix
  eval = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    modules = [
      ../configuration.nix
      # 注入测试专用覆盖，避免评估时因缺少某些物理环境属性而报错
      {
        # 如果需要可以在这里添加覆盖
      }
    ];
    inherit pkgs;
  };
  
  cfg = eval.config;
in
pkgs.runCommand "bagevm-us-static-check" {
  # 增加元数据输出，方便调试
  passthru = { inherit eval; };
} ''
  echo "--- 正在执行静态检查 ---"

  echo "检查主机名..."
  if [[ "${cfg.networking.hostName}" != "bagevm-us" ]]; then
    echo "错误: 主机名预期为 bagevm-us，实际为 ${cfg.networking.hostName}"
    exit 1
  fi

  echo "检查更新模式 (legacy)..."
  if [[ "${cfg.base.update.upgrade.type}" != "legacy" ]]; then
    echo "错误: 更新模式预期为 legacy，实际为 ${cfg.base.update.upgrade.type}"
    exit 1
  fi

  echo "检查 Nginx 邮箱..."
  if [[ "${cfg.base.app.web.nginx.email}" != "hi@shaog.me" ]]; then
    echo "错误: 邮箱配置不匹配"
    exit 1
  fi

  echo "检查 CachyOS 内核是否启用..."
  if [[ "${builtins.toString cfg.exts.kernel.cachyos.enable}" != "1" ]]; then
    echo "错误: CachyOS 内核未启用"
    exit 1
  fi

  echo "静态检查通过！"
  touch $out
''
