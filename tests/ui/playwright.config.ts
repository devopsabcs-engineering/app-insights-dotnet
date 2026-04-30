import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright configuration for the Mapaq.Web Razor pages.
 *
 * Targets `https://localhost:7010` by default so `npx playwright test`
 * just works once `pwsh ./scripts/start-local.ps1` is running. Override the
 * base URL via the MAPAQ_WEB_URL environment variable when pointing at a
 * deployed App Service:
 *
 *     $env:MAPAQ_WEB_URL = 'https://mapaq-web-xxxxx.azurewebsites.net'
 *     npx playwright test
 *
 * Reporters:
 *   * `list`     — concise per-test status in the terminal.
 *   * `html`     — playwright-report/index.html for local inspection.
 *   * `junit`    — test-results/junit.xml for the Azure DevOps Test tab.
 *
 * Screenshots for every test (pass or fail) land under `screenshots/` so the
 * pipeline can publish them to the project wiki. Test specs use
 * `await captureScreenshot(page, name)` from helpers.ts to control the file
 * name; failures still produce Playwright's default trace / video.
 */
const baseURL = process.env.MAPAQ_WEB_URL ?? 'https://localhost:7010';
const isCI = !!process.env.CI;

export default defineConfig({
  testDir: './specs',
  outputDir: './test-results/raw',
  // Tight timeouts so a stuck deployment fails the build fast instead of dragging on.
  timeout: 30_000,
  expect: { timeout: 10_000 },
  fullyParallel: true,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: isCI ? 2 : undefined,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
    ['junit', { outputFile: 'test-results/junit.xml' }],
  ],
  use: {
    baseURL,
    // Localhost dev cert fails strict TLS — accept it; deployed Azure URLs are valid certs.
    ignoreHTTPSErrors: true,
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1366, height: 900 } },
    },
  ],
});
