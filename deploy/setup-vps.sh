#!/bin/bash
set -e

echo "=== Update System ==="
apt update && apt upgrade -y

echo "=== Install Node.js 20 ==="
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

echo "=== Install PostgreSQL ==="
apt install -y postgresql postgresql-contrib
sudo -u postgres psql -c "CREATE DATABASE lungo_db;"
sudo -u postgres psql -c "CREATE USER lungo_user WITH PASSWORD 'LungoDB2025!';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE lungo_db TO lungo_user;"
sudo -u postgres psql -c "ALTER USER lungo_user CREATEDB;"

echo "=== Install Redis ==="
apt install -y redis-server
systemctl enable redis-server
systemctl start redis-server

echo "=== Install PM2 ==="
npm install -g pm2

echo "=== Install Nginx ==="
apt install -y nginx
systemctl enable nginx
systemctl start nginx

echo "=== Install Certbot SSL ==="
apt install -y certbot python3-certbot-nginx

echo "=== Install Git ==="
apt install -y git

echo "Setup selesai!"
