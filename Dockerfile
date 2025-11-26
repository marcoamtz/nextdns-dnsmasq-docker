FROM alpine:3.22.2

# Version arguments for main components
# NextDNS: Version from nextdns.io repository (no Alpine suffix)
ARG NEXTDNS_VERSION="1.46.0"
# DNSMasq: Version from Alpine repository (includes -r0 suffix)
ARG DNSMASQ_VERSION="2.91-r0"

# Add labels as per best practices
LABEL maintainer="Marco Martinez" \
    description="NextDNS with DNSMasq proxy" \
    version="0.0.10" \
    nextdns.version="${NEXTDNS_VERSION}" \
    dnsmasq.version="${DNSMASQ_VERSION}"

# Set environment variables
ENV NEXTDNS_ARGUMENTS="-listen :5053 -report-client-info -log-queries -cache-size 10MB" \
    NEXTDNS_ID=abcdef \
    LOG_DIR=/logs

# Install runtime dependencies
RUN set -ex && \
    # Add NextDNS repository
    wget -qO /etc/apk/keys/nextdns.pub https://repo.nextdns.io/nextdns.pub && \
    echo "https://repo.nextdns.io/apk" >> /etc/apk/repositories && \
    # Add Alpine edge repository
    # echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories && \
    # Update and install packages
    apk update && \
    # Install nextdns and other packages
    apk --no-cache add \
        nextdns=${NEXTDNS_VERSION} \
        ca-certificates \
        tini \
        logrotate \
        su-exec && \
    # Install dnsmasq regular repository (creates 'dnsmasq' user/group)
    apk --no-cache add dnsmasq=${DNSMASQ_VERSION} && \
    # Install dnsmasq from edge repository
    # apk --no-cache add --repository https://dl-cdn.alpinelinux.org/alpine/edge/main dnsmasq=${DNSMASQ_VERSION} && \
    # Create necessary directories with proper ownership (use dnsmasq user from package)
    mkdir -p /etc/dnsmasq.d ${LOG_DIR} /dhcp-leases && \
    chown dnsmasq:dnsmasq ${LOG_DIR} /dhcp-leases && \
    # Cleanup
    rm -rf /var/cache/apk/* /tmp/* && \
    # Verify installations
    nextdns version && \
    dnsmasq --version

# Copy configurations
COPY dnsmasq.conf /etc/dnsmasq.conf
COPY --chmod=755 startup.sh /startup.sh
COPY --chmod=755 create-logrotate-conf.sh /create-logrotate-conf.sh

# Expose DNS and DHCP ports
EXPOSE 53/tcp 53/udp 67/udp

# Volume for logs
VOLUME ${LOG_DIR}

# Volume for DHCP leases (persists across container restarts)
VOLUME /dhcp-leases

# Enhanced health check - test both connectivity and DNS resolution
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD nc -zu localhost 53 && nslookup localhost 127.0.0.1 > /dev/null || exit 1

# Use tini as init with proper signal handling
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["/startup.sh"]
