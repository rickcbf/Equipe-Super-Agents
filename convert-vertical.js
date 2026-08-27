const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const htmlFiles = [
  { file: '12-hook-vertical.html', width: 1080, height: 1920 },
  { file: '13-titulo-vertical.html', width: 1080, height: 1920 },
  { file: '14-preco-vertical.html', width: 1080, height: 1920 },
];

(async () => {
  const browser = await puppeteer.launch({ headless: true });
  const pngDir = path.join(__dirname, 'png');
  if (!fs.existsSync(pngDir)) fs.mkdirSync(pngDir);

  for (const { file, width, height } of htmlFiles) {
    const page = await browser.newPage();
    await page.setViewport({ width, height, deviceScaleFactor: 1 });
    const filePath = 'file:///' + path.join(__dirname, file).replace(/\\/g, '/');
    await page.goto(filePath, { waitUntil: 'networkidle0', timeout: 15000 });
    await new Promise(r => setTimeout(r, 1500));
    const pngName = file.replace('.html', '.png');
    await page.screenshot({ path: path.join(pngDir, pngName), fullPage: false });
    console.log('OK:', pngName);
    await page.close();
  }

  await browser.close();
})();
