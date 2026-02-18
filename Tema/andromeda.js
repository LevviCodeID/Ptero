// andromeda.js
(function() {
    'use strict';

    // Dark mode initialization
    const initDarkMode = () => {
        const darkMode = localStorage.getItem('theme') === 'dark' || 
                        (!localStorage.getItem('theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
        if (darkMode) {
            document.body.classList.add('dark');
        } else {
            document.body.classList.remove('dark');
        }
    };

    // Add theme toggle button to navbar
    const addThemeToggle = () => {
        // Cari tempat untuk menaruh toggle (misal di pojok kanan navbar)
        const navbar = document.querySelector('.navbar-nav.ml-auto');
        if (navbar) {
            const toggleLi = document.createElement('li');
            toggleLi.className = 'nav-item';
            toggleLi.innerHTML = `
                <button id="theme-toggle" class="theme-toggle">
                    <i class="fas fa-moon dark:hidden"></i>
                    <i class="fas fa-sun hidden dark:inline"></i>
                </button>
            `;
            navbar.appendChild(toggleLi);
        } else {
            // Fallback: tambahkan di pojok kanan atas body
            const toggleDiv = document.createElement('div');
            toggleDiv.className = 'fixed top-4 right-4 z-50';
            toggleDiv.innerHTML = `
                <button id="theme-toggle" class="theme-toggle">
                    <i class="fas fa-moon dark:hidden"></i>
                    <i class="fas fa-sun hidden dark:inline"></i>
                </button>
            `;
            document.body.appendChild(toggleDiv);
        }

        // Event listener
        const toggleBtn = document.getElementById('theme-toggle');
        if (toggleBtn) {
            toggleBtn.addEventListener('click', () => {
                document.body.classList.toggle('dark');
                const theme = document.body.classList.contains('dark') ? 'dark' : 'light';
                localStorage.setItem('theme', theme);
            });
        }
    };

    // Ubah beberapa elemen agar lebih modern (misal: tambahkan class ke card)
    const enhanceElements = () => {
        // Tambahkan class 'card' ke elemen yang biasanya menjadi panel
        document.querySelectorAll('.panel, .box').forEach(el => {
            el.classList.add('card');
        });

        // Ubah progress bar standar
        document.querySelectorAll('.progress').forEach(el => {
            el.classList.add('progress-sm');
        });

        // Ubah badge
        document.querySelectorAll('.label').forEach(el => {
            el.classList.add('badge');
        });

        // Tambahkan icon ke tombol jika belum ada
        document.querySelectorAll('.btn-primary').forEach(btn => {
            if (!btn.querySelector('.fas, .far')) {
                btn.innerHTML = '<i class="fas fa-check mr-2"></i>' + btn.innerHTML;
            }
        });
    };

    // Jalankan setelah DOM siap
    document.addEventListener('DOMContentLoaded', () => {
        initDarkMode();
        addThemeToggle();
        enhanceElements();
    });
})();
