#!/bin/bash
# Script instalasi tema Stellar untuk Pterodactyl
# Dijalankan dengan: curl -sL https://raw.githubusercontent.com/username/repo/main/installer.sh | bash

# Warna output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Memulai instalasi tema Stellar...${NC}"

# Cek root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Script ini harus dijalankan sebagai root!${NC}"
   exit 1
fi

# Cek direktori Pterodactyl
if [ ! -d "/var/www/pterodactyl" ]; then
    echo -e "${RED}Direktori /var/www/pterodactyl tidak ditemukan!${NC}"
    echo -e "${YELLOW}Pastikan Pterodactyl sudah terinstall di server ini.${NC}"
    exit 1
fi

# Install dependencies jika perlu
echo -e "${YELLOW}Memeriksa dependencies...${NC}"
apt update -qq
apt install -y curl wget unzip zip -qq

# Backup sebelum instalasi
BACKUP_DIR="/root/backup-pterodactyl-$(date +%Y%m%d-%H%M%S)"
echo -e "${YELLOW}Membuat backup di $BACKUP_DIR...${NC}"
cp -r /var/www/pterodactyl $BACKUP_DIR

# Download tema
echo -e "${YELLOW}Mendownload tema Stellar...${NC}"
cd /tmp
wget -q -O stellar.zip https://raw.githubusercontent.com/LevviCodeID/Ptero/refs/heads/main/Tema/stellar.zip

if [ $? -ne 0 ]; then
    echo -e "${RED}Gagal mendownload tema! Periksa koneksi internet.${NC}"
    exit 1
fi

# Ekstrak
echo -e "${YELLOW}Mengekstrak file...${NC}"
unzip -q -o stellar.zip -d stellar_temp
if [ $? -ne 0 ]; then
    echo -e "${RED}Gagal mengekstrak file zip!${NC}"
    exit 1
fi

# Pindah ke direktori pterodactyl
cd /var/www/pterodactyl

# Backup .env
cp .env .env.backup

# Hapus cache
echo -e "${YELLOW}Membersihkan cache...${NC}"
php artisan view:clear
php artisan config:clear

# Copy file tema (asumsi struktur zip sesuai standar: public & resources)
echo -e "${YELLOW}Memindahkan file tema...${NC}"
cp -r /tmp/stellar_temp/* /var/www/pterodactyl/

# Set permission
echo -e "${YELLOW}Mengatur permission...${NC}"
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl/storage
chmod -R 755 /var/www/pterodactyl/bootstrap/cache

# Optimasi
echo -e "${YELLOW}Optimasi cache...${NC}"
php artisan optimize
php artisan view:cache

# Bersihkan temporary files
rm -rf /tmp/stellar.zip /tmp/stellar_temp

echo -e "${GREEN}✅ Instalasi tema Stellar selesai!${NC}"
echo -e "${GREEN}Silakan cek panel Anda: http://$(curl -s ifconfig.me)${NC}"
