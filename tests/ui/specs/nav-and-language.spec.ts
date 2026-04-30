import { expect, test } from '@playwright/test';
import { captureScreenshot, setCulture } from './helpers';

test.describe('Site chrome and language', () => {
  test('main navigation links resolve to their pages', async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
    await page.goto('/');

    await page.locator('.site-subnav a', { hasText: 'Establishments' }).click();
    await expect(page).toHaveURL(/\/Etablissements/);
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Search establishments');

    await page.locator('.site-subnav a', { hasText: 'Regional dashboard' }).click();
    await expect(page).toHaveURL(/\/Inspections\/Rollup/);
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Regional inspection dashboard');

    await page.locator('.site-subnav a', { hasText: 'Home' }).click();
    await expect(page).toHaveURL(/\/(\?.*)?$/);
    await expect(page.getByRole('heading', { level: 1 })).toContainText('Quebec food-establishment inspections');

    await captureScreenshot(page, 'main-nav-home');
  });

  test('switches between French and English via the header toggle', async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
    await page.goto('/');
    await expect(page.locator('.site-subnav a').first()).toHaveText('Home');
    await captureScreenshot(page, 'language-en');

    await page.locator('.header-meta a', { hasText: 'FR' }).click();
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      /Inspections des établissements alimentaires/i,
    );
    await captureScreenshot(page, 'language-fr');

    await page.locator('.header-meta a', { hasText: 'EN' }).click();
    await expect(page.getByRole('heading', { level: 1 })).toContainText(
      'Quebec food-establishment inspections',
    );
  });

  test('footer disclaimer is present on every page', async ({ page }) => {
    await setCulture(page, 'en-CA', '/');
    for (const path of ['/', '/Etablissements', '/Inspections/Rollup']) {
      await page.goto(path);
      await expect(page.locator('footer.site-footer small')).toContainText(/Demo application/i);
    }
    await captureScreenshot(page, 'footer-disclaimer');
  });
});
