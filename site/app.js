// Cambio de idioma: el contenido de ambos idiomas ya está en la página; aquí solo se elige cuál mostrar.
const root = document.documentElement;

function setLang(lang) {
  root.lang = lang;
  try { localStorage.setItem('lang', lang); } catch (e) { /* modo privado: no se recuerda, pero funciona */ }
  document.querySelectorAll('[data-set-lang]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.setLang === lang)));
}

document.querySelectorAll('[data-set-lang]').forEach((b) => b.addEventListener('click', () => setLang(b.dataset.setLang)));
setLang(root.lang === 'en' ? 'en' : 'es');
