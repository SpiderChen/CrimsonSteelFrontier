const assert = require('node:assert/strict');
const { chromium } = require('../tools/browser/node_modules/playwright');
const nav = require('./ui_navigation.cjs');

(async () => {
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: ['--use-angle=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'],
  });
  try {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(m.text())) errors.push(m.text()); });
    const base = process.env.GAME_URL || 'http://localhost:8060';
    const point = (x, y) => {
      const v = page.viewportSize(), s = Math.min(v.width / 720, v.height / 1280);
      return { x: x * s + (v.width - 720 * s) / 2, y: y * s + (v.height - 1280 * s) / 2 };
    };
    async function tap(x, y) { const p = point(x, y); await page.touchscreen.tap(p.x, p.y); await page.waitForTimeout(250); }
    async function ready() { await page.waitForFunction(() => !document.querySelector('#status'), null, { timeout: 120000 }); }
    async function save() {
      return page.evaluate(async () => {
        for (const info of await indexedDB.databases()) {
          const db = await new Promise(resolve => { const r = indexedDB.open(info.name); r.onsuccess = () => resolve(r.result); });
          for (const name of db.objectStoreNames) {
            const data = await new Promise(resolve => {
              const store = db.transaction(name).objectStore(name), rows = store.getAll(), keys = store.getAllKeys();
              let r, k; const done = () => { if (r && k) resolve({ rows: r, keys: k }); };
              rows.onsuccess = () => { r = rows.result; done(); }; keys.onsuccess = () => { k = keys.result; done(); };
            });
            const index = data.keys.findIndex(k => String(k).endsWith('/crimson_front_v1.json'));
            if (index >= 0) { db.close(); return JSON.parse(new TextDecoder().decode(data.rows[index].contents)); }
          }
          db.close();
        }
      });
    }
    async function persisted(predicate) {
      const until = Date.now() + 15000;
      let value;
      while (Date.now() < until) { value = await save(); if (value && predicate(value)) return value; await page.waitForTimeout(150); }
      assert.fail(JSON.stringify({ save: value, errors }));
    }
    await page.goto(base); await ready();
    await persisted(d => d.narrative?.active === 'prologue');
    await page.waitForTimeout(500);
    await page.screenshot({ path: 'tests/story-prologue-mobile.png' });
    await tap(530, 1206); await tap(530, 1206);
    const progress = await persisted(d => d.narrative.cursor >= 1);
    await page.reload(); await ready();
    await persisted(d => d.narrative.active === 'prologue' && d.narrative.cursor === progress.narrative.cursor);
    await tap(610, 74);
    const completed = await persisted(d => d.narrative.seen.includes('prologue') && !d.narrative.active);
    assert.equal(completed.world.docked, true);
    await page.screenshot({ path: 'tests/story-guide-carrier-mobile.png' });
    await nav.facility(tap, 'regions'); await tap(360, 338); await tap(360, 754);
    await persisted(d => d.narrative.active === 'briefing_0' && d.narrative.milestones.launch);
    await tap(610, 74);
    const touch = await context.newCDPSession(page);
    await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ ...point(200, 700), id: 1 }] });
    await touch.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ ...point(270, 700), id: 1 }] });
    await page.waitForTimeout(800);
    await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await persisted(d => d.narrative.milestones.move && !d.world.expedition_autopilot);
    await tap(530, 56);
    await persisted(d => d.narrative.milestones.auto && d.world.expedition_autopilot);
    await tap(568, 160); await tap(160, 515); await tap(624, 157);
    await persisted(d => d.narrative.milestones.fleet);
    await page.screenshot({ path: 'tests/story-guide-field-mobile.png' });
    await tap(656, 1056); await tap(360, 783);
    await persisted(d => d.narrative.active === 'first_return' && d.narrative.milestones.return);
    await tap(610, 74); await tap(510, 1027); await nav.facility(tap, 'story');
    await page.screenshot({ path: 'tests/story-archive-mobile.png' });
    await tap(360, 367); // The first archive row is the prologue.
    await page.waitForTimeout(400);
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.screenshot({ path: 'tests/story-prologue-desktop.png' });
    await tap(610, 74);
    const afterReplay = await save();
    assert.equal(afterReplay.narrative.seen.filter(id => id === 'prologue').length, 1);
    assert.deepEqual(errors, []);
    console.log('STORY BROWSER PASS: cinematic, saved cursor, real touch onboarding, extraction dialogue, archive and responsive layouts');
  } finally { await browser.close(); }
})().catch(e => { console.error(e); process.exitCode = 1; });
