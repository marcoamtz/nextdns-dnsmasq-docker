# NextDNS with DNSMasq Docker Container

A Docker container running NextDNS with DNSMasq as a proxy.

## Features

- NextDNS client with DNSMasq proxy
- **Version pinning** for reproducible builds and controlled updates
- External logging with automatic rotation (logs rotate at 10MB)
- Automatic service monitoring and restart with enhanced health checks
- DHCP server functionality (optional)
- **Alpine-based** for minimal size (~5MB base image)
- Proper signal handling and process management with tini

## Overview

This container:

- Runs the NextDNS CLI client with your configuration ID
- Runs dnsmasq as a local DNS server and DHCP server
- Automatically monitors and restarts either service if they crash
- Exposes DNS services on port 53 (TCP/UDP) and DHCP on port 67 (UDP)
- Uses **pinned versions** for NextDNS (v1.46.0) and DNSMasq (v2.91)
- Writes logs to an external volume with automatic rotation

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

Logs are written to the volume mounted at `/logs`:

- NextDNS logs: `/logs/nextdns.log`
- DNSMasq logs: `/logs/dnsmasq.log`

Logs are automatically rotated when they reach 10MB using logrotate with the following settings:

- Rotates when files reach 10MB
- Keeps 3 rotated files
- Uses compression for rotated logs
- Uses copytruncate to handle rotation without interrupting services

## How It Works

The container runs both NextDNS and dnsmasq services:

```
Client → dnsmasq (port 53) → NextDNS (port 5053) → NextDNS Cloud
```

1. **dnsmasq** listens on port 53 and forwards all DNS queries to NextDNS
2. **NextDNS** connects to NextDNS servers using your configuration ID, providing DNS filtering and privacy
3. **dnsmasq** also provides DHCP server functionality (optional) for IP address management
4. A monitoring process ensures both services remain running and restarts them if needed
5. Logs are written to external files and automatically rotated when they reach 10MB

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

- **NextDNS**: `1.46.0` (from nextdns.io repository)
- **DNSMasq**: `2.91-r0` (from Alpine repository)

### Building with Custom Versions

```bash
# Standard build with pinned versions
docker build -t nextdns-dnsmasq .

# Build with custom versions
docker build \
  --build-arg NEXTDNS_VERSION=1.46.0 \
  --build-arg DNSMASQ_VERSION=2.91-r0 \
  --no-cache \
  -t nextdns-dnsmasq .
```

### Building the Container

To build the container yourself:

```bash
git clone https://github.com/marcoamtz/nextdns-dnsmasq-docker.git
cd nextdns-dnsmasq-docker
docker build -t nextdns-dnsmasq .
```

## Technical Notes

- **Alpine-based**: Uses Alpine Linux as base for minimal size (~5MB) and security
- **Version Pinning**: Both NextDNS and DNSMasq versions are explicitly pinned for reproducible builds
- **Privilege Separation**: Services run as non-root user `dnsmasq` where possible (see Security section below)
- **Enhanced Health Check**: Tests both port connectivity and DNS resolution functionality
- **Process Management**: Uses tini as PID 1 for proper signal handling and zombie process reaping
- **Self-Healing**: Automatic monitoring and restart of DNS/DHCP services if they crash
- **Optimized Logging**: Structured logging with automatic rotation and compression
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
