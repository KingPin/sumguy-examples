const { chromium } = require('playwright-core');

const CHROME = process.env.CHROMIUM_BIN;
if (!CHROME) {
  console.error('CHROMIUM_BIN env var required');
  process.exit(1);
}

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: CHROME,
  });
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto('http://localhost:8080/?client=playwright-vanilla', {
    waitUntil: 'networkidle',
    timeout: 30000,
  });
  await page.waitForTimeout(1000);
  await browser.close();
  console.log('playwright-vanilla done');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
