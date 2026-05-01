#!/usr/bin/env bash
set -e

# 定义 Binary Cache 参数
# 注意：必须保留 cache.nixos.org，否则由于覆盖会导致基础缓存丢失
CACHE_Substituters="https://cache.nixos.org https://attic.xuyh0120.win/lantian https://cache.garnix.io"
CACHE_TrustedPublicKeys="cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc= cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="

echo "============================================"
echo "Running Tests"
echo "============================================"

# 获取脚本所在目录，确保无论在哪里运行都能找到 default.nix
TEST_DIR="$(dirname "$0")"

echo ""
echo "[1/2] Running Static Configuration Checks..."
nix-build "$TEST_DIR" -A staticCheck
echo "Static checks passed."

echo ""
echo "[2/2] Running Virtual Machine Integration Tests..."
echo "Using Binary Caches to accelerate build:"
echo "  - https://attic.xuyh0120.win/lantian"
echo "  - https://cache.garnix.io"

# 使用 --option 传递缓存配置，确保能拉取到预编译的内核
nix-build "$TEST_DIR" -A vmTest \
  --option substituters "$CACHE_Substituters" \
  --option trusted-public-keys "$CACHE_TrustedPublicKeys"
  
echo ""
echo "============================================"
echo "All Tests Passed Successfully!"
echo "============================================"
