// build-html-deck.mjs
// Reads slides/content/<lang>/deck.yaml for both 'en' and 'fr', renders a
// hand-rolled HTML deck mirroring the gh-advsec-devsecops skeleton (sticky
// nav.toc, <section id="secN"> with ═ ASCII banner comments, .lang-switcher
// with relative hrefs, Mermaid v11 CDN), and writes:
//
//   docs/app-insights-dotnet.html      (en)
//   docs/app-insights-dotnet-fr.html   (fr)

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import yaml from 'js-yaml';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, '..', '..');

const LANGS = ['en', 'fr'];
const OUT_FILES = {
  en: join(ROOT, 'docs', 'app-insights-dotnet.html'),
  fr: join(ROOT, 'docs', 'app-insights-dotnet-fr.html'),
};
const THEME_CSS = join(ROOT, 'slides', 'theme', 'deck.css');
const CSS = existsSync(THEME_CSS) ? readFileSync(THEME_CSS, 'utf8') : '';

const TEXT = {
  en: {
    htmlLang: 'en',
    badge: 'Observability — .NET 10 on Azure',
    metaLine: ['📅 2026', '👤 Microsoft Canada', '🏢 MAPAQ Workshop'],
    footer: 'Application Insights for .NET 10 — bilingual workshop · Microsoft Canada',
    contentsLabel: 'Contents',
  },
  fr: {
    htmlLang: 'fr',
    badge: 'Observabilité — .NET 10 sur Azure',
    metaLine: ['📅 2026', '👤 Microsoft Canada', '🏢 Atelier MAPAQ'],
    footer: 'Application Insights pour .NET 10 — atelier bilingue · Microsoft Canada',
    contentsLabel: 'Sommaire',
  },
};

const escapeHtml = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
}[c]));

function pad(n) { return String(n).padStart(2, '0'); }

function banner(num, key, title) {
  // ASCII banner comment for grep-ability inside the rendered HTML, mirrors
  // the gh-advsec-devsecops convention.
  const line = '═'.repeat(72);
  return `\n<!-- ${line}\n     SECTION ${pad(num)} · ${key} · ${title}\n     ${line} -->\n`;
}

function renderBullets(bullets) {
  if (!Array.isArray(bullets) || bullets.length === 0) return '';
  const items = bullets.map((b) => `      <li>${escapeHtml(b)}</li>`).join('\n');
  return `\n    <ul>\n${items}\n    </ul>`;
}

function renderMermaid(mermaidSource) {
  if (!mermaidSource) return '';
  // Render the source verbatim inside <pre class="mermaid"> so the in-browser
  // Mermaid v11 CDN script picks it up at startOnLoad: true.
  return `\n    <div class="mermaid-wrapper">\n      <pre class="mermaid">\n${mermaidSource.trimEnd()}\n      </pre>\n    </div>`;
}

function renderImage(image, altText) {
  if (!image) return '';
  return `\n    <div class="mermaid-wrapper">\n      <img src="${escapeHtml(image)}" alt="${escapeHtml(altText || '')}" style="max-width:100%;height:auto;" />\n    </div>`;
}

function renderNotes(notes) {
  if (!notes) return '';
  return `\n    <p class="notes">${escapeHtml(notes)}</p>`;
}

function renderSection(slide, idx) {
  const num = idx + 1;
  const sectionId = `sec${num}`;
  const titleEsc = escapeHtml(slide.title || slide.key || `Slide ${num}`);
  const body =
    renderBullets(slide.bullets) +
    renderMermaid(slide.mermaid) +
    renderImage(slide.image, slide.title) +
    renderNotes(slide.notes);

  return `${banner(num, slide.key || `slide-${num}`, slide.title || '')}<section id="${sectionId}" data-key="${escapeHtml(slide.key || '')}">
    <h2><span class="section-num">${pad(num)}</span> ${titleEsc}</h2>${body}
  </section>`;
}

function renderToc(slides, contentsLabel) {
  const links = slides
    .map((s, i) => `      <a href="#sec${i + 1}">${escapeHtml(s.title || s.key || `Slide ${i + 1}`)}</a>`)
    .join('\n');
  return `<nav class="toc" aria-label="${escapeHtml(contentsLabel)}">
    <div class="toc-inner">
${links}
    </div>
  </nav>`;
}

function renderLangSwitcher(currentLang) {
  const enHref = 'app-insights-dotnet.html';
  const frHref = 'app-insights-dotnet-fr.html';
  const enClass = currentLang === 'en' ? ' class="active"' : '';
  const frClass = currentLang === 'fr' ? ' class="active"' : '';
  return `<div class="lang-switcher" role="navigation" aria-label="Language">
    <a href="${enHref}"${enClass} hreflang="en">EN</a>
    <a href="${frHref}"${frClass} hreflang="fr">FR</a>
  </div>`;
}

function renderHero(spec, langText) {
  const meta = langText.metaLine.map(escapeHtml).join('<span> · </span>');
  return `<div class="hero">
    <div class="hero-badge">${escapeHtml(langText.badge)}</div>
    <h1>${escapeHtml(spec.title || '')}</h1>
    <p class="subtitle">${escapeHtml(spec.subtitle || '')}</p>
    <p class="hero-meta">${meta}</p>
  </div>`;
}

function renderMermaidScript() {
  // Inline Mermaid v11 CDN init — keeps the deck a single self-contained file
  // per language for easy hand-off.
  return `<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>
  mermaid.initialize({
    startOnLoad: true,
    theme: 'dark',
    themeVariables: {
      darkMode: true,
      background: '#0B1220',
      primaryColor: '#3B82F6',
      primaryBorderColor: '#1F2A37',
      primaryTextColor: '#E5E7EB',
      secondaryColor: '#16A34A',
      tertiaryColor: '#F97316',
      lineColor: '#94A3B8',
      fontFamily: 'Inter, -apple-system, sans-serif',
      fontSize: '14px'
    },
    flowchart: { htmlLabels: true, curve: 'basis', padding: 15, nodeSpacing: 50, rankSpacing: 50 },
    sequence: { useMaxWidth: true, showSequenceNumbers: true }
  });
</script>`;
}

function renderHtml(lang, spec) {
  const langText = TEXT[lang];
  const slides = Array.isArray(spec.slides) ? spec.slides : [];
  const sections = slides.map(renderSection).join('\n');
  return `<!DOCTYPE html>
<html lang="${langText.htmlLang}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(spec.title || 'Application Insights .NET 10')}</title>
  <meta name="description" content="${escapeHtml(spec.subtitle || '')}">
  <meta name="author" content="${escapeHtml(spec.author || '')}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
${CSS}
  </style>
</head>
<body>
${renderLangSwitcher(lang)}
${renderHero(spec, langText)}
${renderToc(slides, langText.contentsLabel)}
<div class="container">
${sections}
</div>
<div class="footer"><p>${escapeHtml(langText.footer)}</p></div>
${renderMermaidScript()}
</body>
</html>
`;
}

function main() {
  for (const lang of LANGS) {
    const yamlPath = join(ROOT, 'slides', 'content', lang, 'deck.yaml');
    if (!existsSync(yamlPath)) {
      console.warn(`⚠ ${yamlPath} not found; skipping ${lang}`);
      continue;
    }
    const spec = yaml.load(readFileSync(yamlPath, 'utf8'));
    const html = renderHtml(lang, spec || {});
    const outPath = OUT_FILES[lang];
    mkdirSync(dirname(outPath), { recursive: true });
    writeFileSync(outPath, html, 'utf8');
    const slideCount = Array.isArray(spec?.slides) ? spec.slides.length : 0;
    console.log(`✓ wrote ${outPath} (${slideCount} slides)`);
  }
}

main();
