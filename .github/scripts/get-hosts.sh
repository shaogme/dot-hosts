#!/usr/bin/env bash
set -e

# Change directory to the repository root (two levels up from .github/scripts)
cd "$(dirname "$0")/../../"

hosts=()

# Iterate over directories in vps/
for dir in vps/*/; do
    # 检查是否存在 configuration.nix 且存在 tests/run-tests.sh
    if [ -d "$dir" ] && [ -f "$dir/configuration.nix" ] && [ -f "$dir/tests/run-tests.sh" ]; then
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
