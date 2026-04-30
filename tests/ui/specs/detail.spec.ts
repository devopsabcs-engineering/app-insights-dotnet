import { expect, test } from '@playwright/test';
import { captureScreenshot, setCulture } from './helpers';

test.describe('Establishment detail', () => {
  test.beforeEach(async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
  });

  test('drill from search results into a single establishment', async ({ page }) => {
    await page.goto('/Etablissements?region=06-MONTREAL');
    const firstRow = page.locator('table.data-table tbody tr').first();
    await expect(firstRow).toBeVisible();
    const expectedName = (await firstRow.locator('td').first().innerText()).trim();

    await firstRow.getByRole('link', { name: 'View' }).click();

    await expect(page).toHaveURL(/\/Etablissements\/Detail\/\d+$/);
    await expect(page.locator('section.hero h1')).toHaveText(expectedName);
    await expect(page.getByRole('heading', { name: 'Convictions' })).toBeVisible();
    await expect(page.getByRole('link', { name: /Back to search/ })).toBeVisible();

    await captureScreenshot(page, 'detail-from-search');
  });

  test('shows the not-found message for an unknown id', async ({ page }) => {
    await page.goto('/Etablissements/Detail/9999999');
    await expect(page.locator('.empty-state')).toContainText(/could not be found/i);
    await captureScreenshot(page, 'detail-not-found');
  });
});
