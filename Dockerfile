FROM alpine:3.22

# Add labels as per best practices
LABEL maintainer="Marco Martinez" \
    description="NextDNS with DNSMasq proxy" \
    version="0.0.7"

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
        nextdns \
        ca-certificates \
        tini \
        logrotate && \
    # Install dnsmasq regular repository
    apk --no-cache add dnsmasq && \
    # Install dnsmasq from edge repository
    # apk --no-cache add --repository https://dl-cdn.alpinelinux.org/alpine/edge/main dnsmasq && \
    # Create necessary directories
    mkdir -p /etc/dnsmasq.d ${LOG_DIR} && \
    # Cleanup
    rm -rf /var/cache/apk/* /tmp/* && \
    # Verify installations
    nextdns version && \
    dnsmasq --version

# Copy configurations
COPY dnsmasq.conf /etc/dnsmasq.conf
COPY --chmod=755 startup.sh /startup.sh
COPY --chmod=755 create-logrotate-conf.sh /create-logrotate-conf.sh

# Expose DNS ports
EXPOSE 53/tcp 53/udp

# Volume for logs
VOLUME ${LOG_DIR}

# More efficient health check - use nc for faster response
HEALTHCHECK --interval=60s --timeout=2s --start-period=5s --retries=3 \
    CMD nc -zu localhost 53 || exit 1

# Use tini as init with proper signal handling
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["/startup.sh"]
