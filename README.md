# NextDNS with DNSMasq Docker Container

A Docker container that runs both NextDNS and dnsmasq services together, providing DNS resolution with NextDNS filtering capabilities and the caching/forwarding benefits of dnsmasq.

## Overview

This container:

- Runs the NextDNS CLI client with your configuration ID
- Runs dnsmasq as a local DNS server and DHCP server
- Automatically monitors and restarts either service if they crash
- Exposes DNS services on port 53 (TCP/UDP)

The inclusion of dnsmasq alongside NextDNS is to provide DHCP server functionality, allowing this container to serve as a complete network solution for DNS filtering and IP address management.

## Requirements

- Docker installed on your host system
- A valid NextDNS configuration ID (from your NextDNS account)

## Usage

### Basic Usage

```bash
docker run -d \
  --name nextdns-dnsmasq \
  -e NEXTDNS_ID=abc123 \
  -e NEXTDNS_ARGUMENTS="-report-client-info -cache-size 10MB -log-queries" \
  -p 53:53/udp \
  -p 53:53/tcp \
  -v /path/to/custom/dnsmasq/config:/etc/dnsmasq.d \
  --cap-add NET_ADMIN \
  --restart unless-stopped \
  marcoamtz/nextdns-dnsmasq:latest
```

### Environment Variables

| Variable            | Required | Description                                     |
| ------------------- | -------- | ----------------------------------------------- |
| `NEXTDNS_ID`        | Yes      | Your NextDNS configuration ID                   |
| `NEXTDNS_ARGUMENTS` | No       | Additional arguments to pass to the NextDNS CLI |

### Docker Compose Example

```yaml
version: "3"

services:
  nextdns-dnsmasq:
    image: marcoamtz/nextdns-dnsmasq:latest
    container_name: nextdns-dnsmasq
    environment:
      - NEXTDNS_ID=abc123
      - NEXTDNS_ARGUMENTS=-report-client-info -cache-size 10MB -log-queries
    ports:
      - "53:53/udp"
      - "53:53/tcp"
    volumes:
      - /path/to/custom/dnsmasq/config:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
```

> **Note on NET_ADMIN capability**: The `NET_ADMIN` capability grants the container permissions to perform network-related operations. When using host networking, this capability is required for proper functionality. When using port mapping (as in the example above), it's recommended but not strictly required for basic operation, as Docker handles the port forwarding. However, some advanced functionality of NextDNS or dnsmasq might still benefit from these permissions.

### Alternative: Using Host Network

If you prefer host networking for potentially better performance and DHCP capabilities:

```yaml
version: "3"

services:
  nextdns-dnsmasq:
    image: marcoamtz/nextdns-dnsmasq:latest
    container_name: nextdns-dnsmasq
    network_mode: host
    environment:
      - NEXTDNS_ID=abc123
      - NEXTDNS_ARGUMENTS=-report-client-info -cache-size 10MB -log-queries
    volumes:
      - /path/to/custom/dnsmasq/config:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
```

## How It Works

The container runs both NextDNS and dnsmasq services:

1. NextDNS connects to NextDNS servers using your configuration ID, providing DNS filtering
2. dnsmasq provides DHCP server functionality for network clients, as well as caching and local DNS resolution
3. A monitoring process ensures both services remain running and restarts them if needed

### DHCP Configuration

To utilize the DHCP server functionality, you'll need to add a custom dnsmasq configuration. Mount a volume to `/etc/dnsmasq.d` and include configuration files with DHCP settings such as:

```
# Example DHCP configuration
dhcp-range=192.168.1.50,192.168.1.150,12h
dhcp-option=option:router,192.168.1.1
dhcp-option=option:dns-server,192.168.1.1
```

## Building the Container

To build the container yourself:

```bash
git clone https://github.com/marcoamtz/nextdns-dnsmasq-docker.git
cd nextdns-dnsmasq-docker
docker build -t nextdns-dnsmasq .
```

## Technical Notes

- **Compiled from Source**: DNSMasq is compiled from source rather than installed from package repositories, ensuring the latest version with all fixes.

- **Multi-stage Build**: Uses Docker multi-stage build to separate the build environment from the runtime environment, resulting in a much smaller final image.

- **Source Verification**: PGP signature verification ensures the DNSMasq source code is authentic and has not been tampered with.

## License

This project is licensed under the [Apache License 2.0](LICENSE) - see the LICENSE file for details.
