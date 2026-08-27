const puppeteer = require('puppeteer');
const path = require('path');

(async () => {
  const browser = await puppeteer.launch({ headless: true });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900, deviceScaleFactor: 1 });
  const filePath = 'file:///' + path.join(__dirname, 'pagina-vendas.html').replace(/\\/g, '/');
  await page.goto(filePath, { waitUntil: 'networkidle0', timeout: 20000 });
  await new Promise(r => setTimeout(r, 3000));

  await page.screenshot({ path: path.join(__dirname, 'png', 'vendas-hero.png'), fullPage: false });
  console.log('OK: hero');

  await page.evaluate(() => window.scrollTo(0, 900));
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(__dirname, 'png', 'vendas-proof-problem.png'), fullPage: false });
  console.log('OK: proof+problem');

  await page.evaluate(() => window.scrollTo(0, 1900));
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(__dirname, 'png', 'vendas-features.png'), fullPage: false });
  console.log('OK: features');

  await page.evaluate(() => window.scrollTo(0, 3000));
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(__dirname, 'png', 'vendas-demo.png'), fullPage: false });
  console.log('OK: demo');

  await page.evaluate(() => window.scrollTo(0, 4500));
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(__dirname, 'png', 'vendas-pricing.png'), fullPage: false });
  console.log('OK: pricing');

  await page.evaluate(() => window.scrollTo(0, 5800));
  await new Promise(r => setTimeout(r, 500));
  await page.screenshot({ path: path.join(__dirname, 'png', 'vendas-faq-cta.png'), fullPage: false });
  console.log('OK: faq+cta');

  await page.close();
  await browser.close();
  console.log('Screenshots da pagina de vendas prontos!');
})();
