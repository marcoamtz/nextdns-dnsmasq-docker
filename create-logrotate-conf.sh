#!/bin/sh
set -e  # Exit on error

# Create proper logrotate configuration using environment variables

# Ensure LOG_DIR is set
: "${LOG_DIR:=/logs}"

# Ensure logrotate directory exists
mkdir -p /etc/logrotate.d

# Create logrotate config
cat > /etc/logrotate.d/dns-logs << EOF
${LOG_DIR}/nextdns.log ${LOG_DIR}/dnsmasq.log {
    size 10M
    rotate 3
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
}
EOF

echo "Created logrotate configuration for ${LOG_DIR}/nextdns.log and ${LOG_DIR}/dnsmasq.log"
