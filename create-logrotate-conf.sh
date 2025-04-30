#!/bin/sh
# Create proper logrotate configuration using environment variables

# Ensure LOG_DIR is set
: "${LOG_DIR:=/logs}"

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
