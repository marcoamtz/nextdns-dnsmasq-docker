#!/bin/sh
set -e  # Exit on error

# Trap cleanup on signal
cleanup() {
    echo "Cleaning up processes..."
    if [ -n "$NEXTDNS_PID" ]; then
        kill $NEXTDNS_PID 2>/dev/null || true
    fi
    if [ -n "$DNSMASQ_PID" ]; then
        kill $DNSMASQ_PID 2>/dev/null || true
    fi
    if [ -n "$LOGROTATE_PID" ]; then
        kill $LOGROTATE_PID 2>/dev/null || true
    fi
    exit 0
}

# Set up trap for common signals
trap cleanup INT TERM QUIT

# Validate environment variables
if [ -z "${NEXTDNS_ID}" ]; then
    echo "Error: NEXTDNS_ID not set"
    exit 1
fi

# Set permissions on volume directories
chown dnsmasq:dnsmasq "${LOG_DIR}" /dhcp-leases
chmod 755 "${LOG_DIR}" /dhcp-leases

# Create logrotate configuration
/create-logrotate-conf.sh

# Function to start NextDNS
start_nextdns() {
    NEXTDNS_VERSION=$(nextdns version 2>/dev/null | awk '{print $NF}' || echo "unknown")
    echo "Starting NextDNS version ${NEXTDNS_VERSION}..."
    su-exec dnsmasq nextdns run ${NEXTDNS_ARGUMENTS} -log-queries -config ${NEXTDNS_ID} > "${LOG_DIR}/nextdns.log" 2>&1 &
    NEXTDNS_PID=$!
    echo "NextDNS started with PID: $NEXTDNS_PID"
}

# Function to start dnsmasq
start_dnsmasq() {
    DNSMASQ_VERSION=$(dnsmasq --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
    echo "Starting dnsmasq version ${DNSMASQ_VERSION}..."
    dnsmasq -k --log-facility="${LOG_DIR}/dnsmasq.log" &
    DNSMASQ_PID=$!
    echo "dnsmasq started with PID: $DNSMASQ_PID"
}

# Function to rotate logs periodically
start_logrotate() {
    (
        while true; do
            # Run logrotate every 15 minutes
            sleep 900
            logrotate /etc/logrotate.d/dns-logs
        done
    ) &
    LOGROTATE_PID=$!
    echo "Log rotation started with PID: $LOGROTATE_PID"
}

# Initial service start
echo "Starting DNS services with privilege separation..."
start_nextdns
start_dnsmasq
start_logrotate

# Monitor and restart processes with improved reliability
echo "Monitoring services..."
while true; do
    # Check NextDNS
    if ! kill -0 $NEXTDNS_PID 2>/dev/null; then
        echo "$(date): NextDNS process died, restarting..."
        start_nextdns
    fi

    # Check dnsmasq
    if ! kill -0 $DNSMASQ_PID 2>/dev/null; then
        echo "$(date): dnsmasq process died, restarting..."
        start_dnsmasq
    fi

    # Check logrotate
    if ! kill -0 $LOGROTATE_PID 2>/dev/null; then
        echo "$(date): Log rotation process died, restarting..."
        start_logrotate
    fi

    # Adaptive sleep - use higher interval for better CPU efficiency
    sleep 20
done
