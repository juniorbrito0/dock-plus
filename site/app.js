/* Dock+: progressive enhancement only. The site is fully usable without this file. */
(function () {
  "use strict";

  // ---- theme toggle (persists choice; default = dark) ----
  var root = document.documentElement;
  try {
    var saved = localStorage.getItem("dockplus-theme");
    if (saved) root.setAttribute("data-theme", saved);
  } catch (e) {}

  var toggle = document.querySelector(".theme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "light" ? "dark" : "light";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem("dockplus-theme", next); } catch (e) {}
    });
  }

  // ---- scroll reveal ----
  var els = document.querySelectorAll("[data-reveal]");
  if (!els.length) return;
  root.classList.add("reveal-ready");

  if (!("IntersectionObserver" in window)) {
    els.forEach(function (el) { el.classList.add("in"); });
    return;
  }

  var io = new IntersectionObserver(
    function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("in");
          io.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
  );
  els.forEach(function (el) { io.observe(el); });
})();
