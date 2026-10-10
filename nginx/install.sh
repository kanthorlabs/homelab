#!/usr/bin/env bash
SCRIPT_NAME=homelab-nginx
. "$(dirname "$0")/../lib/common.sh"
require_command sudo
homelab_require curl curl
homelab_require nginx nginx
homelab_require openssl openssl

host=$(homelab_host) || exit 1
port=$(homelab_port) || exit 1
site=/etc/nginx/sites-available/homelab
enabled=/etc/nginx/sites-enabled/homelab
default_site=/etc/nginx/sites-enabled/default
template="$ROOT/nginx/site.conf"
page="$ROOT/www/index.html"
webroot=/var/www/homelab

work=$(mktemp -d) || die "cannot create a temporary directory"
trap 'rm -rf "$work"' EXIT
rendered="$work/site.conf"
backup="$work/site.conf.previous"

inline_hash() {
	local blocks
	blocks=$(grep -cx "<$1>" "$page")
	[ "$blocks" = 1 ] || die "$page needs exactly one <$1> line, found $blocks"
	awk -v start="<$1>" -v stop="</$1>" '$0 == stop { on = 0 } on { print } $0 == start { on = 1; printf "\n" }' "$page" |
		openssl dgst -sha256 -binary | openssl base64 -A
}
script_hash="sha256-$(inline_hash script)" || exit 1
style_hash="sha256-$(inline_hash style)" || exit 1

sed -e "s/@HOST@/$host/" -e "s/@HOMELAB_PORT@/$port/" \
	-e "s|@SCRIPT_HASH@|$script_hash|" -e "s|@STYLE_HASH@|$style_hash|" "$template" >"$rendered" || die "cannot render $template"

had_link=0
sudo test -L "$enabled" && had_link=1
had_default=0
sudo test -L "$default_site" && had_default=1

restore() {
	if [ -f "$backup" ]; then
		sudo install -o root -g root -m 644 "$backup" "$site"
	else
		sudo rm -f "$site"
	fi
	[ "$had_link" = 1 ] || sudo rm -f "$enabled"
	[ "$had_default" = 0 ] || sudo ln -sfn /etc/nginx/sites-available/default "$default_site"
}

if sudo test -f "$site"; then
	sudo cp "$site" "$backup" || die "cannot back up $site"
fi

log "installing the homepage in $webroot"
sudo install -d -o root -g root -m 755 "$webroot" || die "cannot create $webroot"
sudo install -o root -g root -m 644 "$page" "$webroot/index.html" || die "cannot install $webroot/index.html"

log "installing $site for $host"
sudo install -o root -g root -m 644 "$rendered" "$site" || die "cannot install $site"
sudo ln -sfn "$site" "$enabled" || die "cannot enable $site"
if [ "$had_default" = 1 ]; then
	log "disabling the default site that listens on the local network"
	sudo rm -f "$default_site" || die "cannot remove $default_site"
fi
if ! sudo nginx -t; then
	restore
	die "nginx -t failed. The previous site is back. Fix the reported error, then rerun"
fi
sudo systemctl enable nginx || die "cannot enable nginx"
if [ "$had_default" = 1 ]; then
	sudo systemctl restart nginx || die "nginx did not start. Read journalctl -u nginx"
else
	sudo systemctl reload-or-restart nginx || die "nginx did not start. Read journalctl -u nginx"
fi

status=$(curl -s -o /dev/null -w '%{http_code}' -H "Host: $host" http://127.0.0.1/)
[ "$status" = "200" ] || die "http://127.0.0.1/ for $host answers $status, not 200"
log "nginx serves $host on 127.0.0.1:80"
