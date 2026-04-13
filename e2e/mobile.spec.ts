import { expect, test } from '@playwright/test';

test('mobile usability smoke', async ({ page }) => {
  await page.goto('/');

  await expect(page.getByRole('heading', { name: 'Расписание' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Группа' })).toBeVisible();

  await page.getByRole('button', { name: 'Группа' }).click();
  await expect(page.getByRole('heading', { name: 'Выбор группы' })).toBeVisible();

  const searchInput = page.getByPlaceholder('Поиск группы');
  await expect(searchInput).toBeVisible();
  await searchInput.fill('ИДБ');

  const firstGroup = page.locator('button', { hasText: 'ИДБ' }).first();
  await firstGroup.click();

  await expect(page.getByText('Выбранный день').or(page.getByText('Сегодня'))).toBeVisible();
  await expect(page.locator('main')).toBeVisible();
});
