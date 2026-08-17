#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    echo "Usage: $0 [npins-update-flags/names...]"
    echo ""
    echo "Updates npins dependencies for all hosts detected by .github/scripts/get-hosts.sh."
    echo "Optional arguments will be passed directly to 'npins update'."
    exit 0
fi

# Run npins command with fallback to nix shell if npins is not in PATH
run_npins() {
    if command -v npins &>/dev/null; then
        npins "$@"
    elif command -v nix &>/dev/null; then
        nix shell nixpkgs#npins -c npins "$@"
    else
        echo "Error: neither npins nor nix command was found." >&2
        exit 1
    fi
}

# Obtain hosts list using .github/scripts/get-hosts.sh
HOSTS_JSON=$(bash "$REPO_DIR/.github/scripts/get-hosts.sh" --filter-npins)

HOST_LIST=()
if command -v jq &>/dev/null; then
    while IFS= read -r host; do
        [ -n "$host" ] && HOST_LIST+=("$host")
    done < <(echo "$HOSTS_JSON" | jq -r '.[]')
elif command -v python3 &>/dev/null; then
    while IFS= read -r host; do
        [ -n "$host" ] && HOST_LIST+=("$host")
    done < <(python3 -c "import json, sys; [print(h) for h in json.loads(sys.argv[1])]" "$HOSTS_JSON")
else
    clean_json=$(echo "$HOSTS_JSON" | tr -d '[]" ' | tr ',' '\n')
    while IFS= read -r host; do
        [ -n "$host" ] && HOST_LIST+=("$host")
    done <<< "$clean_json"
fi

if [ ${#HOST_LIST[@]} -eq 0 ]; then
    echo "No hosts with npins found."
    exit 0
fi

echo "Found ${#HOST_LIST[@]} host(s) with npins:"
for host in "${HOST_LIST[@]}"; do
    echo "  - $host"
done
echo ""

for host in "${HOST_LIST[@]}"; do
    target_dir="$REPO_DIR/$host"
    if [ ! -d "$target_dir" ]; then
        echo "Warning: Directory $target_dir does not exist, skipping."
        continue
    fi
    echo "=========================================="
    echo "Updating npins for host: $host"
    echo "=========================================="
    (
        cd "$target_dir"
        run_npins upgrade
        run_npins update "$@"
    )
done

echo ""
echo "=========================================="
echo "Successfully updated npins for all hosts!"
echo "=========================================="
