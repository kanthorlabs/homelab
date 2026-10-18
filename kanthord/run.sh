#!/usr/bin/env bash
SCRIPT_NAME=homelab-kanthord
. "$(dirname "$0")/../lib/common.sh"
homelab_require curl curl

engine=$(homelab_engine) || exit 1

host=$(homelab_host) || exit 1
port=$(homelab_port) || exit 1
image=$(homelab_image "${IMAGE:-kanthord:latest}") || exit 1
name=$(homelab_name CONTAINER "$HOMELAB_CONTAINER") || exit 1
volume=$(homelab_name VOLUME "$HOMELAB_VOLUME") || exit 1
base_path=/s/kanthord
config=/var/lib/kanthord/config/kanthord/kanthord.yaml
hardening=(--cap-drop=ALL --security-opt=no-new-privileges)

"$engine" image inspect "$image" >/dev/null 2>&1 || die "image $image is missing. Build it with make release-image in kanthord"

if ! "$engine" run --rm "${hardening[@]}" -v "$volume:/var/lib/kanthord" --entrypoint test "$image" -f "$config"; then
	log "creating the configuration in volume $volume"
	"$engine" run --rm "${hardening[@]}" -v "$volume:/var/lib/kanthord" "$image" config init \
		--gateway-bind :: \
		--gateway-allowed-host "$host" \
		--gateway-base-path "$base_path" || die "config init failed"
fi
"$engine" run --rm "${hardening[@]}" -v "$volume:/var/lib/kanthord" "$image" config show | grep -qx "  base_path: $base_path" ||
	die "the configuration in volume $volume has no base_path $base_path"

"$engine" rm -f "$name" >/dev/null 2>&1 || true
case "$(basename "$engine")" in
podman) systemctl --user enable podman-restart.service >/dev/null 2>&1 || die "cannot enable podman-restart.service, so $name would not start after a reboot" ;;
esac
log "starting $name from $image on 127.0.0.1:$port"
"$engine" run -d --name "$name" --restart=always "${hardening[@]}" \
	-p "127.0.0.1:$port:31415" \
	-p "127.0.0.1:1455:1455" \
	-v "$volume:/var/lib/kanthord" \
	"$image" >/dev/null || die "cannot start $name"

for _ in $(seq 1 30); do
	if curl -fs -o /dev/null -H "Host: $host" "http://127.0.0.1:$port$base_path/api/liveness"; then
		log "$name answers at http://127.0.0.1:$port$base_path"
		exit 0
	fi
	sleep 1
done
die "$name did not answer after 30 attempts. Read $engine logs $name"
