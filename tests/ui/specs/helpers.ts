import { Page, test } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Folder where deterministic per-test UI screenshots are written. The pipeline
 * publishes everything in here to the project wiki page `UI-Tests-Latest` so
 * the latest run is always browsable from the wiki sidebar.
 */
export const SCREENSHOT_DIR = path.resolve(__dirname, '..', 'screenshots');

/**
 * Folder where API (Swagger UI) screenshots are written. Published to the
 * separate wiki page `API-Tests-Latest` by the same workflow so the UI page
 * stays focused on Mapaq.Web while the API page documents Mapaq.Api.
 */
export const API_SCREENSHOT_DIR = path.resolve(__dirname, '..', 'api-screenshots');

for (const dir of [SCREENSHOT_DIR, API_SCREENSHOT_DIR]) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

async function _capture(page: Page, dir: string, name: string): Promise<string> {
  const info = test.info();
  const specFile = path.basename(info.file, path.extname(info.file));
  const safe = name.replace(/[^a-z0-9._-]+/gi, '-').toLowerCase();
  const target = path.join(dir, `${specFile}--${safe}.png`);
  await page.screenshot({ path: target, fullPage: true });
  return target;
}

/**
 * Save a full-page PNG screenshot under `screenshots/<spec>--<name>.png`.
 *
 * The spec file name comes from `test.info().titlePath[0]`, which keeps the
 * captured filenames stable across runs (matching wiki page deep-links).
 */
export async function captureScreenshot(page: Page, name: string): Promise<string> {
  return _capture(page, SCREENSHOT_DIR, name);
}

/**
 * Save a full-page PNG screenshot under `api-screenshots/<spec>--<name>.png`.
 *
 * Routed to a separate folder so the workflow can publish API screenshots to
 * the dedicated `API-Tests-Latest` wiki page without polluting the UI page.
 */
export async function captureApiScreenshot(page: Page, name: string): Promise<string> {
  return _capture(page, API_SCREENSHOT_DIR, name);
}

/**
 * Switch the UI culture by visiting the /setlang endpoint and waiting for the
 * resulting redirect back to the page. Use 'fr-CA' or 'en-CA'.
 */
export async function setCulture(page: Page, culture: 'fr-CA' | 'en-CA', returnPath = '/'): Promise<void> {
  const url = `/setlang?culture=${culture}&returnUrl=${encodeURIComponent(returnPath)}`;
  await page.goto(url, { waitUntil: 'domcontentloaded' });
}
