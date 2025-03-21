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

# Function to start NextDNS
start_nextdns() {
    echo "Starting NextDNS with config ${NEXTDNS_ID}..."
    nextdns run ${NEXTDNS_ARGUMENTS} -config ${NEXTDNS_ID} &
    NEXTDNS_PID=$!
    echo "NextDNS started with PID: $NEXTDNS_PID"
}

# Function to start dnsmasq
start_dnsmasq() {
    echo "Starting dnsmasq..."
    # Run dnsmasq
    dnsmasq -k &
    DNSMASQ_PID=$!
    echo "dnsmasq started with PID: $DNSMASQ_PID"
}

# Initial service start
echo "Starting DNS services as root user..."
start_nextdns
start_dnsmasq

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

    # Adaptive sleep - use higher interval for better CPU efficiency
    sleep 20
done
