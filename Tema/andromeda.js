document.addEventListener("DOMContentLoaded", () => {
  document.body.classList.add("andromeda-active");

  document.querySelectorAll(
    "button,.btn,.button"
  ).forEach(b => b.classList.add("andromeda-btn"));

  if (!document.querySelector(".andromeda-toggle")) {
    const t = document.createElement("div");
    t.className = "andromeda-toggle";
    t.innerHTML = "🌙";
    document.body.appendChild(t);

    t.onclick = () => {
      document.body.classList.toggle("dark");
      localStorage.setItem(
        "andromeda-theme",
        document.body.classList.contains("dark") ? "dark" : "light"
      );
    };
  }

  if (localStorage.getItem("andromeda-theme") === "dark") {
    document.body.classList.add("dark");
  }
});
