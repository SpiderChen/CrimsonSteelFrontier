// Real Chrome / WebGL acceptance in an ephemeral profile, never a user profile.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../tools/browser/node_modules/playwright');
const nav = require('./ui_navigation.cjs');

(async () => {
  const output = process.env.OUTPUT_DIR || '.local/roster-acceptance';
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
    args: [...(process.env.SOFTWARE_GL ? ['--use-angle=swiftshader'] : ['--enable-gpu']), '--enable-webgl', '--ignore-gpu-blocklist'],
  });
  let page;
  const errors = [];
  try {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
    page = await context.newPage();
    const base = process.env.GAME_URL || 'http://localhost:8061';
    page.on('pageerror', error => errors.push(String(error)));
    page.on('console', message => {
      if (message.type() === 'error' || /SCRIPT ERROR|ERROR:/.test(message.text())) {
        errors.push(message.text()); console.error(message.text());
      }
    });
    await page.route('**/__fixture', route => route.fulfill({ status: 200, contentType: 'text/html', body: '<!doctype html><title>isolated roster fixture</title>' }));
    function point(x, y) {
      const viewport = page.viewportSize(), scale = Math.min(viewport.width / 720, viewport.height / 1280);
      return { x: x * scale + (viewport.width - 720 * scale) / 2, y: y * scale + (viewport.height - 1280 * scale) / 2 };
    }
    async function tap(x, y, delay = 300) {
      const position = point(x, y); await page.touchscreen.tap(position.x, position.y);
      if (delay) await page.waitForTimeout(delay);
    }
    async function ready() {
      await page.waitForFunction(() => !document.querySelector('#status'), null, { timeout: 120000 });
      await page.waitForTimeout(1000);
    }
    async function snap(name) { await page.screenshot({ path: path.join(output, `${name}.png`) }); }
    async function save(setup = false) {
      return page.evaluate(async setup => {
        for (const info of await indexedDB.databases()) {
          const database = await new Promise((resolve, reject) => {
            const request = indexedDB.open(info.name);
            request.onsuccess = () => resolve(request.result); request.onerror = () => reject(request.error);
          });
          for (const storeName of database.objectStoreNames) {
            const entries = await new Promise((resolve, reject) => {
              const store = database.transaction(storeName).objectStore(storeName), values = store.getAll(), names = store.getAllKeys();
              let rows, keys; const finish = () => { if (rows && keys) resolve({ rows, keys }); };
              values.onsuccess = () => { rows = values.result; finish(); }; names.onsuccess = () => { keys = names.result; finish(); };
              values.onerror = names.onerror = event => reject(event.target.error);
            });
            const index = entries.keys.findIndex(key => String(key).endsWith('/crimson_front_v1.json'));
            if (index < 0) continue;
            const row = entries.rows[index], data = JSON.parse(new TextDecoder().decode(row.contents));
            if (setup) {
              if (data.levels.length !== 6 || data.mechs?.units.length !== 6) throw new Error('Web export does not contain the expanded six-pilot/six-chassis roster');
              data.selected = 0; data.selected_mech = 0;
              data.unlocked = [true, true, true, false, false, false]; data.levels = [1, 1, 1, 1, 1, 1];
              data.gems = 900; data.sound = false; data.hp = 100; data.recovery = 0; data.heat = 0;
              data.pilot_runtime = {}; data.world = { docked: true, position: [384, 384] };
              data.narrative = { ...data.narrative, active: '', cursor: 0, pending: [], tutorial: false, unlocked: ['prologue', 'briefing_0'], seen: ['prologue', 'briefing_0'] };
              // Move existing items rather than duplicating IDs or inventing inventory.
              data.parts.loadouts[5] = { ...data.parts.loadouts[0] }; data.parts.loadouts[0] = {};
              const weapon = data.parts.inventory.find(item => item.id === data.parts.loadouts[5]['0']);
              if (weapon) { weapon.blueprint = 15; weapon.mechanism = ''; }
              delete data.parts.loadouts[5]['4']; // Single beam keeps the starter reactor within its actual power budget.
              data.last_seen = Math.floor(Date.now() / 1000);
              if (data.salvage) data.salvage.cursor = data.last_seen;
              row.contents = new TextEncoder().encode(JSON.stringify(data)); row.timestamp = new Date();
              await new Promise((resolve, reject) => {
                const transaction = database.transaction(storeName, 'readwrite');
                transaction.objectStore(storeName).put(row, entries.keys[index]);
                transaction.oncomplete = resolve; transaction.onerror = () => reject(transaction.error);
              });
            }
            database.close(); return data;
          }
          database.close();
        }
      }, setup);
    }
    async function persisted(predicate, timeout = 20000) {
      const until = Date.now() + timeout; let value;
      while (Date.now() < until) {
        value = await save(); if (value && predicate(value)) return value;
        if (errors.length) assert.fail(JSON.stringify(errors));
        await page.waitForTimeout(180);
      }
      await snap('failure-state'); assert.fail(JSON.stringify({ save: value, errors }));
    }
    async function finishStories() {
      for (let count = 0; count < 4; count++) {
        const current = await save();
        if (!current?.narrative?.active) return;
        const active = current.narrative.active;
        await tap(610, 74); await persisted(data => data.narrative.active !== active);
      }
    }

    await page.goto(base); await ready(); await persisted(data => data.narrative?.active === 'prologue');
    await tap(610, 74); await persisted(data => !data.narrative.active);
    await page.goto(`${base}/__fixture`); await page.waitForTimeout(800); const initial = await save(true);
    assert.equal(initial.unlocked.filter(Boolean).length, 3);
    await page.goto(base); await ready(); await persisted(data => data.gems === 900 && data.levels.length === 6);
    await nav.facility(tap, 'pilots');
    await snap('six-pilot-tabs-mobile');
    for (let index = 3; index < 6; index++) {
      await tap(132 + (index - 3) * 228, 362);
      await snap(`pilot-${index}-locked-mobile`);
      const before = await save(); await tap(180, 1029);
      const unlocked = await persisted(data => data.unlocked[index] && data.gems === before.gems - 300);
      assert.equal(unlocked.recruits, before.recruits + 1);
      await persisted(data => data.narrative.active === `arrival_${index}`);
      await snap(`pilot-${index}-arrival-mobile`);
      await finishStories(); await tap(180, 1029); await persisted(data => data.selected === index);
      await persisted(data => data.narrative.active === `bond_${index}`);
      await snap(`pilot-${index}-bond-mobile`);
      await finishStories(); await persisted(data => !data.narrative.active && data.narrative.seen.includes(`bond_${index}`));
      await snap(`pilot-${index}-profile-mobile`);
      await tap(180, 1111); await snap(`pilot-${index}-abilities-mobile`); await tap(624, 187);
      console.log(`ROSTER PASS: pilot ${index} portrait, 300-crystal unlock, profile selection and ability sheet`);
    }
    const recruited = await persisted(data => data.unlocked.every(Boolean) && data.gems === 0 && data.selected === 5);
    assert.equal(recruited.recruits, initial.recruits + 3);
    await nav.facility(tap, 'hangar'); await tap(574, 216); await tap(578, 1039);
    await page.waitForTimeout(900); await snap('new-chassis-hangar-mobile');
    for (let index = 3; index < 6; index++) {
      await tap(547, 451 + (index - 3) * 250);
      await persisted(data => data.selected_mech === index && data.selected === 5);
      await snap(`chassis-${index}-selected-mobile`);
      if (index < 5) await tap(574, 216);
    }
    await tap(534, 1115);
    await tap(112, 847); // Idle makes silhouette comparison use the same neutral stance.
    for (let index = 3; index < 6; index++) {
      await tap(160 + (index - 3) * 198, 336); await page.waitForTimeout(600);
      await snap(`chassis-${index}-3d-review-mobile`);
    }
    await tap(360, 1107);
    console.log('ROSTER PASS: page-two live 3D cards, all three chassis selections, six-chassis motion review');
    await nav.facility(tap, 'training');
    await page.waitForTimeout(15000); await snap('eve-training-skill-mobile');
    await tap(555, 1028);
    const afterTraining = await save();
    assert.equal(afterTraining.hp, 100); assert.deepEqual(afterTraining.pilot_roster, recruited.pilot_roster);
    await nav.facility(tap, 'regions'); await tap(360, 338); await tap(360, 754);
    await persisted(data => data.world.docked === false); await finishStories();
    await snap('eve-xuanjia-field-start-mobile');
    const start = (await save()).world.position;
    const touch = await context.newCDPSession(page);
    await touch.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ ...point(200, 700), id: 1 }] });
    await touch.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ ...point(270, 700), id: 1 }] });
    await page.waitForTimeout(1100); await snap('eve-xuanjia-field-manual-mobile');
    await touch.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await persisted(data => !data.world.docked && data.world.expedition_autopilot === false && Math.hypot(data.world.position[0] - start[0], data.world.position[1] - start[1]) > 10);
    await tap(530, 56); await persisted(data => data.world.expedition_autopilot === true);
    await page.waitForTimeout(1500); await snap('eve-xuanjia-field-auto-mobile');
    const beforeReload = await save();
    await page.reload(); await ready();
    const restored = await persisted(data => data.selected === 5 && data.selected_mech === 5 && data.unlocked.length === 6 && data.mechs.units.length === 6);
    assert.deepEqual(restored.unlocked, [true, true, true, true, true, true]);
    assert.equal(restored.gems, 0); assert.equal(restored.world.docked, false);
    assert.deepEqual(restored.parts.loadouts, beforeReload.parts.loadouts);
    assert.deepEqual(restored.mechs.units, beforeReload.mechs.units);
    await snap('expanded-roster-reload-mobile');
    assert.deepEqual(errors, []);
    fs.writeFileSync(path.join(output, 'browser-errors.json'), JSON.stringify(errors, null, 2));
    fs.writeFileSync(path.join(output, 'roster-acceptance.json'), JSON.stringify({
      selectedPilot: restored.selected, selectedChassis: restored.selected_mech, unlocked: restored.unlocked,
      crystalsAfterRecruitment: restored.gems, recruits: restored.recruits, chassisCount: restored.mechs.units.length,
      fieldContinuesAfterReload: !restored.world.docked, manualAndAutoVerified: true,
      trainingScreenshot: 'eve-training-skill-mobile.png', errors,
    }, null, 2));
    await context.close();
    console.log('ROSTER BROWSER PASS: six pilots/chassis, three directed recruits, independent selection, live 3D previews, ability sheets, training, real manual/auto field control and expanded save reload; no browser/Godot errors.');
  } catch (error) {
    if (page && !page.isClosed()) await page.screenshot({ path: path.join(output, 'failure.png') }).catch(() => {});
    fs.writeFileSync(path.join(output, 'browser-errors.json'), JSON.stringify(errors, null, 2));
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
