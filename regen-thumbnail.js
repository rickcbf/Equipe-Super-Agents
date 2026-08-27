const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 720, deviceScaleFactor: 1 });
  const filePath = 'file:///' + path.join(__dirname, '09-thumbnail-youtube-v2.html').replace(/\\/g, '/');
  await page.goto(filePath, { waitUntil: 'networkidle0', timeout: 15000 });
  await new Promise(r => setTimeout(r, 2500));
  await page.screenshot({ path: path.join(__dirname, 'png', '09-thumbnail-youtube-v2.png'), fullPage: false });
  console.log('OK: 09-thumbnail-youtube-v2.png (1280x720)');
  await page.close();
  await browser.close();
})();
