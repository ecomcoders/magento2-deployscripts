#!/usr/bin/env bash
set -euo pipefail

echo -e 'Subject: Update Manager Report\n\n'
cat /var/lib/update-notifier/updates-available
LAST_UPDATES=$(date -r /var/lib/update-notifier/updates-available)
echo "Last updated: $LAST_UPDATES"

apt list --upgradable
