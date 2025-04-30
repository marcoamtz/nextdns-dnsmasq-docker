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

# Check for privileged ports access
if ! grep -q "53" /proc/sys/net/ipv4/ip_local_port_range 2>/dev/null; then
    echo "Note: Running with privileged port 53 access (root)"
fi

# Ensure log directory exists and create logrotate configuration
mkdir -p "${LOG_DIR}"
chmod 755 "${LOG_DIR}"
/create-logrotate-conf.sh

# Function to start NextDNS
start_nextdns() {
    echo "Starting NextDNS with config ${NEXTDNS_ID}..."
    nextdns run ${NEXTDNS_ARGUMENTS} -log-queries -config ${NEXTDNS_ID} > "${LOG_DIR}/nextdns.log" 2>&1 &
    NEXTDNS_PID=$!
    echo "NextDNS started with PID: $NEXTDNS_PID"
}

# Function to start dnsmasq
start_dnsmasq() {
    echo "Starting dnsmasq..."
    # Run dnsmasq with logging enabled
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
echo "Starting DNS services as root user..."
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
