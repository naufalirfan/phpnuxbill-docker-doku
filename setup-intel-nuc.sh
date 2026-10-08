#!/usr/bin/env bash
# ==============================================================================
# Script Auto-Installer PHPNuxBill di Intel NUC (Debian 11/12 atau Ubuntu 22.04/24.04)
# ==============================================================================
set -e

echo "=== [1/5] Memperbarui Paket Sistem & Install Dependency ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx mariadb-server curl git unzip software-properties-common lsb-release ca-certificates apt-transport-https

# Pastikan PHP 8.2 & Ekstensi terinstall
echo "=== [2/5] Memasang PHP 8.2 dan Ekstensi Pendukung ==="
sudo apt install -y php-fpm php-cli php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bcmath

PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
echo "PHP Version terdeteksi: $PHP_VER"

echo "=== [3/5] Membuat Database MariaDB ==="
DB_NAME="nuxbill_db"
DB_USER="nuxbill_user"
DB_PASS="NuxBillSecure2026!"

sudo mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "=== [4/5] Mengunduh PHPNuxBill Terbaru ==="
sudo rm -rf /var/www/phpnuxbill
sudo git clone https://github.com/hotspotbilling/phpnuxbill.git /var/www/phpnuxbill

# Salin plugin DOKU jika ada di folder kerja
if [ -f "./doku.php" ]; then
    sudo cp ./doku.php /var/www/phpnuxbill/system/paymentgateway/doku.php
    sudo cp ./doku.php /var/www/phpnuxbill/system/plugin/doku.php 2>/dev/null || true
    echo "Plugin doku.php berhasil disalin!"
fi

if [ -f "./doku_config.tpl" ]; then
    sudo cp ./doku_config.tpl /var/www/phpnuxbill/ui/ui/doku_config.tpl
    echo "Template doku_config.tpl berhasil disalin!"
fi

sudo chown -R www-data:www-data /var/www/phpnuxbill
sudo chmod -R 755 /var/www/phpnuxbill
sudo chmod -R 777 /var/www/phpnuxbill/system/cache /var/www/phpnuxbill/system/uploads 2>/dev/null || true

echo "=== [5/5] Konfigurasi Nginx Web Server ==="
sudo tee /etc/nginx/sites-available/phpnuxbill << 'NGINX_CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/phpnuxbill;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINX_CONF

# Link socket php-fpm sesuai versi
PHP_SOCK="/var/run/php/php${PHP_VER}-fpm.sock"
if [ -S "$PHP_SOCK" ]; then
    sudo sed -i "s|/var/run/php/php-fpm.sock|$PHP_SOCK|g" /etc/nginx/sites-available/phpnuxbill
fi

sudo ln -sf /etc/nginx/sites-available/phpnuxbill /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl restart php${PHP_VER}-fpm mariadb

# Setup Cron Job PHPNuxBill
CRON_JOB="* * * * * php /var/www/phpnuxbill/index.php cron/run >/dev/null 2>&1"
(crontab -l 2>/dev/null | grep -Fv "phpnuxbill/index.php" ; echo "$CRON_JOB") | crontab -

echo "=================================================================="
echo "🎉 Instalasi PHPNuxBill di Intel NUC Selesai!"
echo "Akses web browser di: http://$(hostname -I | awk '{print $1}')"
echo "Database: ${DB_NAME} | User: ${DB_USER} | Pass: ${DB_PASS}"
echo "=================================================================="
