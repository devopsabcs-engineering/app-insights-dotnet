import { expect, test } from '@playwright/test';
import { captureScreenshot, setCulture } from './helpers';

test.describe('Inspections rollup dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
  });

  test('renders the dashboard with rows for the default region/year', async ({ page }) => {
    await page.goto('/Inspections/Rollup');
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'Regional inspection dashboard',
    );
    await expect(page.locator('select#region')).toBeVisible();
    await expect(page.locator('select#year')).toBeVisible();
    await expect(page.locator('select#indicator')).toBeVisible();

    const rowCount = await page.locator('table.data-table tbody tr').count();
    expect(rowCount).toBeGreaterThan(0);
    await expect(page.locator('table.data-table .bar').first()).toBeVisible();
    await expect(page.locator('p.muted')).toContainText(/Annual total/);

    await captureScreenshot(page, 'rollup-default');
  });

  test('filters by indicator (Permits suspended) and shows only that indicator', async ({ page }) => {
    await page.goto('/Inspections/Rollup');
    await page.locator('select#indicator').selectOption('04-PermisSuspendus');
    await page.getByRole('button', { name: 'Show' }).click();

    await expect(page).toHaveURL(/indicator=04-PermisSuspendus/);
    const indicatorCells = page.locator('table.data-table tbody tr td:nth-child(2)');
    const count = await indicatorCells.count();
    expect(count).toBeGreaterThan(0);
    for (let i = 0; i < count; i++) {
      await expect(indicatorCells.nth(i)).toHaveText('Permits suspended');
    }

    await captureScreenshot(page, 'rollup-suspended-permits');
  });
});
