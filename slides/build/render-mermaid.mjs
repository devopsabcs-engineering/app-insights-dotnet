// render-mermaid.mjs
// Globs slides/content/**/*.yaml, extracts each slide's `mermaid:` block to a
// tempfile, and runs `mmdc` to render PNGs into docs/decks/assets/.
// Output filename pattern: <slide-key>-<lang>.png — encodes both slide-key and
// language so EN+FR variants of the same slide do not collide.

import { readFileSync, writeFileSync, mkdirSync, readdirSync, rmSync, existsSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import yaml from 'js-yaml';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = resolve(__dirname, '..', '..');

const CONTENT_DIR = join(ROOT, 'slides', 'content');
const OUT_DIR = join(ROOT, 'docs', 'decks', 'assets');
const MERMAID_CONFIG = join(ROOT, 'slides', 'theme', 'mermaid-config.json');

mkdirSync(OUT_DIR, { recursive: true });

function discoverYamlFiles() {
  const results = [];
  if (!existsSync(CONTENT_DIR)) return results;
  for (const lang of readdirSync(CONTENT_DIR, { withFileTypes: true })) {
    if (!lang.isDirectory()) continue;
    const langDir = join(CONTENT_DIR, lang.name);
    for (const entry of readdirSync(langDir, { withFileTypes: true })) {
      if (entry.isFile() && entry.name.endsWith('.yaml')) {
        results.push({ lang: lang.name, file: join(langDir, entry.name) });
      }
    }
  }
  return results;
}

function renderOne(mermaidSource, outPath) {
  const tmp = join(tmpdir(), `mermaid-${Date.now()}-${Math.random().toString(36).slice(2)}.mmd`);
  writeFileSync(tmp, mermaidSource, 'utf8');
  try {
    const args = [
      '-y', '-p', '@mermaid-js/mermaid-cli',
      'mmdc',
      '-i', tmp,
      '-o', outPath,
      '-b', 'transparent',
      '-t', 'dark',
      '-c', MERMAID_CONFIG,
      '-w', '1600',
      '-H', '900',
    ];
    const result = spawnSync('npx', args, { stdio: 'inherit', shell: process.platform === 'win32' });
    if (result.status !== 0) {
      console.error(`  ✗ mmdc failed for ${outPath} (exit ${result.status})`);
      return false;
    }
    return true;
  } finally {
    try { rmSync(tmp, { force: true }); } catch { /* ignore */ }
  }
}

function main() {
  const files = discoverYamlFiles();
  if (files.length === 0) {
    console.warn(`No YAML files found under ${CONTENT_DIR}`);
    return;
  }

  let renderedCount = 0;
  let skippedCount = 0;

  for (const { lang, file } of files) {
    const spec = yaml.load(readFileSync(file, 'utf8'));
    if (!spec || !Array.isArray(spec.slides)) {
      console.warn(`  ⚠ ${file} has no slides[]; skipping`);
      continue;
    }
    for (const slide of spec.slides) {
      if (!slide.mermaid) { skippedCount += 1; continue; }
      if (!slide.key) {
        console.warn(`  ⚠ slide in ${file} has mermaid: but no key:; skipping`);
        continue;
      }
      const outPath = join(OUT_DIR, `${slide.key}-${lang}.png`);
      console.log(`→ rendering ${slide.key} (${lang}) → ${outPath}`);
      if (renderOne(String(slide.mermaid), outPath)) {
        renderedCount += 1;
      }
    }
  }

  console.log(`\nDone. Rendered ${renderedCount} diagrams, skipped ${skippedCount} non-mermaid slides.`);
}

main();
