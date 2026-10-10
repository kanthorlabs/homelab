#!/usr/bin/env bash
SCRIPT_NAME=homelab-kanthord-cleanup
. "$(dirname "$0")/../lib/common.sh"

engine=$(homelab_engine) || exit 1
name=$(homelab_name CONTAINER "$HOMELAB_CONTAINER") || exit 1
volume=$(homelab_name VOLUME "$HOMELAB_VOLUME") || exit 1

if "$engine" container inspect "$name" >/dev/null 2>&1; then
	"$engine" rm -f "$name" >/dev/null || die "cannot remove container $name"
	log "removed container $name"
fi

if "$engine" volume inspect "$volume" >/dev/null 2>&1; then
	if confirm "remove volume $volume with its master key and data"; then
		"$engine" volume rm "$volume" >/dev/null || die "cannot remove volume $volume"
		log "removed volume $volume"
	else
		log "kept volume $volume"
	fi
fi

log "the nginx site stays. Run make kanthord to start again"
