#!/usr/bin/env bash
set -e

# Change directory to the repository root (two levels up from .github/scripts)
cd "$(dirname "$0")/../../"

FILTER_NPINS=false
if [[ "$1" == "--filter-npins" ]]; then
    FILTER_NPINS=true
fi

hosts=()

# Iterate over directories in vps/
for dir in vps/*/; do
    # 检查基础要求：是否存在 configuration.nix 且存在 tests/run-tests.sh
    if [ -d "$dir" ] && [ -f "$dir/configuration.nix" ] && [ -f "$dir/tests/run-tests.sh" ]; then
        
        # 如果启用了 npins 过滤，则额外检查 npins 文件
        if [ "$FILTER_NPINS" = true ]; then
            if [ ! -f "$dir/npins/default.nix" ] || [ ! -f "$dir/npins/sources.json" ]; then
                continue
            fi
        fi

        # Extract the directory name (host name)
        host=$(basename "$dir")
        hosts+=("$host")
    fi
done

# Output as JSON array using jq
if [ ${#hosts[@]} -eq 0 ]; then
    echo "[]"
else
    printf '%s\n' "${hosts[@]}" | jq -R . | jq -s -c .
fi
