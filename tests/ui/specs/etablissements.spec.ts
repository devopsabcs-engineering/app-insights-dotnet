import { expect, test } from '@playwright/test';
import { captureScreenshot, setCulture } from './helpers';

test.describe('Establishments search', () => {
  test.beforeEach(async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
  });

  test('shows the initial prompt before any search is run', async ({ page }) => {
    await page.goto('/Etablissements');
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Search establishments');
    await expect(page.locator('.empty-state')).toContainText(/Pick a region/i);
    await expect(page.locator('table.data-table')).toHaveCount(0);
    await captureScreenshot(page, 'initial-prompt');
  });

  test('returns rows when searching by region via the dropdown', async ({ page }) => {
    await page.goto('/Etablissements');
    await page.locator('select#region').selectOption('06-MONTREAL');
    await page.getByRole('button', { name: 'Search' }).click();

    await expect(page).toHaveURL(/region=06-MONTREAL/);
    await expect(page.locator('p.muted')).toContainText(/establishments shown/);
    const rowCount = await page.locator('table.data-table tbody tr').count();
    expect(rowCount).toBeGreaterThan(0);
    await expect(page.locator('table.data-table tbody tr').first().locator('.badge')).toContainText('06-MONTREAL');

    await captureScreenshot(page, 'search-region-montreal');
  });

  test('returns rows when searching by city', async ({ page }) => {
    await page.goto('/Etablissements');
    await page.locator('input#city').fill('Montreal');
    await page.getByRole('button', { name: 'Search' }).click();

    await expect(page).toHaveURL(/city=Montreal/);
    const rowCount = await page.locator('table.data-table tbody tr').count();
    expect(rowCount).toBeGreaterThan(0);

    await captureScreenshot(page, 'search-city-montreal');
  });

  test('shows the empty-state message when the filter matches nothing', async ({ page }) => {
    await page.goto('/Etablissements?city=ZZZ-DOES-NOT-EXIST');
    await expect(page.locator('.empty-state')).toContainText(/No establishments matched/i);
    await captureScreenshot(page, 'search-no-results');
  });
});
