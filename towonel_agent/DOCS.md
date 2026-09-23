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

Option keys match the agent's real `TOWONEL_*` environment variables 1:1
(see the [Agent section](https://codeberg.org/towonel/towonel#user-content-agent)
of the upstream config reference) — same approach as the Newt add-on, whose
options are named `PANGOLIN_ENDPOINT`/`NEWT_ID`/`NEWT_SECRET` after Newt's
own env vars.

| Option | Description |
|---|---|
| `TOWONEL_INVITE_TOKEN` | `tt_inv_2_...` from the hub. **Required.** |
| `TOWONEL_AGENT_SERVICES` | JSON array `[{"hostname":"...","origin":"127.0.0.1:8123"}]`. **Required.** |
| `TOWONEL_AGENT_TCP_SERVICES` | optional, JSON array for raw TCP services |
| `TOWONEL_AGENT_UDP_SERVICES` | optional, JSON array for raw UDP services |
| `TOWONEL_AGENT_TRUSTED_EDGES` | optional override for trusted edge IDs; leave empty to use the hub's default |
| `RUST_LOG` | `trace`/`debug`/`info`/`warn`/`error` |
| `custom_env_vars` | additional `NAME=value` pairs, e.g. for future Towonel agent options not yet exposed here |

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

## Health check

`towonel-agent` exposes `GET /healthz` on `127.0.0.1:9090` by default (no
env var needed to enable it); the Dockerfile's `HEALTHCHECK` polls that
directly.

## Architecture note

`armhf` is deliberately left out here (unlike the Newt add-on) — it hasn't
been confirmed that Towonel builds official `armhf`/ARMv6 images. Check the
image's multi-arch manifest list before adding it to `arch:` in
`config.yaml`:

```bash
docker manifest inspect codeberg.org/towonel/towonel-agent:1.7.1
```
