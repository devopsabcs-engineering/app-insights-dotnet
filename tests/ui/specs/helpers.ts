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
  // Make sure the page has finished its initial load before snapshotting so a
  // still-rendering layout doesn't trigger Chromium's intermittent
  // "Unable to capture screenshot" protocol error on full-page captures.
  await page.waitForLoadState('load');
  try {
    await page.screenshot({ path: target, fullPage: true, animations: 'disabled' });
  } catch {
    // A full-page capture can transiently fail under parallel load; retry once
    // after a brief settle, then fall back to a viewport capture so the wiki
    // still gets an image instead of the whole test failing on a flaky snapshot.
    await page.waitForTimeout(250);
    await page.screenshot({ path: target, animations: 'disabled' });
  }
  return target;
}

/**
 * Abort the App Insights browser SDK and its click-analytics CDN requests.
 *
 * The layout embeds a render-blocking `js.monitor.azure.com` script (no
 * async/defer). When that CDN is slow under parallel test load the page
 * renders incrementally, leaving controls "not stable" for clicks and
 * full-page screenshots unable to capture. Blocking telemetry in the UI tests
 * removes that flakiness without changing any page behaviour under test.
 * Routes must be registered before the first navigation.
 */
export async function blockTelemetry(page: Page): Promise<void> {
  await page.route('**/js.monitor.azure.com/**', route => route.abort());
  await page.route('**/*.applicationinsights.azure.com/**', route => route.abort());
  await page.route('**/dc.services.visualstudio.com/**', route => route.abort());
}

/**
 * Switch the UI culture by visiting the /setlang endpoint and waiting for the
 * resulting redirect back to the page. Use 'fr-CA' or 'en-CA'.
 */
export async function setCulture(page: Page, culture: 'fr-CA' | 'en-CA', returnPath = '/'): Promise<void> {
  const url = `/setlang?culture=${culture}&returnUrl=${encodeURIComponent(returnPath)}`;
  await page.goto(url, { waitUntil: 'domcontentloaded' });
}
