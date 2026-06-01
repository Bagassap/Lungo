#!/bin/bash
set -e

APP_DIR="/var/www/lungo-backend"
echo "=== Deploy Lungo Backend ==="

if [ -d "$APP_DIR" ]; then
  cd $APP_DIR
  git pull origin main
else
  git clone https://github.com/YOUR_REPO/lungo.git $APP_DIR
  cd $APP_DIR
fi

cd $APP_DIR/backend
npm install
npm run build

pm2 stop lungo-backend || true
pm2 delete lungo-backend || true
pm2 start dist/main.js --name lungo-backend
pm2 save
pm2 startup

echo "Deploy selesai!"
