#!/usr/bin/env bash
set -e

# 定义 Binary Cache 参数
# 注意：必须保留 cache.nixos.org，否则由于覆盖会导致基础缓存丢失
CACHE_Substituters="https://cache.nixos.org https://attic.xuyh0120.win/lantian https://cache.garnix.io"
CACHE_TrustedPublicKeys="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc= cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

# 获取脚本所在目录
TESTS_DIR="$(dirname "$0")"

# 支持的 VPS 列表
VPS_LIST=("bagevm-jp" "bagevm-us" "cloudcone" "colocrossing")

print_help() {
  echo "统一 VPS 测试工具"
  echo "用法: $0 [vps-name | all]"
  echo ""
  echo "可用的 VPS 选项:"
  for vps in "${VPS_LIST[@]}"; do
    echo "  - $vps"
  done
  echo "  - all          (运行所有 VPS 的全部测试)"
}

run_test_for_vps() {
  local vps=$1
  echo "============================================"
  echo "正在测试 VPS: $vps"
  echo "============================================"
  
  echo ""
  echo "[1/2] 正在运行静态配置检查..."
  nix-build "$TESTS_DIR" -A "$vps".staticCheck
  echo "静态检查通过。"
  
  echo ""
  echo "[2/2] 正在运行虚拟机集成测试..."
  echo "使用 Binary Caches 加速虚拟机测试构建:"
  echo "  - https://attic.xuyh0120.win/lantian"
  echo "  - https://cache.garnix.io"
  
  # 使用 --option 传递缓存配置，确保能拉取到预编译的内核
  nix-build "$TESTS_DIR" -A "$vps".vmTest \
    --option substituters "$CACHE_Substituters" \
    --option trusted-public-keys "$CACHE_TrustedPublicKeys"
    
  echo ""
  echo "============================================"
  echo "VPS $vps 所有测试成功通过！"
  echo "============================================"
}

TARGET=${1:-all}

if [ "$TARGET" = "help" ] || [ "$TARGET" = "-h" ] || [ "$TARGET" = "--help" ]; then
  print_help
  exit 0
fi

if [ "$TARGET" = "all" ]; then
  for vps in "${VPS_LIST[@]}"; do
    run_test_for_vps "$vps"
  done
  echo "============================================"
  echo "恭喜！所有 VPS 的静态和虚拟机测试均已成功通过！"
  echo "============================================"
else
  # 验证输入的 VPS 名称是否有效
  VALID=false
  for vps in "${VPS_LIST[@]}"; do
    if [ "$vps" = "$TARGET" ]; then
      VALID=true
      break
    fi
  done
  
  if [ "$VALID" = "true" ]; then
    run_test_for_vps "$TARGET"
  else
    echo "错误: 未知的 VPS 名称 '$TARGET'"
    echo ""
    print_help
    exit 1
  fi
fi
