document.addEventListener("DOMContentLoaded", () => {

  document.querySelectorAll(".card, .panel, table tbody tr").forEach(el => {
    el.style.transition = "all .25s ease"
    el.addEventListener("mouseenter", () => {
      el.style.transform = "translateY(-4px)"
      el.style.boxShadow = "0 20px 45px rgba(0,0,0,.15)"
    })
    el.addEventListener("mouseleave", () => {
      el.style.transform = "none"
      el.style.boxShadow = ""
    })
  })

})
