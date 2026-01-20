# NextDNS with DNSMasq

A lightweight Docker container combining NextDNS client with DNSMasq for DNS filtering, privacy, and optional DHCP server functionality.

## Features

- **NextDNS client** with DNSMasq proxy for DNS filtering and privacy
- **DHCP server** functionality (optional)
- **s6-overlay** for proper process supervision with instant restarts
- **Version pinning** for reproducible builds
- **Alpine-based** for minimal image size (~25MB)
- **Multi-arch support**: `amd64` and `arm64`

## Quick Start

```bash
docker run -d \
  --name nextdns-dnsmasq \
  -p 53:53/tcp \
  -p 53:53/udp \
  -e NEXTDNS_ID=your-config-id \
  --cap-add NET_ADMIN \
  --restart unless-stopped \
  marcoamtz/nextdns-dnsmasq:latest
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `NEXTDNS_ID` | Your NextDNS configuration ID | **Required** |
| `NEXTDNS_ARGUMENTS` | Additional NextDNS CLI arguments | `-listen :5053 -report-client-info -log-queries -cache-size 10MB` |
| `LOG_DIR` | Log directory path | `/logs` |

## Volumes

| Path | Description |
|------|-------------|
| `/logs` | Service logs (NextDNS and DNSMasq) with automatic rotation |
| `/etc/dnsmasq.d` | Custom DNSMasq configuration files |
| `/dhcp-leases` | DHCP lease persistence (recommended for DHCP) |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 53 | TCP/UDP | DNS queries |
| 67 | UDP | DHCP server (optional) |

## Docker Compose

```yaml
services:
  nextdns-dnsmasq:
    image: marcoamtz/nextdns-dnsmasq:latest
    container_name: nextdns-dnsmasq
    network_mode: host  # Recommended for DNS/DHCP
    environment:
      - NEXTDNS_ID=your-config-id
      - NEXTDNS_ARGUMENTS=-report-client-info -cache-size 10MB -log-queries
    volumes:
      - ./config:/etc/dnsmasq.d
      - ./logs:/logs
      - ./dhcp-leases:/dhcp-leases
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
```

## How It Works

```
Client → DNSMasq (port 53) → NextDNS (port 5053) → NextDNS Cloud
```

1. **DNSMasq** listens on port 53 and forwards DNS queries to NextDNS
2. **NextDNS** connects to NextDNS servers using your configuration ID
3. **s6-overlay** supervises services and restarts them instantly if they crash

## DHCP Configuration

Mount a volume to `/etc/dnsmasq.d` with your DHCP configuration:

```
# /etc/dnsmasq.d/dhcp.conf
dhcp-range=192.168.1.50,192.168.1.150,12h
dhcp-option=option:router,192.168.1.1
dhcp-option=option:dns-server,192.168.1.1
```

**Important**: Mount `/dhcp-leases` to persist leases across container restarts.

## Viewing Logs

```bash
# From host (with volume mounted)
tail -f ./logs/nextdns/current
tail -f ./logs/dnsmasq/current

# From inside container
docker exec nextdns-dnsmasq cat /logs/nextdns/current
```

Logs auto-rotate at 1MB, keeping 5 files (~5MB max per service).

## Version Information

Check current versions via Docker labels:

```bash
docker inspect --format='{{json .Config.Labels}}' nextdns-dnsmasq | jq
```

## Security

- **DNSMasq** starts as root to bind port 53, then drops to unprivileged `dnsmasq` user
- **NextDNS** runs entirely as non-root user on unprivileged port 5053
- **Minimal attack surface** with Alpine base image

## Links

- [GitHub Repository](https://github.com/marcoamtz/nextdns-dnsmasq-docker)
- [NextDNS](https://nextdns.io)

## License

[Apache License 2.0](https://github.com/marcoamtz/nextdns-dnsmasq-docker/blob/main/LICENSE)
