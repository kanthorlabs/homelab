#!/usr/bin/env bash
set -euo pipefail
umask 022

out=${1:?usage: collect.sh <output file>}

cpu_sample() {
	awk '/^cpu / { idle = $5 + $6; total = 0; for (i = 2; i <= NF; i++) total += $i; print total, idle; exit }' /proc/stat
}

read -r total_a idle_a < <(cpu_sample)
sleep 2
read -r total_b idle_b < <(cpu_sample)

cpu=$(awk -v t="$((total_b - total_a))" -v i="$((idle_b - idle_a))" 'BEGIN { printf "%.1f", (t > 0 ? 100 * (t - i) / t : 0) }')
ram=$(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } END { printf "%.1f", (t > 0 ? 100 * (t - a) / t : 0) }' /proc/meminfo)
disk=$(df -P / | awk 'NR == 2 { printf "%.1f", (($3 + $4) > 0 ? 100 * $3 / ($3 + $4) : 0) }')

tmp=$(mktemp "$(dirname "$out")/.stats.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '{"cpu":%s,"ram":%s,"disk":%s,"updated":%s}\n' "$cpu" "$ram" "$disk" "$(date +%s)" >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$out"
