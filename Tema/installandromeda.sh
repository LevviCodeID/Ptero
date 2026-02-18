#!/usr/bin/env bash
set -e

# ======================================================
# ANDROMEDA THEME INSTALLER
# Dev : LevviCode
# TELE: https://t.me/lepicode
# ======================================================

THEME_DIR="/var/www/pterodactyl/public/themes/andromeda"
BACKUP_DIR="/var/www/pterodactyl/storage/backups/andromeda"
ADMIN="/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
MASTER="/var/www/pterodactyl/resources/views/layouts/master.blade.php"

CSS_URL="https://raw.githubusercontent.com/LevviCodeID/Ptero/refs/heads/main/Tema/andromeda.css"
JS_URL="https://raw.githubusercontent.com/LevviCodeID/Ptero/refs/heads/main/Tema/andromeda.js"

echo ""
echo "📌 Installing Andromeda Theme..."
echo ""

# create directories
mkdir -p "$THEME_DIR"
mkdir -p "$BACKUP_DIR"

# backup layouts
echo "🗂 Backing up layout files..."
cp "$ADMIN" "$BACKUP_DIR/admin.blade.php.bak" || true
cp "$MASTER" "$BACKUP_DIR/master.blade.php.bak" || true

# download CSS
echo "🎨 Downloading andromeda.css..."
curl -s "$CSS_URL" -o "$THEME_DIR/andromeda.css"

# download JS
echo "🧠 Downloading andromeda.js..."
curl -s "$JS_URL" -o "$THEME_DIR/andromeda.js"

# inject into Blade
inject_theme() {
 local file="$1"
 if ! grep -q "andromeda.css" "$file"; then
   echo "🔗 Injecting CSS into $file"
   sed -i "/<head>/a \\
<link rel=\\"stylesheet\\" href=\\"https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css\\">\\
<link rel=\\"stylesheet\\" href=\\"{{ asset('themes/andromeda/andromeda.css') }}\\">" "$file"
 fi

 if ! grep -q "andromeda.js" "$file"; then
   echo "🔗 Injecting JS into $file"
   sed -i "/<\\/body>/i \\
<script src=\\"{{ asset('themes/andromeda/andromeda.js') }}\\"></script>" "$file"
 fi
}

inject_theme "$ADMIN"
inject_theme "$MASTER"

# clear Laravel views/caches
echo "🧹 Clearing Pterodactyl cache..."
cd /var/www/pterodactyl
php artisan view:clear
php artisan cache:clear

echo ""
echo "✅ Andromeda Theme Installed!"
echo "📌 Backup stored in: $BACKUP_DIR"
echo ""
