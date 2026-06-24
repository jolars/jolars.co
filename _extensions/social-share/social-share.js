(function () {
  "use strict";

  function shareUrl() {
    var canonical = document.querySelector('link[rel="canonical"]');
    return canonical && canonical.href ? canonical.href : window.location.href;
  }

  function shareTitle() {
    var og = document.querySelector('meta[property="og:title"]');
    return og && og.content ? og.content : document.title;
  }

  function openShare(url) {
    window.open(url, "_blank", "noopener,noreferrer");
  }

  function onBluesky(event) {
    event.preventDefault();
    var text = shareTitle() + " " + shareUrl();
    openShare("https://bsky.app/intent/compose?text=" + encodeURIComponent(text));
  }

  function onMastodon(event) {
    event.preventDefault();
    var stored = window.localStorage.getItem("social-share:mastodon-instance") || "";
    var instance = window.prompt(
      "Your Mastodon instance (e.g. mastodon.social):",
      stored
    );
    if (!instance) {
      return;
    }
    instance = instance.trim().replace(/^https?:\/\//, "").replace(/\/+$/, "");
    if (!instance) {
      return;
    }
    window.localStorage.setItem("social-share:mastodon-instance", instance);
    var text = shareTitle() + " " + shareUrl();
    openShare("https://" + instance + "/share?text=" + encodeURIComponent(text));
  }

  function onCopy(event) {
    var button = event.currentTarget;
    var url = shareUrl();
    var flash = function () {
      button.classList.add("is-copied");
      window.setTimeout(function () {
        button.classList.remove("is-copied");
      }, 1500);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(flash, function () {
        window.prompt("Copy this link:", url);
      });
    } else {
      window.prompt("Copy this link:", url);
    }
  }

  function init() {
    var handlers = {
      bluesky: onBluesky,
      mastodon: onMastodon,
      copy: onCopy,
    };
    document.querySelectorAll("[data-social-share]").forEach(function (el) {
      var handler = handlers[el.getAttribute("data-social-share")];
      if (handler) {
        el.addEventListener("click", handler);
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
