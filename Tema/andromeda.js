/* ======================================================
   ANDROMEDA THEME JS
   Dev  : LevviCode
====================================================== */

(() => {
  const STORAGE_KEY = 'andromeda-theme'

  const enableDark = () => {
    document.body.classList.add('dark')
    localStorage.setItem(STORAGE_KEY, 'dark')
  }

  const disableDark = () => {
    document.body.classList.remove('dark')
    localStorage.setItem(STORAGE_KEY, 'light')
  }

  // Load theme
  if (localStorage.getItem(STORAGE_KEY) === 'dark') {
    enableDark()
  }

  // Toggle global
  window.toggleAndromeda = () => {
    document.body.classList.contains('dark')
      ? disableDark()
      : enableDark()
  }

  // Auto button if not exist
  document.addEventListener('DOMContentLoaded', () => {
    if (!document.querySelector('.andromeda-toggle')) {
      const btn = document.createElement('div')
      btn.className = 'andromeda-toggle'
      btn.innerHTML = '<i class="fa-solid fa-moon"></i>'
      btn.onclick = toggleAndromeda
      document.body.appendChild(btn)
    }
  })
})()
