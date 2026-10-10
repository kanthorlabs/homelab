# homelab

Setup of a home server that publishes local services through a Cloudflare Tunnel and nginx.

Every service listens on `127.0.0.1` only. The tunnel sends every request of one host to nginx, and nginx routes each `/s/<service-name>` path to its local service.

## Before you start

- A Debian or Ubuntu server with `sudo`.
- A Cloudflare Tunnel that runs on the server as the `cloudflared` systemd service.
- A Cloudflare Access application that covers the full host.
- podman or docker for the containers.

## Configure

Copy `.env.example` to `.env`, then set your public host:

```sh
cp .env.example .env
```

`.env` stays on the server. Git ignores it. The scripts read `.env` as data and never run it.

## Targets

| Target                  | Effect                                                                         |
| ----------------------- | ------------------------------------------------------------------------------ |
| `make nginx`            | Install the nginx site on `127.0.0.1:80` and the homepage in `/var/www/homelab`. A failed `nginx -t` restores the previous site. |
| `make stats`            | Install the `homelab-stats` timer. Every 60 s it writes the CPU, RAM and disk usage to `/run/homelab-stats/stats.json`. |
| `make kanthord`         | Run the kanthord container under `/s/kanthord` on `127.0.0.1:31416`.          |
| `make kanthord-cleanup` | Remove the kanthord container. Ask before the removal of its volume.          |
| `make check`            | Lint the scripts with shellcheck.                                              |

`make help` lists the variables of each target.

## Security model

- nginx and every container bind `127.0.0.1`. The server opens no port to the local network or to the internet.
- Cloudflare terminates HTTPS. Cloudflare Access authenticates every request before it reaches the tunnel.
- nginx trusts `CF-Connecting-IP` from `127.0.0.1` only, limits requests and connections per client, hides its version and refuses hidden files.
- Containers run without Linux capabilities and with `no-new-privileges`.
- The scripts validate every host, port, name and image before they use it.
- This repository holds no secret, host name, address or credential. Keep them in `.env` or on the server.

## Homepage

`www/index.html` is the homepage at `/`. It looks from a riverside stall over the wide Mekong at the floating market of Cái Răng. The bridge with its billboard stands on the horizon, and the sun rises behind it. Small boats moor along both far banks. A boat with a name tag is a service, and its lantern and tag show its health:

- Green, healthy: the last check answered `2xx` within 1.5 s.
- Orange, warning: the answer was slow, or a part reports a fault.
- Red, down: the check failed or timed out after 5 s.

The page probes each service every 15 s from the browser. Hover or tap a boat to read its status, uptime, latency and last check. Add a service to the `SERVICES` list in `www/index.html`.

The board on the right dock shows the CPU, RAM and disk usage of the machine. `make stats` installs the timer that writes these values. The timer runs a sandboxed script as the `homelab-stats` system user without network access. nginx serves the file read-only at `/stats.json`. The board shows `--` when the reading is older than 3 minutes.

nginx serves the page with a strict Content Security Policy. `make nginx` computes the hashes of the inline script and style, so the page runs no other code.

Read [SECURITY.md](SECURITY.md) to report a vulnerability.
