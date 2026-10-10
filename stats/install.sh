#!/usr/bin/env bash
SCRIPT_NAME=homelab-stats
. "$(dirname "$0")/../lib/common.sh"
require_command sudo
require_command systemctl

collector=/usr/local/lib/homelab/collect-stats
units=/etc/systemd/system
output=/run/homelab-stats/stats.json

log "installing $collector and the homelab-stats timer"
sudo install -d -o root -g root -m 755 "$(dirname "$collector")" || die "cannot create $(dirname "$collector")"
sudo install -o root -g root -m 755 "$ROOT/stats/collect.sh" "$collector" || die "cannot install $collector"
for unit in homelab-stats.service homelab-stats.timer; do
	sudo install -o root -g root -m 644 "$ROOT/stats/$unit" "$units/$unit" || die "cannot install $units/$unit"
done
sudo systemctl daemon-reload || die "systemctl daemon-reload failed"
sudo systemctl start homelab-stats.service || die "homelab-stats.service failed. Read journalctl -u homelab-stats"
sudo systemctl enable --now homelab-stats.timer || die "cannot enable homelab-stats.timer"

[ -s "$output" ] || die "$output is missing after the first run"
log "$output: $(cat "$output")"
log "nginx serves it at /stats.json after make nginx"
