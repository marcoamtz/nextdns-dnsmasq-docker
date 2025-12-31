FROM alpine:3.22.2

# Version arguments for main components
# NextDNS: Version from nextdns.io repository (no Alpine suffix)
ARG NEXTDNS_VERSION="1.46.0"
# DNSMasq: Version from Alpine repository (includes -r0 suffix)
ARG DNSMASQ_VERSION="2.91-r0"
ARG S6_OVERLAY_VERSION="3.2.0.2"

# Target architecture (automatically set by Docker buildx)
ARG TARGETARCH

# Add labels as per best practices
LABEL maintainer="Marco Martinez" \
    description="NextDNS with DNSMasq proxy" \
    version="0.0.11" \
    nextdns.version="${NEXTDNS_VERSION}" \
    dnsmasq.version="${DNSMASQ_VERSION}"

# Set environment variables
ENV NEXTDNS_ARGUMENTS="-listen :5053 -report-client-info -log-queries -cache-size 10MB" \
    NEXTDNS_ID=abcdef \
    LOG_DIR=/logs \
    S6_VERBOSITY=1

# Install s6-overlay (multi-arch: amd64/arm64)
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN set -ex && \
    # Map Docker arch to s6-overlay arch naming
    case "${TARGETARCH}" in \
        amd64) S6_ARCH="x86_64" ;; \
        arm64) S6_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    # Download architecture-specific package
    wget -O /tmp/s6-overlay-${S6_ARCH}.tar.xz \
        https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz && \
    # Extract s6-overlay
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz && \
    tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz && \
    rm -f /tmp/s6-overlay-*.tar.xz

# Install runtime dependencies
RUN set -ex && \
    # Add NextDNS repository
    wget -qO /etc/apk/keys/nextdns.pub https://repo.nextdns.io/nextdns.pub && \
    echo "https://repo.nextdns.io/apk" >> /etc/apk/repositories && \
    # Alpine edge repository (uncomment to use newer dnsmasq versions)
    # echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Update and install packages
    apk update && \
    apk --no-cache add \
        nextdns=${NEXTDNS_VERSION} \
        ca-certificates \
        netcat-openbsd && \
    # Install dnsmasq from standard repository (creates 'dnsmasq' user/group)
    apk --no-cache add dnsmasq=${DNSMASQ_VERSION} && \
    # Install dnsmasq from edge repository (uncomment to use instead of standard)
    # apk --no-cache add --repository https://dl-cdn.alpinelinux.org/alpine/edge/main dnsmasq=${DNSMASQ_VERSION} && \
    # Create necessary directories
    mkdir -p /etc/dnsmasq.d ${LOG_DIR} /dhcp-leases && \
    chown dnsmasq:dnsmasq ${LOG_DIR} /dhcp-leases && \
    # Cleanup
    rm -rf /var/cache/apk/* /tmp/* && \
    # Verify installations
    nextdns version && \
    dnsmasq --version

# Copy configurations
COPY dnsmasq.conf /etc/dnsmasq.conf

# Copy s6-overlay service definitions (includes s6-log configurations)
COPY --chmod=755 rootfs/ /

# Expose DNS and DHCP ports
EXPOSE 53/tcp 53/udp 67/udp

# Volume for logs
VOLUME ${LOG_DIR}

# Volume for DHCP leases (persists across container restarts)
VOLUME /dhcp-leases

# Enhanced health check - test both connectivity and DNS resolution
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD nc -z localhost 53 && nslookup localhost 127.0.0.1 > /dev/null || exit 1

# s6-overlay entrypoint
ENTRYPOINT ["/init"]
