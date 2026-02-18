#!/bin/bash

IP="$1"
PASSWORD="$2"

if [ -z "$IP" ] || [ -z "$PASSWORD" ]; then
    echo "Parameter kurang!"
    exit 1
fi

sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@$IP << 'EOF'

PANEL_DIR="/var/www/pterodactyl"
TMP_DIR="/tmp/stellar_install"
ZIP_URL="https://raw.githubusercontent.com/LevviCodeID/Ptero/refs/heads/main/Tema/stellar.zip"

echo "=== START INSTALL STELLAR THEME ==="

if [ ! -d "$PANEL_DIR" ]; then
    echo "PANEL_NOT_FOUND"
    exit 1
fi

rm -rf $TMP_DIR
mkdir -p $TMP_DIR

echo "Downloading stellar.zip..."
curl -sL $ZIP_URL -o $TMP_DIR/stellar.zip || { echo "DOWNLOAD_FAILED"; exit 1; }

echo "Extracting..."
unzip -o $TMP_DIR/stellar.zip -d $TMP_DIR || { echo "UNZIP_FAILED"; exit 1; }

if [ ! -d "$TMP_DIR/pterodactyl" ]; then
    echo "ZIP_STRUCTURE_INVALID"
    exit 1
fi

echo "Backing up panel..."
cp -r $PANEL_DIR ${PANEL_DIR}_backup_$(date +%Y%m%d%H%M%S)

echo "Copy theme files..."
cp -r $TMP_DIR/pterodactyl/* $PANEL_DIR/

cd $PANEL_DIR || { echo "CD_FAIL"; exit 1; }

echo "Installing dependencies (composer)..."
composer install --no-dev --optimize-autoloader

echo "Running Laravel migrations..."
php artisan migrate --force

echo "Building assets..."
npm install --silent
npm run build

echo "Clearing caches..."
php artisan view:clear
php artisan cache:clear
php artisan config:clear

echo "Fixing permissions..."
chown -R www-data:www-data $PANEL_DIR
chmod -R 755 storage bootstrap/cache

echo "Restarting services..."
systemctl restart nginx
systemctl restart php8.1-fpm

echo "STELLAR_INSTALL_SUCCESS"

EOF
