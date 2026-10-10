# Shared helpers. Source this file. Do not run it.

set -euo pipefail
umask 077

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$ROOT/.env"

HOMELAB_PORT=${HOMELAB_PORT:-31416}
HOMELAB_CONTAINER=${CONTAINER:-kanthord-homelab}
HOMELAB_VOLUME=${VOLUME:-kanthord-homelab}

log() { printf '%s: %s\n' "$SCRIPT_NAME" "$*"; }
warn() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; }
die() { warn "$*"; exit 1; }

# Ask a yes/no question. YES=1 answers yes. No terminal answers no.
confirm() {
	if [ "${YES:-0}" = "1" ]; then
		log "$1 -> yes (YES=1)"
		return 0
	fi
	if [ ! -t 0 ]; then
		warn "$1 -> no terminal, and no policy. Refused"
		return 1
	fi
	printf '%s: %s [y/N] ' "$SCRIPT_NAME" "$1" >&2
	local answer
	read -r answer
	case "$answer" in [yY] | [yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

require_command() { command -v "$1" >/dev/null 2>&1 || die "$1 is not installed"; }

# env_value <name> -> the last value of <name> in .env, without a shell evaluation
env_value() {
	[ -f "$ENV_FILE" ] || return 0
	sed -n "s/^$1=//p" "$ENV_FILE" | tail -n 1
}

# homelab_host -> the public host from HOMELAB_HOST or from .env
homelab_host() {
	local host=${HOMELAB_HOST:-}
	[ -n "$host" ] || host=$(env_value HOMELAB_HOST)
	[ -n "$host" ] || die "HOMELAB_HOST is not set. Write HOMELAB_HOST=<host> to $ENV_FILE"
	case "$host" in
	*[!A-Za-z0-9.-]* | .* | *. | *..* | -* ) die "HOMELAB_HOST $host is not a host name" ;;
	esac
	printf '%s' "$host"
}

# homelab_port -> HOMELAB_PORT after a range check
homelab_port() {
	case "$HOMELAB_PORT" in
	'' | *[!0-9]* | 0*) die "HOMELAB_PORT $HOMELAB_PORT is not a port" ;;
	esac
	if [ "$HOMELAB_PORT" -lt 1024 ] || [ "$HOMELAB_PORT" -gt 65535 ]; then
		die "HOMELAB_PORT $HOMELAB_PORT is not in 1024-65535"
	fi
	printf '%s' "$HOMELAB_PORT"
}

# homelab_name <label> <value> -> the value when it is a container or volume name
homelab_name() {
	case "$2" in
	'' | [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*) die "$1 $2 is not a valid name" ;;
	esac
	printf '%s' "$2"
}

# homelab_image <value> -> the value when it is an image reference
homelab_image() {
	case "$1" in
	'' | [!A-Za-z0-9]* | *[!A-Za-z0-9_.:/@-]*) die "IMAGE $1 is not an image reference" ;;
	esac
	printf '%s' "$1"
}

# homelab_find <command> -> its path on PATH or in an sbin directory
homelab_find() {
	command -v "$1" 2>/dev/null && return 0
	local dir
	for dir in /usr/local/sbin /usr/sbin /sbin; do
		if [ -x "$dir/$1" ]; then
			printf '%s\n' "$dir/$1"
			return 0
		fi
	done
	return 1
}

# homelab_require <command> <package> -> install the package with apt-get after a confirmation
homelab_require() {
	homelab_find "$1" >/dev/null && return 0
	command -v apt-get >/dev/null 2>&1 || die "$1 is missing. Install the package $2"
	confirm "$1 is missing. Install the package $2 with sudo apt-get" || die "$1 is missing. Install the package $2"
	sudo apt-get update || die "apt-get update failed"
	sudo apt-get install -y "$2" || die "apt-get could not install $2"
	homelab_find "$1" >/dev/null || die "$2 is installed, but $1 is still missing"
}

# homelab_engine -> CONTAINER_ENGINE, or the first of podman and docker, or podman after its installation
homelab_engine() {
	local engine=${CONTAINER_ENGINE:-} candidate
	if [ -z "$engine" ]; then
		for candidate in podman docker; do
			if command -v "$candidate" >/dev/null 2>&1; then
				engine=$candidate
				break
			fi
		done
	fi
	if [ -z "$engine" ]; then
		homelab_require podman podman >&2
		engine=podman
	fi
	case "$(basename "$engine")" in
	podman | docker) ;;
	*) die "CONTAINER_ENGINE $engine is not podman or docker" ;;
	esac
	require_command "$engine"
	printf '%s' "$engine"
}
