#!/usr/bin/env bash
SCRIPT_NAME=homelab-nginx
. "$(dirname "$0")/../lib/common.sh"
require_command sudo
homelab_require curl curl
homelab_require nginx nginx

host=$(homelab_host) || exit 1
port=$(homelab_port) || exit 1
site=/etc/nginx/sites-available/homelab
enabled=/etc/nginx/sites-enabled/homelab
template="$ROOT/nginx/site.conf"

work=$(mktemp -d) || die "cannot create a temporary directory"
trap 'rm -rf "$work"' EXIT
rendered="$work/site.conf"
backup="$work/site.conf.previous"

sed -e "s/@HOST@/$host/" -e "s/@HOMELAB_PORT@/$port/" "$template" >"$rendered" || die "cannot render $template"

had_link=0
sudo test -L "$enabled" && had_link=1

restore() {
	if [ -f "$backup" ]; then
		sudo install -o root -g root -m 644 "$backup" "$site"
	else
		sudo rm -f "$site"
	fi
	[ "$had_link" = 1 ] || sudo rm -f "$enabled"
}

if sudo test -f "$site"; then
	sudo cp "$site" "$backup" || die "cannot back up $site"
fi

log "installing $site for $host"
sudo install -o root -g root -m 644 "$rendered" "$site" || die "cannot install $site"
sudo ln -sfn "$site" "$enabled" || die "cannot enable $site"
if ! sudo nginx -t; then
	restore
	die "nginx -t failed. The previous site is back. Fix the reported error, then rerun"
fi
sudo systemctl enable nginx || die "cannot enable nginx"
sudo systemctl reload-or-restart nginx || die "nginx did not start. Read journalctl -u nginx"

status=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $host" http://127.0.0.1/)
[ "$status" = "200" ] || die "http://127.0.0.1/ for $host answers $status, not 200"
log "nginx serves $host on 127.0.0.1:80"
