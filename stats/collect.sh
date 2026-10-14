#!/usr/bin/env bash
set -euo pipefail
umask 022

out=${1:?usage: collect.sh <output file>}

cpu_sample() {
	awk '/^cpu / { idle = $5 + $6; total = 0; for (i = 2; i <= NF; i++) total += $i; print total, idle; exit }' /proc/stat
}

cpu_temp_millidegrees() {
	local dir zone
	for dir in /sys/class/hwmon/hwmon*; do
		case "$(cat "$dir/name" 2>/dev/null)" in
		coretemp | k10temp | zenpower | cpu_thermal)
			cat "$dir/temp1_input" 2>/dev/null && return 0
			;;
		esac
	done
	for zone in /sys/class/thermal/thermal_zone*; do
		case "$(cat "$zone/type" 2>/dev/null)" in
		x86_pkg_temp | cpu-thermal | cpu_thermal)
			cat "$zone/temp" 2>/dev/null && return 0
			;;
		esac
	done
	return 1
}

read -r total_a idle_a < <(cpu_sample)
sleep 2
read -r total_b idle_b < <(cpu_sample)

cpu=$(awk -v t="$((total_b - total_a))" -v i="$((idle_b - idle_a))" 'BEGIN { printf "%.1f", (t > 0 ? 100 * (t - i) / t : 0) }')
ram=$(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 } END { printf "%.1f", (t > 0 ? 100 * (t - a) / t : 0) }' /proc/meminfo)
disk=$(df -P / | awk 'NR == 2 { printf "%.1f", (($3 + $4) > 0 ? 100 * $3 / ($3 + $4) : 0) }')
temp=$({ cpu_temp_millidegrees || true; } | awk '/^-?[0-9]+$/ { printf "%.1f", $1 / 1000; found = 1; exit } END { if (!found) print "null" }')

tmp=$(mktemp "$(dirname "$out")/.stats.XXXXXX")
trap 'rm -f "$tmp"' EXIT
printf '{"cpu":%s,"ram":%s,"disk":%s,"temp":%s,"updated":%s}\n' "$cpu" "$ram" "$disk" "$temp" "$(date +%s)" >"$tmp"
chmod 644 "$tmp"
mv -f "$tmp" "$out"
