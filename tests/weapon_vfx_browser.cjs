const assert = require('node:assert/strict');
const { chromium } = require('../tools/browser/node_modules/playwright');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
  });
  try {
    const context = await browser.newContext({viewport: {width: 390, height: 844}, isMobile: true, hasTouch: true});
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) errors.push(message.text());
    });
    const scale = 390 / 720, offset = (844 - 1280 * scale) / 2;
    const tap = async (x, y) => {
      await page.touchscreen.tap(x * scale, y * scale + offset);
      await page.waitForTimeout(250);
    };
    await page.goto(process.env.GAME_URL || 'http://localhost:8060');
    await page.waitForFunction(() => !document.querySelector('#status'), null, {timeout: 120000});
    await page.waitForTimeout(1500);
    await tap(610, 74); // Skip the opening story in this isolated browser profile.
    await tap(188, 756); // Mech preparation.
    await tap(530, 1115); // Motion and VFX review.
    await tap(110, 847); // Idle pose keeps the test independent of footstep animation.
    await tap(508, 1048); // Enable actual attack demonstration.
    const frames = [];
    for (let i = 0; i < 9; i++) {
      await tap(122 + (i % 5) * 119, 894 + Math.floor(i / 5) * 42);
      await page.waitForTimeout(700);
      frames.push(await page.screenshot({clip: {x: 66 * scale, y: 366 * scale + offset, width: 588 * scale, height: 438 * scale}}));
      if (i === 4) await page.screenshot({path: 'tests/weapon-vfx-review-mobile.png'});
    }
    assert(new Set(frames.map(frame => frame.toString('base64'))).size >= 8, 'weapon selectors change the actual rendered stage');
    await tap(158, 991); // Pause.
    const clip = {x: 66 * scale, y: 366 * scale + offset, width: 588 * scale, height: 438 * scale};
    const paused = await page.screenshot({clip});
    await page.waitForTimeout(700);
    assert(paused.equals(await page.screenshot({clip})), 'paused weapon stage remains visually frozen');
    await page.screenshot({path: 'tests/weapon-vfx-paused-mobile.png'});
    assert.deepEqual(errors, [], 'nine weapon families render without JS or Godot errors');
    console.log('WEAPON VFX BROWSER PASS: nine weapon selections, real attack demonstration, mobile rendering and frozen paused stage; no runtime errors');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
