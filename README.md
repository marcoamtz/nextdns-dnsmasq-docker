# NextDNS with DNSMasq Docker Container

A Docker container running NextDNS with DNSMasq as a proxy.

## Features

- NextDNS client with DNSMasq proxy
- **Version pinning** for reproducible builds and controlled updates
- **s6-log** for efficient logging with automatic rotation
- Automatic service monitoring and restart with health checks
- DHCP server functionality (optional)
- **Alpine-based** for minimal size
- **s6-overlay** for proper process supervision with instant restarts

## Overview

This container:

- Runs the NextDNS CLI client with your configuration ID
- Runs dnsmasq as a local DNS server and DHCP server
- Uses s6-overlay for instant service restarts if they crash
- Exposes DNS services on port 53 (TCP/UDP) and DHCP on port 67 (UDP)
- Uses **pinned versions** for NextDNS, DNSMasq, and s6-overlay
- Uses s6-log for efficient logging with automatic size-based rotation

The inclusion of dnsmasq alongside NextDNS is to provide DHCP server functionality, allowing this container to serve as a complete network solution for DNS filtering and IP address management.

## Requirements

- Docker installed on your host system
- A valid NextDNS configuration ID (from your NextDNS account)

## Usage

### Basic Usage

```bash
docker run -d \
  --name nextdns-dnsmasq \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 67:67/udp \
  -e NEXTDNS_ID=yourConfigID \
  -e NEXTDNS_ARGUMENTS="-report-client-info -cache-size 10MB -log-queries" \
  -v /path/to/your/logs:/logs \
  -v /path/to/custom/dnsmasq/config:/etc/dnsmasq.d \
  -v /path/to/dhcp-leases:/dhcp-leases \
  --cap-add NET_ADMIN \
  --restart unless-stopped \
  marcoamtz/nextdns-dnsmasq:latest
```

### Docker Compose (Recommended)

A `docker-compose.yml` is included in this repository. To get started:

1. Copy the example environment file and add your NextDNS configuration:

```bash
cp .env.example .env
# Edit .env and set your NEXTDNS_ID
```

2. Create the required directories:

```bash
mkdir -p config logs dhcp-leases
```

3. Start the container:

```bash
docker compose up -d
```

The included compose file uses host networking (recommended for homelab DNS/DHCP). To use port mapping instead, modify `docker-compose.yml`:

```yaml
services:
  nextdns-dnsmasq:
    # Remove this line:
    # network_mode: host
    # Add port mappings:
    ports:
      - "53:53/udp"
      - "53:53/tcp"
      - "67:67/udp"
```

**Benefits of host networking for DNS/DHCP:**

- ✅ Better performance for network services
- ✅ DHCP broadcasts work correctly
- ✅ No port mapping complexity
- ✅ Direct network interface access

> **Note on NET_ADMIN capability**: The `NET_ADMIN` capability grants the container permissions to perform network-related operations. Required for host networking and recommended for port mapping mode.

## Environment Variables

- `NEXTDNS_ID`: Your NextDNS configuration ID (required)
- `NEXTDNS_ARGUMENTS`: Arguments to pass to the NextDNS client (default: `-listen :5053 -report-client-info -log-queries -cache-size 10MB`)
- `LOG_DIR`: Directory where logs will be stored (default: `/logs`)

## Logs

Logs are written to the volume mounted at `/logs` using s6-log:

- NextDNS logs: `/logs/nextdns/current`
- DNSMasq logs: `/logs/dnsmasq/current`

### Viewing Logs

```bash
# View current logs
cat /logs/nextdns/current
cat /logs/dnsmasq/current

# Follow logs in real-time
tail -f /logs/nextdns/current

# From outside the container
docker exec <container> cat /logs/nextdns/current
```

### Log Rotation

Logs are automatically rotated using s6-log with the following settings:

- Rotates when files reach 1MB
- Keeps 5 rotated files (~5MB max per service)
- Atomic rotation (no race conditions)
- Rotated files are named with timestamps (e.g., `@400000005f5e100c...s`)

## How It Works

The container runs both NextDNS and dnsmasq services:

```
Client → dnsmasq (port 53) → NextDNS (port 5053) → NextDNS Cloud
```

1. **dnsmasq** listens on port 53 and forwards all DNS queries to NextDNS
2. **NextDNS** connects to NextDNS servers using your configuration ID, providing DNS filtering and privacy
3. **dnsmasq** also provides DHCP server functionality (optional) for IP address management
4. **s6-overlay** supervises all services and instantly restarts them if they crash
5. **s6-log** captures service output and handles automatic log rotation

### Service Dependencies

The container uses s6's native dependency and readiness system:

1. **NextDNS** starts and signals readiness when port 5053 is listening
2. **dnsmasq** waits for NextDNS readiness before starting (via `dependencies.d/`)
3. This ensures DNS queries never fail due to NextDNS not being ready

### DHCP Configuration

To utilize the DHCP server functionality, you'll need to add a custom dnsmasq configuration. Mount a volume to `/etc/dnsmasq.d` and include configuration files with DHCP settings such as:

```
# Example DHCP configuration
dhcp-range=192.168.1.50,192.168.1.150,12h
dhcp-option=option:router,192.168.1.1
dhcp-option=option:dns-server,192.168.1.1
```

### DHCP Lease Persistence

DHCP leases are stored at `/dhcp-leases/dnsmasq.leases`. To ensure leases persist across container restarts (preventing IP conflicts and maintaining stable device assignments), mount a volume to this location:

```bash
-v /path/to/dhcp-leases:/dhcp-leases
```

> **Important**: Without this volume mount, all DHCP leases will be lost when the container restarts, which can cause IP address conflicts or devices receiving different IPs than expected.

## Version Management

This container uses **version pinning** to ensure reproducible builds. Software versions are controlled via ARG variables in the Dockerfile:

- **NextDNS**: from nextdns.io repository
- **DNSMasq**: from Alpine repository
- **s6-overlay**: process supervisor

Check the Dockerfile for current pinned versions. All versions are also exposed as Docker labels for easy inspection:

```bash
docker inspect --format='{{json .Config.Labels}}' nextdns-dnsmasq | jq
```

### Building with Custom Versions

```bash
# Standard build (uses pinned versions from Dockerfile)
docker build -t nextdns-dnsmasq .

# Override a specific version
docker build --build-arg DNSMASQ_VERSION=x.xx-r0 -t nextdns-dnsmasq .
```

Available build args: `NEXTDNS_VERSION`, `DNSMASQ_VERSION`, `S6_OVERLAY_VERSION`.

### Building the Container

To build the container yourself:

```bash
git clone https://github.com/marcoamtz/nextdns-dnsmasq-docker.git
cd nextdns-dnsmasq-docker
docker build -t nextdns-dnsmasq .
```

## Technical Notes

- **Alpine-based**: Uses Alpine Linux as base for minimal size and security
- **s6-overlay**: Event-driven process supervision with instant restarts (no polling loops)
- **Version Pinning**: NextDNS, DNSMasq, and s6-overlay versions are explicitly pinned for reproducible builds
- **Privilege Separation**: Services run as non-root user `dnsmasq` where possible (see Security section below)
- **Health Check**: Tests DNS port connectivity every 60 seconds
- **Self-Healing**: s6-overlay automatically restarts crashed services immediately
- **s6-log Integration**: Efficient logging with atomic rotation, no external dependencies
- **Service Dependencies**: dnsmasq waits for NextDNS readiness via s6's native dependency system
- **Repository Flexibility**: Supports both standard Alpine and edge repositories for DNSMasq

## Security

This container implements privilege separation to minimize the attack surface:

- **NextDNS**: Runs entirely as non-root user `dnsmasq` (binds to unprivileged port 5053)
- **dnsmasq**: Starts as root to bind to privileged port 53, then immediately drops privileges to user `dnsmasq`
- **Package-provided user**: Uses the `dnsmasq` user/group created by Alpine's dnsmasq package
- **Minimal permissions**: Log and DHCP lease directories are owned by the `dnsmasq` user

This approach follows the principle of least privilege while maintaining the ability to bind to privileged DNS port 53.

## License

This project is licensed under the [Apache License 2.0](LICENSE) - see the LICENSE file for details.
