(() => {
  if (!document.getElementById("quarto-search")) return;
  const destinations = new WeakMap();
  let searchOverlay = null;

  const updateSearch = () => {
    const overlay = document.querySelector(".aa-DetachedOverlay");
    // Autocomplete removes the focused input with the overlay. Wait for pointer
    // dismissal to finish, and preserve focus if another control already has it.
    if (searchOverlay && !overlay) {
      requestAnimationFrame(() => {
        if (
          !document.querySelector(".aa-DetachedOverlay") &&
          document.activeElement === document.body
        ) {
          document
            .querySelector("#quarto-search .aa-DetachedSearchButton")
            ?.focus({ preventScroll: true });
        }
      });
    }
    searchOverlay = overlay;

    for (const panel of document.querySelectorAll(".aa-Panel")) {
      panel.tabIndex = 0;
    }
    // Autocomplete owns the option semantics and keyboard navigation. A link
    // inside an option is still focusable even with a negative tabindex.
    for (const link of document.querySelectorAll('.aa-Item[role="option"] a[href]')) {
      destinations.set(link, link.href);
      link.removeAttribute("href");
    }
  };

  const navigate = (event) => {
    if (event.button > 1) return;
    const link = event.target.closest("a");
    const destination = destinations.get(link);
    if (!destination) return;
    event.preventDefault();
    // The input's Enter handler still uses Autocomplete's navigator. Restore
    // pointer navigation, including modified clicks, for the placeholder link.
    if (event.button === 1 || event.ctrlKey || event.metaKey || event.shiftKey) {
      window.open(destination, "_blank", "noopener");
    } else {
      window.location.assign(destination);
    }
  };

  document.body.addEventListener("click", navigate);
  document.body.addEventListener("auxclick", navigate);
  updateSearch();
  // Overlay searches render outside #quarto-search-results, and Autocomplete
  // recreates the panel when readers reopen search or change its query.
  new MutationObserver(updateSearch).observe(document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["href"],
  });
})();
