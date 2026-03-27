#!/bin/bash

# Script to update VM_IP in all configuration files
# Usage: ./update_ip.sh <new_ip>

if [ -z "$1" ]; then
    echo "Usage: ./update_ip.sh <new_ip>"
    echo "Example: ./update_ip.sh 192.168.2.15"
    exit 1
fi

NEW_IP=$1

echo "Updating VM_IP to $NEW_IP..."

# Update .env file
sed -i '' "s/^VM_IP=.*/VM_IP=$NEW_IP/" .env
echo "✓ Updated .env"

# Update extra_hosts in docker-compose.monitoring.yml
sed -i '' "s/- \"vm:.*\"/- \"vm:$NEW_IP\"/" docker-compose.monitoring.yml
echo "✓ Updated docker-compose.monitoring.yml"

echo ""
echo "Restart the containers to apply changes:"
echo "  docker-compose -f docker-compose.monitoring.yml down && docker-compose -f docker-compose.monitoring.yml up -d"