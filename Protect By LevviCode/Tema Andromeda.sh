#!/bin/bash

echo "🚀 Memasang Tema Andromeda untuk Pterodactyl..."

PTERO_PATH="/var/www/pterodactyl"
THEME_PATH="$PTERO_PATH/public/themes/andromeda"

mkdir -p "$THEME_PATH"

# ==================== CSS ====================
cat > "$THEME_PATH/andromeda.css" <<'EOF'
:root {
    --primary: #3b82f6;
    --primary-light: #60a5fa;
    --primary-dark: #2563eb;
    --bg-light: #f9fafb;
    --bg-dark: #111827;
    --surface-light: #ffffff;
    --surface-dark: #1f2937;
    --text-light: #1f2937;
    --text-dark: #f3f4f6;
    --border-light: #e5e7eb;
    --border-dark: #374151;
}
body.dark {
    background-color: var(--bg-dark);
    color: var(--text-dark);
}
body.dark .card,
body.dark .box,
body.dark .panel {
    background-color: var(--surface-dark);
    border-color: var(--border-dark);
}
.btn-andromeda {
    background: linear-gradient(135deg, var(--primary), var(--primary-dark));
    color: white;
    padding: 0.5rem 1.25rem;
    border-radius: 0.75rem;
    font-weight: 600;
    transition: all 0.2s;
    border: none;
    box-shadow: 0 4px 6px -1px rgba(59, 130, 246, 0.3);
}
.btn-andromeda:hover {
    transform: translateY(-2px);
    box-shadow: 0 10px 15px -3px rgba(59, 130, 246, 0.4);
}
.navbar-andromeda {
    background: linear-gradient(135deg, #1e293b, #0f172a);
    color: white;
    border-bottom: 1px solid #334155;
}
body.dark .navbar-andromeda {
    background: #0f172a;
    border-bottom-color: #1e293b;
}
.sidebar-andromeda {
    background: var(--surface-light);
    border-right: 1px solid var(--border-light);
}
body.dark .sidebar-andromeda {
    background: var(--surface-dark);
    border-right-color: var(--border-dark);
}
.stat-card {
    background: linear-gradient(135deg, #3b82f6, #8b5cf6);
    color: white;
    border-radius: 1rem;
    padding: 1.5rem;
    box-shadow: 0 20px 25px -5px rgba(59, 130, 246, 0.2);
}
.theme-toggle {
    background: rgba(255,255,255,0.2);
    border: 1px solid rgba(255,255,255,0.3);
    border-radius: 9999px;
    padding: 0.5rem;
    cursor: pointer;
    transition: all 0.2s;
}
.theme-toggle:hover {
    background: rgba(255,255,255,0.3);
}
EOF

# ==================== JavaScript ====================
cat > "$THEME_PATH/andromeda.js" <<'EOF'
document.addEventListener('DOMContentLoaded', function() {
    // Dark mode initialization
    const darkMode = localStorage.getItem('theme') === 'dark' || 
                    (!localStorage.getItem('theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
    if (darkMode) {
        document.body.classList.add('dark');
    }

    // Toggle button
    const toggleBtn = document.getElementById('theme-toggle');
    if (toggleBtn) {
        toggleBtn.addEventListener('click', function() {
            document.body.classList.toggle('dark');
            localStorage.setItem('theme', document.body.classList.contains('dark') ? 'dark' : 'light');
        });
    }

    // Add smooth scrolling
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            document.querySelector(this.getAttribute('href')).scrollIntoView({ behavior: 'smooth' });
        });
    });
});
EOF

echo "✅ File tema dibuat."

# ==================== Backup ====================
BACKUP_DIR="$PTERO_PATH/storage/backups/andromeda-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# ==================== Modify Layouts ====================
# Admin layout
if [ -f "$PTERO_PATH/resources/views/layouts/admin.blade.php" ]; then
    cp "$PTERO_PATH/resources/views/layouts/admin.blade.php" "$BACKUP_DIR/admin.blade.php"
    
    # Add head includes
    sed -i '/<\/head>/i \
    <!-- Tailwind CSS -->\
    <script src="https:\/\/cdn.tailwindcss.com"><\/script>\
    <!-- FontAwesome -->\
    <link rel="stylesheet" href="https:\/\/cdnjs.cloudflare.com\/ajax\/libs\/font-awesome\/6.0.0-beta3\/css\/all.min.css">\
    <!-- Andromeda Theme -->\
    <link rel="stylesheet" href="{{ asset(\'themes\/andromeda\/andromeda.css\') }}">' "$PTERO_PATH/resources/views/layouts/admin.blade.php"
    
    # Add JS before closing body
    sed -i '/<\/body>/i \
    <script src="{{ asset(\'themes\/andromeda\/andromeda.js\') }}"><\/script>' "$PTERO_PATH/resources/views/layouts/admin.blade.php"
    
    # Add theme toggle button (search for navbar-nav or similar)
    if grep -q "navbar-nav ml-auto" "$PTERO_PATH/resources/views/layouts/admin.blade.php"; then
        sed -i '/navbar-nav ml-auto/a \
            <li class="nav-item">\
                <button id="theme-toggle" class="theme-toggle">\
                    <i class="fas fa-moon dark:hidden text-gray-200"></i>\
                    <i class="fas fa-sun hidden dark:inline text-yellow-300"></i>\
                </button>\
            </li>' "$PTERO_PATH/resources/views/layouts/admin.blade.php"
    else
        # Fallback: add to top bar
        sed -i '/<body/a \
    <div class="absolute top-4 right-4 z-50">\
        <button id="theme-toggle" class="theme-toggle">\
            <i class="fas fa-moon dark:hidden text-gray-800 dark:text-gray-200"></i>\
            <i class="fas fa-sun hidden dark:inline text-yellow-300"></i>\
        </button>\
    </div>' "$PTERO_PATH/resources/views/layouts/admin.blade.php"
    fi
    
    echo "✅ Admin layout modified."
fi

# Master layout
if [ -f "$PTERO_PATH/resources/views/layouts/master.blade.php" ]; then
    cp "$PTERO_PATH/resources/views/layouts/master.blade.php" "$BACKUP_DIR/master.blade.php"
    
    sed -i '/<\/head>/i \
    <!-- Tailwind CSS -->\
    <script src="https:\/\/cdn.tailwindcss.com"><\/script>\
    <!-- FontAwesome -->\
    <link rel="stylesheet" href="https:\/\/cdnjs.cloudflare.com\/ajax\/libs\/font-awesome\/6.0.0-beta3\/css\/all.min.css">\
    <!-- Andromeda Theme -->\
    <link rel="stylesheet" href="{{ asset(\'themes\/andromeda\/andromeda.css\') }}">' "$PTERO_PATH/resources/views/layouts/master.blade.php"
    
    sed -i '/<\/body>/i \
    <script src="{{ asset(\'themes\/andromeda\/andromeda.js\') }}"><\/script>' "$PTERO_PATH/resources/views/layouts/master.blade.php"
    
    echo "✅ Master layout modified."
fi

# ==================== Clear Cache ====================
cd "$PTERO_PATH"
php artisan view:clear
php artisan cache:clear

echo ""
echo "🎉 Tema Andromeda berhasil dipasang!"
echo "📁 Backup disimpan di: $BACKUP_DIR"
echo "🌙 Dark mode dapat di-toggle dengan tombol bulan/matahari di pojok kanan atas."
echo "© Protect By LevviCode t.me/lepicode"
