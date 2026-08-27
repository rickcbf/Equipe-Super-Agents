const puppeteer = require('puppeteer');
const path = require('path');

const htmlFiles = [
  { file: '09-thumbnail-youtube.html', width: 1280, height: 720 },
  { file: '11-credibilidade.html', width: 1920, height: 1080 },
];

(async () => {
  const browser = await puppeteer.launch({ headless: true });
  const pngDir = path.join(__dirname, 'png');

  for (const { file, width, height } of htmlFiles) {
    const page = await browser.newPage();
    await page.setViewport({ width, height, deviceScaleFactor: 1 });
    const filePath = 'file:///' + path.join(__dirname, file).replace(/\\/g, '/');
    await page.goto(filePath, { waitUntil: 'networkidle0', timeout: 15000 });
    await new Promise(r => setTimeout(r, 2000));
    const pngName = file.replace('.html', '.png');
    await page.screenshot({ path: path.join(pngDir, pngName), fullPage: false });
    console.log('OK:', pngName);
    await page.close();
  }

  await browser.close();
  console.log('PNGs com caricatura regenerados!');
})();
