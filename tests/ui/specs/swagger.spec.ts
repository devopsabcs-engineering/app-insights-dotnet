import { expect, test, Locator, Page } from '@playwright/test';
import { captureApiScreenshot } from './helpers';

/**
 * Drives the Mapaq.Api Swagger UI (`/swagger/index.html`) end-to-end:
 *
 *   * Renders the landing page and screenshots the operations list.
 *   * Expands every operation, clicks **Try it out**, fills required
 *     parameters, clicks **Execute**, waits for the response panel, and
 *     screenshots the request + response together.
 *
 * Screenshots are written to `tests/ui/api-screenshots/` so the
 * `ui-tests` GitHub Actions workflow can publish them to the dedicated
 * `API-Tests-Latest` wiki page (separate from `UI-Tests-Latest`).
 *
 * The API base URL is taken from the `MAPAQ_API_URL` env var (the workflow
 * resolves it from `mapaq-api-*` in `rg-<env>`); falls back to the local
 * `https://localhost:7250` when running interactively.
 */

// Strip trailing slashes so we can append `/swagger/index.html` cleanly.
const apiBaseUrl =
  (process.env.MAPAQ_API_URL ?? 'https://localhost:7250').replace(/\/+$/, '');
const swaggerUrl = `${apiBaseUrl}/swagger/index.html`;

/**
 * Locate a single Swagger UI operation block by its HTTP method + exact path.
 *
 * Swagger UI renders each operation as `.opblock.opblock-<method>` with a
 * `.opblock-summary-path` whose visible text is the literal route. Filtering
 * by exact text avoids the `/api/establishments` vs `/api/establishments/{id}`
 * ambiguity that a substring match would produce.
 */
function operation(page: Page, method: 'get' | 'post', path: string): Locator {
  return page
    .locator(`.opblock.opblock-${method}`)
    .filter({ has: page.locator('.opblock-summary-path').getByText(path, { exact: true }) });
}

/**
 * Expand the operation panel if it is currently collapsed.
 */
async function expandOperation(op: Locator): Promise<void> {
  const isOpen = await op.evaluate((el) => el.classList.contains('is-open'));
  if (!isOpen) {
    await op.locator('.opblock-summary').click();
  }
  // Wait for the body to render so subsequent locators are stable.
  await op.locator('.opblock-body').waitFor({ state: 'visible' });
}

/**
 * Fill the operation's parameter inputs **in declared (DOM) order**, mapping
 * one supplied value per `<input>` produced by Swagger UI.
 *
 * Swagger UI 5.x renders each parameter on its own `<tr>` of `table.parameters`,
 * but the row itself does NOT carry the `parameters` class — only the table
 * does. The actual `<input>` lives in `td.parameters-col_description`, so we
 * scope there to skip the read-only `parameters-col_name` cells and to avoid
 * matching the request-body editor's textarea elsewhere on the page.
 *
 * Values are filled in the same sequence as the OpenAPI document declares
 * them, which is also the visual top-to-bottom order on the page.
 */
async function fillParameters(op: Locator, values: string[]): Promise<void> {
  if (values.length === 0) {
    return;
  }
  const inputs = op.locator('table.parameters tbody td.parameters-col_description input');
  // Sanity-check there are enough input slots. A mismatch usually means the
  // Swagger doc changed shape and the spec needs updating.
  await expect(inputs).toHaveCount(values.length);
  for (let i = 0; i < values.length; i++) {
    await inputs.nth(i).fill(values[i]);
  }
}

/**
 * Drive the full Try it out → Execute → wait-for-response cycle for a single
 * operation, then capture a deterministic full-page screenshot.
 *
 * The screenshot name doubles as the wiki page heading slug (the publisher
 * derives `<spec> · <name>` from the file stem) so the order on the wiki
 * matches the order on the Swagger landing page.
 */
async function exerciseEndpoint(
  page: Page,
  method: 'get' | 'post',
  path: string,
  paramValues: string[],
  screenshotName: string,
): Promise<void> {
  const op = operation(page, method, path);
  await expect(op).toHaveCount(1, { timeout: 15_000 });

  await expandOperation(op);

  // "Try it out" toggles the parameters into editable inputs. Re-clicking
  // collapses them, so only click when the button is actually labelled
  // "Try it out" (vs "Cancel" after a previous click).
  const tryItOut = op.locator('button.try-out__btn');
  await expect(tryItOut).toBeVisible();
  if ((await tryItOut.textContent())?.trim().toLowerCase().startsWith('try')) {
    await tryItOut.click();
  }

  await fillParameters(op, paramValues);

  await op.locator('button.execute').click();

  // Swagger UI renders the response under `.responses-wrapper`; the live
  // response row has class `live-responses-table` once the call completes.
  // Wait for a status code cell so we screenshot a populated response (any
  // 2xx/4xx/5xx is fine — the goal is documenting what each call looks like).
  //
  // Some endpoints with OpenAPI 3.1 union-type query params (e.g. `year` on
  // `/api/inspections/rollup`, declared as `type: ["integer", "string"]` by
  // .NET 10's built-in OpenAPI generator for required value-type query
  // parameters) cause Swagger UI 5.x to render Execute without producing the
  // live-response DOM, even though the underlying API call succeeds. In that
  // case fall back to a brief settle delay so we still capture a meaningful
  // screenshot of the request form, and emit a workflow warning so the
  // regression is visible without breaking the build (AB#2226).
  try {
    await op
      .locator('.responses-wrapper .live-responses-table .response-col_status')
      .first()
      .waitFor({ state: 'visible', timeout: 30_000 });
  } catch (err) {
    const message = err instanceof Error ? err.message.split('\n')[0] : String(err);
    // GitHub Actions surfaces `::warning::` lines as warnings on the run
    // summary; locally it's just a console message.
    console.warn(
      `::warning::Swagger UI response panel did not appear for ${method.toUpperCase()} ${path} ` +
        `within 30s (${message}). Capturing the request-form screenshot only.`,
    );
    // Give Swagger UI a moment to render whatever it can (loading spinner,
    // partially-rendered payload, etc.) before we screenshot.
    await page.waitForTimeout(2_000);
  }

  // Scroll the operation into view so the screenshot frames it nicely on
  // pages where multiple endpoints have been expanded by prior runs.
  await op.scrollIntoViewIfNeeded();

  await captureApiScreenshot(page, screenshotName);
}

test.describe('Mapaq.Api Swagger UI', () => {
  // The Swagger UI bundle pulls assets from the same App Service so
  // `networkidle` is a reliable settle signal. Localhost dev cert issues are
  // already handled by `ignoreHTTPSErrors: true` in playwright.config.ts.
  test('lists all four endpoints on the landing page', async ({ page }) => {
    await page.goto(swaggerUrl, { waitUntil: 'networkidle' });
    await expect(page.locator('.opblock-summary')).toHaveCount(4);
    await expect(operation(page, 'get', '/api/establishments')).toHaveCount(1);
    await expect(operation(page, 'get', '/api/establishments/{id}')).toHaveCount(1);
    await expect(operation(page, 'get', '/api/inspections/rollup')).toHaveCount(1);
    await expect(operation(page, 'post', '/api/sync')).toHaveCount(1);
    await captureApiScreenshot(page, 'landing');
  });

  test('GET /api/establishments — search by region returns rows', async ({ page }) => {
    await page.goto(swaggerUrl, { waitUntil: 'networkidle' });
    // Two query params (city, region) declared in this order on the API.
    await exerciseEndpoint(
      page,
      'get',
      '/api/establishments',
      ['', '06-MONTREAL'],
      'get-establishments',
    );
  });

  test('GET /api/establishments/{id} — fetch a known establishment', async ({ page }) => {
    // Resolve a real id by hitting the list endpoint first; falls back to 1
    // when the API is unreachable so the test still produces a screenshot of
    // the (likely 404) error response — which is itself useful documentation.
    let id = '1';
    try {
      const list = await page.request.get(`${apiBaseUrl}/api/establishments?region=06-MONTREAL`, {
        timeout: 15_000,
      });
      if (list.ok()) {
        const rows = (await list.json()) as Array<{ establishmentId?: number; EstablishmentId?: number }>;
        const first = rows.find((r) => r.establishmentId ?? r.EstablishmentId);
        if (first) {
          id = String(first.establishmentId ?? first.EstablishmentId);
        }
      }
    } catch {
      // Ignore — fall back to id=1 so the test still produces a screenshot.
    }
    await page.goto(swaggerUrl, { waitUntil: 'networkidle' });
    await exerciseEndpoint(
      page,
      'get',
      '/api/establishments/{id}',
      [id],
      'get-establishment-by-id',
    );
  });

  test('GET /api/inspections/rollup — Montreal current year', async ({ page }) => {
    await page.goto(swaggerUrl, { waitUntil: 'networkidle' });
    // Seeder loads `today.Year - 1` and `today.Year`, so the current year
    // is always present in the demo dataset.
    const year = String(new Date().getFullYear());
    await exerciseEndpoint(
      page,
      'get',
      '/api/inspections/rollup',
      ['06-MONTREAL', year],
      'get-inspections-rollup',
    );
  });

  test('POST /api/sync — kicks off a CKAN sync (response captured)', async ({ page }) => {
    await page.goto(swaggerUrl, { waitUntil: 'networkidle' });
    // No path/query parameters; Swagger UI still shows Try it out + Execute.
    await exerciseEndpoint(page, 'post', '/api/sync', [], 'post-sync');
  });
});
