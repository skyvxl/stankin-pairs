import { expect, test } from '@playwright/test';

test('mobile usability smoke', async ({ page }) => {
	await page.route('**/groups.json', (route) =>
		route.fulfill({ json: [{ group_name: 'ИДБ-23-02' }] })
	);
	await page.route('**/%D0%98%D0%94%D0%91-23-02.json', (route) => route.fulfill({ json: [] }));

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

test('date picker closes after pressing outside it', async ({ page }) => {
	await page.addInitScript(() => {
		localStorage.setItem(
			'pairs_schedule_cache_v2',
			JSON.stringify({ groupName: 'ИДБ-23-02', entries: [] })
		);
	});
	await page.route('**/groups.json', (route) => route.fulfill({ json: [] }));

	await page.goto('/');
	await page.getByRole('button', { name: 'Открыть календарь' }).click();

	const previousMonthButton = page.getByRole('button', { name: 'Предыдущий месяц' });
	await expect(previousMonthButton).toBeVisible();

	await page.getByRole('heading', { name: 'ИДБ-23-02' }).click();
	await expect(previousMonthButton).toBeHidden();
});
