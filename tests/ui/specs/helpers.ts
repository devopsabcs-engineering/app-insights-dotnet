import { Page, test } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Folder where deterministic per-test screenshots are written. The Azure
 * DevOps pipeline publishes everything in here to the project wiki so the
 * latest run is always browsable from the wiki sidebar.
 */
export const SCREENSHOT_DIR = path.resolve(__dirname, '..', 'screenshots');

if (!fs.existsSync(SCREENSHOT_DIR)) {
  fs.mkdirSync(SCREENSHOT_DIR, { recursive: true });
}

/**
 * Save a full-page PNG screenshot under `screenshots/<spec>--<name>.png`.
 *
 * The spec file name comes from `test.info().titlePath[0]`, which keeps the
 * captured filenames stable across runs (matching wiki page deep-links).
 */
export async function captureScreenshot(page: Page, name: string): Promise<string> {
  const info = test.info();
  const specFile = path.basename(info.file, path.extname(info.file));
  const safe = name.replace(/[^a-z0-9._-]+/gi, '-').toLowerCase();
  const target = path.join(SCREENSHOT_DIR, `${specFile}--${safe}.png`);
  await page.screenshot({ path: target, fullPage: true });
  return target;
}

/**
 * Switch the UI culture by visiting the /setlang endpoint and waiting for the
 * resulting redirect back to the page. Use 'fr-CA' or 'en-CA'.
 */
export async function setCulture(page: Page, culture: 'fr-CA' | 'en-CA', returnPath = '/'): Promise<void> {
  const url = `/setlang?culture=${culture}&returnUrl=${encodeURIComponent(returnPath)}`;
  await page.goto(url, { waitUntil: 'domcontentloaded' });
}
