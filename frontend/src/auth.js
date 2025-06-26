// src/auth.js – run once as early as possible (e.g. in main.jsx)
// ----------------------------------------------------------------------------
// This file parses the URL fragment returned by the Lambda callback and
// stores id/access tokens in localStorage so the SPA can authenticate calls.

export function bootstrapAuth() {
  const hash = window.location.hash.slice(1); // Remove the #
  
  // Handle the $ prefix that appears in the callback URL
  const cleanHash = hash.startsWith('$') ? hash.slice(1) : hash;
  
  const params = new URLSearchParams(cleanHash);

  const id = params.get("id_token");
  const access = params.get("access_token");

  if (id && access) {
    localStorage.setItem("id_token", id);
    localStorage.setItem("access_token", access);
    // Clean the fragment from the URL so refreshes don't re‑parse it.
    history.replaceState({}, document.title, window.location.pathname + window.location.search);
  }
} 