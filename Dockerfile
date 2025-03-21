# Build stage
FROM alpine:3.21 AS builder

# Set environment variables for build
ENV DNSMASQ_VERSION=2.91

# Install build dependencies
RUN set -ex && \
    apk update && \
    apk --no-cache add \
        build-base \
        make \
        gcc \
        wget \
        gnupg \
        linux-headers \
        libcap-dev

# Download, verify and compile dnsmasq from source
RUN cd /tmp && \
    # Download dnsmasq source and signature
    wget https://thekelleys.org.uk/dnsmasq/dnsmasq-${DNSMASQ_VERSION}.tar.gz && \
    wget https://thekelleys.org.uk/dnsmasq/dnsmasq-${DNSMASQ_VERSION}.tar.gz.asc && \
    # Import Simon Kelley's PGP key (dnsmasq author)
    wget -O- https://thekelleys.org.uk/srkgpg.txt > /tmp/dnsmasq-key.asc && \
    gpg --import /tmp/dnsmasq-key.asc && \
    # Verify signature
    gpg --verify dnsmasq-${DNSMASQ_VERSION}.tar.gz.asc dnsmasq-${DNSMASQ_VERSION}.tar.gz && \
    # Extract and compile
    tar -xzvf dnsmasq-${DNSMASQ_VERSION}.tar.gz && \
    cd dnsmasq-${DNSMASQ_VERSION} && \
    make && \
    make install

# Final stage
FROM alpine:3.21

# Add labels as per best practices
LABEL maintainer="Marco Martinez" \
    description="NextDNS with DNSMasq proxy" \
    version="0.0.2"

# Set environment variables
ENV NEXTDNS_ARGUMENTS="-listen :5053 -report-client-info -log-queries -cache-size 10MB" \
    NEXTDNS_ID=abcdef \
    NEXTDNS_VERSION=1.45.0

# Install runtime dependencies
RUN set -ex && \
    # Add NextDNS repository
    wget -qO /etc/apk/keys/nextdns.pub https://repo.nextdns.io/nextdns.pub && \
    echo "https://repo.nextdns.io/apk" >> /etc/apk/repositories && \
    # Update and install packages with specific version
    apk update && \
    apk --no-cache add \
        nextdns=${NEXTDNS_VERSION} \
        ca-certificates \
        tini && \
    # Create necessary directories
    mkdir -p /etc/dnsmasq.d && \
    mkdir -p /usr/local/share/man/man8 && \
    # Cleanup
    rm -rf /var/cache/apk/* /tmp/* && \
    # Verify NextDNS installation
    nextdns version

# Copy dnsmasq binary and man pages from builder
COPY --from=builder /usr/local/sbin/dnsmasq /usr/local/sbin/
COPY --from=builder /usr/local/share/man/man8/dnsmasq.8 /usr/local/share/man/man8/

# Copy configurations
COPY dnsmasq.conf /etc/dnsmasq.conf
COPY --chmod=755 startup.sh /startup.sh

# Expose DNS ports
EXPOSE 53/tcp 53/udp

# More efficient health check - use nc for faster response
HEALTHCHECK --interval=60s --timeout=2s --start-period=5s --retries=3 \
    CMD nc -zu localhost 53 || exit 1

# Use tini as init with proper signal handling
ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["/startup.sh"]
