#!/bin/bash
set -e

cd /root/Lungo

BEFORE=$(git rev-parse HEAD)
git fetch origin main
AFTER=$(git rev-parse origin/main)

if [ "$BEFORE" = "$AFTER" ]; then
  exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Update terdeteksi: $BEFORE -> $AFTER"

git reset --hard origin/main

cd /root/Lungo/backend
npm install
npm run build

systemctl restart lungo-backend

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Deploy selesai."
