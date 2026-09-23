# Towonel Agent Add-on

Führt `towonel-agent` direkt in Home Assistant OS aus, analog zum Newt-Add-on
für Pangolin – verbindet sich ausgehend zu einem selbstgehosteten Towonel-Hub
und tunnelt eingehende Requests für konfigurierte Hostnamen zu lokalen
Origins (hier: `127.0.0.1:8123` für Home Assistant selbst).

## Voraussetzungen

- Ein laufender Towonel-Hub (`towonel-node`) mit öffentlicher IP/Domain.
- Ein Invite-Token für den gewünschten Hostnamen:
  ```
  docker exec towonel towonel invite create --name ha --hostnames 'ha.example.com'
  ```

## Konfiguration

| Option | Beschreibung |
|---|---|
| `invite_token` | `tt_inv_2_...` vom Hub |
| `agent_services` | JSON-Array `[{"hostname":"...","origin":"127.0.0.1:8123"}]` |
| `agent_tcp_services` | optional, JSON-Array für rohe TCP-Ports |
| `agent_udp_services` | optional, JSON-Array für UDP-Ports |
| `relay_url` | optional, überschreibt die vom Hub via Bootstrap gelieferte Relay-URL |
| `log_level` | `trace`/`debug`/`info`/`warn`/`error` |
| `custom_env_vars` | zusätzliche `NAME=value`-Paare, z.B. für zukünftige Towonel-Optionen |

## Home Assistant `configuration.yaml`

Da der Agent per `host_network: true` im gleichen Netzwerk-Namespace wie
HAOS läuft und HA über `127.0.0.1` anspricht, muss `127.0.0.1` als Trusted
Proxy eingetragen werden:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
```

## Vor dem Bauen prüfen

Der Binary-Pfad im Upstream-Image (`/usr/local/bin/towonel-agent` im
Dockerfile) ist nicht verifiziert. Vor dem ersten Build prüfen:

```bash
docker run --rm --entrypoint sh codeberg.org/towonel/towonel-agent:1.7.1 -c 'which towonel-agent'
```

Falls der Pfad abweicht, `COPY --from=upstream` im Dockerfile entsprechend
anpassen.

## Architektur-Hinweis

`armhf` ist hier bewusst ausgelassen (anders als beim Newt-Add-on) – nicht
bestätigt, dass Towonel offizielle `armhf`/ARMv6-Images baut. Vor dem
Hinzufügen zu `arch:` in `config.yaml` die Multi-Arch-Manifest-Liste des
Images prüfen:

```bash
docker manifest inspect codeberg.org/towonel/towonel-agent:1.7.1
```
