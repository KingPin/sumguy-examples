const { addExtra } = require('puppeteer-extra');
const puppeteerCore = require('puppeteer-core');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');

const puppeteer = addExtra(puppeteerCore);
puppeteer.use(StealthPlugin());

const CHROME = process.env.CHROMIUM_BIN;
if (!CHROME) {
  console.error('CHROMIUM_BIN env var required');
  process.exit(1);
}

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    executablePath: CHROME,
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.goto('http://localhost:8080/?client=puppeteer-stealth', {
    waitUntil: 'networkidle0',
    timeout: 30000,
  });
  await new Promise((r) => setTimeout(r, 1000));
  await browser.close();
  console.log('puppeteer-stealth done');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
