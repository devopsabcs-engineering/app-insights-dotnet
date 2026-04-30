import { expect, test } from '@playwright/test';
import { captureScreenshot, setCulture } from './helpers';

test.describe('Home page', () => {
  test.beforeEach(async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
  });

  test('renders heading, branding, and main navigation', async ({ page }) => {
    await page.goto('/');

    await expect(page).toHaveTitle(/Inspector dashboard/i);
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'Quebec food-establishment inspections',
    );
    await expect(page.locator('.brand__text span').first()).toHaveText('MAPAQ Inspector');
    await expect(page.locator('.site-subnav a', { hasText: 'Home' })).toHaveClass(/is-active/);
    await expect(page.locator('.site-subnav a', { hasText: 'Establishments' })).toBeVisible();
    await expect(page.locator('.site-subnav a', { hasText: 'Regional dashboard' })).toBeVisible();
    await expect(page.locator('.topic-grid .topic')).toHaveCount(5);

    await captureScreenshot(page, 'landing');
  });

  test('tag pill navigates to filtered Establishments page', async ({ page }) => {
    await page.goto('/');
    await page.locator('.tag-pill', { hasText: 'Establishments in Montreal' }).click();
    await expect(page).toHaveURL(/\/Etablissements\?region=06-MONTREAL$/);
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Search establishments');
    await expect(page.locator('table.data-table tbody tr').first()).toBeVisible();
    await captureScreenshot(page, 'tag-pill-montreal-results');
  });
});
