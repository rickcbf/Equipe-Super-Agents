const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const htmlFiles = [
  { file: '01-titulo.html', width: 1920, height: 1080 },
  { file: '02-hook.html', width: 1920, height: 1080 },
  { file: '03-tool1-gold-snapshot.html', width: 1920, height: 1080 },
  { file: '04-tool2-market-context.html', width: 1920, height: 1080 },
  { file: '05-tool3-technical-analysis.html', width: 1920, height: 1080 },
  { file: '06-tool4-multi-timeframe.html', width: 1920, height: 1080 },
  { file: '07-tool5-entry-filters.html', width: 1920, height: 1080 },
  { file: '08-preco-cta.html', width: 1920, height: 1080 },
  { file: '09-thumbnail-youtube.html', width: 1280, height: 720 },
  { file: '10-encerramento.html', width: 1920, height: 1080 },
  { file: '11-credibilidade.html', width: 1920, height: 1080 },
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
  console.log('\nTodos os PNGs gerados em video-assets/png/');
})();
