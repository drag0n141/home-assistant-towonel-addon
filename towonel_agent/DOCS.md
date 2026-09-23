# Towonel Agent Add-on

Runs `towonel-agent` directly inside Home Assistant OS, mirroring the Newt
add-on for Pangolin — connects outbound to a self-hosted Towonel hub and
tunnels incoming requests for configured hostnames to local origins (here:
`127.0.0.1:8123` for Home Assistant itself).

## Prerequisites

- A running Towonel hub (`towonel-node`) with a public IP/domain.
- An invite token for the desired hostname:
  ```
  docker exec towonel towonel invite create --name ha --hostnames 'ha.example.com'
  ```

## Configuration

| Option | Description |
|---|---|
| `invite_token` | `tt_inv_2_...` from the hub |
| `agent_services` | JSON array `[{"hostname":"...","origin":"127.0.0.1:8123"}]` |
| `agent_tcp_services` | optional, JSON array for raw TCP ports |
| `agent_udp_services` | optional, JSON array for UDP ports |
| `relay_url` | optional, overrides the relay URL the hub delivers via bootstrap |
| `log_level` | `trace`/`debug`/`info`/`warn`/`error` |
| `custom_env_vars` | additional `NAME=value` pairs, e.g. for future Towonel options |

## Home Assistant `configuration.yaml`

Since the agent runs with `host_network: true` in the same network namespace
as HAOS and reaches HA via `127.0.0.1`, that address needs to be added as a
trusted proxy:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```

## Base image: glibc, not Alpine

The upstream `towonel-agent` image builds with `cargo-zigbuild` targeting
`*-unknown-linux-gnu` and its final stage is `gcr.io/distroless/cc-debian12`
— the binary is dynamically linked against **glibc**. This add-on therefore
builds on `ghcr.io/hassio-addons/debian-base` instead of the musl-based
Alpine `ghcr.io/hassio-addons/base` that most HA add-ons (and the Newt
add-on) use; the binary would not run on musl.

The binary is extracted from `/usr/local/bin/towonel-agent` in the upstream
image (confirmed against its Dockerfile) via a multi-stage `COPY
--from=upstream`, since Towonel does not publish a standalone release
binary like Newt (fosrl/newt) does.

## Architecture note

`armhf` is deliberately left out here (unlike the Newt add-on) — it hasn't
been confirmed that Towonel builds official `armhf`/ARMv6 images. Check the
image's multi-arch manifest list before adding it to `arch:` in
`config.yaml`:

```bash
docker manifest inspect codeberg.org/towonel/towonel-agent:1.7.1
```
