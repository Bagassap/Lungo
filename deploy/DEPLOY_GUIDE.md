# Deploy Lungo ke VPS Hostinger

## Info VPS
- **IP:** 187.77.116.121
- **OS:** Ubuntu 22.04 LTS
- **User:** root

---

## 1. Koneksi ke VPS
```bash
ssh root@187.77.116.121
```

---

## 2. Setup VPS (pertama kali saja)
Upload script lalu jalankan:
```bash
scp deploy/setup-vps.sh root@187.77.116.121:/root/
ssh root@187.77.116.121 "bash /root/setup-vps.sh"
```

---

## 3. Upload kode backend
```bash
# Upload folder backend
scp -r backend/ root@187.77.116.121:/var/www/lungo-backend/

# Upload .env production
scp deploy/.env.production root@187.77.116.121:/var/www/lungo-backend/backend/.env

# Upload Firebase service account (jika ada)
scp deploy/firebase-service-account.json root@187.77.116.121:/var/www/lungo-backend/backend/
```

---

## 4. Di VPS — Install & Jalankan
```bash
ssh root@187.77.116.121

cd /var/www/lungo-backend/backend
npm install
npm run build
pm2 start dist/main.js --name lungo-backend
pm2 save
pm2 startup
```

---

## 5. Setup Nginx
```bash
scp deploy/nginx-lungo.conf root@187.77.116.121:/etc/nginx/sites-available/lungo

ssh root@187.77.116.121 "
  ln -sf /etc/nginx/sites-available/lungo /etc/nginx/sites-enabled/lungo
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
"
```

---

## 6. Test Koneksi
```bash
curl http://187.77.116.121/health
```
Response yang diharapkan:
```json
{"status":"ok","timestamp":"..."}
```

---

## 7. Update / Redeploy
Jika ada perubahan kode:
```bash
scp -r backend/ root@187.77.116.121:/var/www/lungo-backend/
ssh root@187.77.116.121 "
  cd /var/www/lungo-backend/backend
  npm install
  npm run build
  pm2 restart lungo-backend
"
```

---

## 8. Monitor & Logs
```bash
# Status aplikasi
pm2 status

# Log real-time
pm2 logs lungo-backend

# Log error saja
pm2 logs lungo-backend --err
```

---

## 9. Database Migration
```bash
ssh root@187.77.116.121 "
  cd /var/www/lungo-backend/backend
  npm run typeorm:run-migrations
"
```

---

## Troubleshooting

### Backend tidak jalan
```bash
pm2 logs lungo-backend --lines 50
```

### Nginx error
```bash
nginx -t
journalctl -u nginx --no-pager -n 50
```

### PostgreSQL tidak bisa connect
```bash
sudo -u postgres psql -c "\l"
sudo -u postgres psql lungo_db -c "\dt"
```

### Port 3000 tidak terbuka
```bash
ufw allow 3000
ufw allow 80
ufw allow 443
ufw allow 22
ufw enable
```
