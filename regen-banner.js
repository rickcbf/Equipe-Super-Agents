const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 400, deviceScaleFactor: 1 });
  const filePath = 'file:///' + path.join(__dirname, 'banner-hotmart.html').replace(/\\/g, '/');
  await page.goto(filePath, { waitUntil: 'networkidle0', timeout: 15000 });
  await new Promise(r => setTimeout(r, 2500));
  await page.screenshot({ path: path.join(__dirname, 'png', 'banner-hotmart.png'), fullPage: false });
  console.log('OK: banner-hotmart.png (1280x400)');
  await page.close();
  await browser.close();
})();
