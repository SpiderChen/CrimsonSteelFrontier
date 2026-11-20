// Exercise every drawing branch in an isolated browser profile using save fixtures.
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
    const ready = async () => {
      await page.waitForFunction(() => !document.querySelector('#status'), null, {timeout: 120000});
      await page.waitForTimeout(1200);
    };
    const tap = async (x, y) => {
      const scale = 390 / 720;
      await page.touchscreen.tap(x * scale, y * scale + (844 - 1280 * scale) / 2);
      await page.waitForTimeout(350);
    };
    await page.goto(process.env.GAME_URL || 'http://localhost:8060');
    await ready();
    await tap(667, 54);
    // Godot persists asynchronously; allow its initial real save to reach IndexedDB.
    await page.waitForTimeout(2500);
    async function fixture(weapon, armor, drive, core) {
      return page.evaluate(async (loadout) => {
        for (const entry of await indexedDB.databases()) {
          const db = await new Promise((resolve, reject) => {
            const request = indexedDB.open(entry.name);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
          });
          for (const name of db.objectStoreNames) {
            const records = await new Promise((resolve, reject) => {
              const store = db.transaction(name).objectStore(name);
              const rows = store.getAll(), keys = store.getAllKeys();
              let values, ids;
              const done = () => { if (values && ids) resolve({values, ids}); };
              rows.onsuccess = () => { values = rows.result; done(); };
              keys.onsuccess = () => { ids = keys.result; done(); };
              rows.onerror = keys.onerror = event => reject(event.target.error);
            });
            for (let i = 0; i < records.ids.length; i++) {
              if (!String(records.ids[i]).endsWith('/crimson_front_v1.json')) continue;
              const row = records.values[i];
              const save = JSON.parse(new TextDecoder().decode(row.contents));
              save.selected = 0;
              save.levels = [1, 1, 1];
              save.stage = 200;
              save.hp = 1;
              save.recovery = 0;
              save.sound = false;
              save.last_seen = Math.floor(Date.now() / 1000);
              save.world = {
                position: [544, 554], cleared: {}, explored: {},
                enemies: {'enemy:0:0': {hp: 100000, max: 100000}},
              };
              save.parts = {
                next_id: 13,
                loadouts: [Object.fromEntries(loadout.map((id, slot) => [String(slot), id])), {}, {}],
                inventory: Array.from({length: 12}, (_, blueprint) => ({
                  id: blueprint + 1, blueprint, slot: Math.floor(blueprint / 3), quality: 2,
                  affixes: [{stat: 'attack', value: 9}, {stat: 'speed', value: 6}, {stat: 'crit', value: 6}],
                })),
              };
              row.contents = new TextEncoder().encode(JSON.stringify(save));
              row.timestamp = new Date();
              await new Promise((resolve, reject) => {
                const transaction = db.transaction(name, 'readwrite');
                transaction.objectStore(name).put(row, records.ids[i]);
                transaction.oncomplete = resolve;
                transaction.onerror = () => reject(transaction.error);
              });
              db.close();
              return true;
            }
          }
          db.close();
        }
        return false;
      }, [weapon, armor, drive, core]);
    }
    async function readSave() {
      return page.evaluate(async()=>{
        for(const entry of await indexedDB.databases()) {
          const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
          for(const name of db.objectStoreNames) {
            const rows=await new Promise(resolve=>{const r=db.transaction(name).objectStore(name).getAll();r.onsuccess=()=>resolve(r.result)});
            for(const row of rows) if(row.contents) {
              try {const data=JSON.parse(new TextDecoder().decode(row.contents));if(data.version===1&&data.levels){db.close();return data}} catch {}
            }
          }
          db.close();
        }
      });
    }
    async function waitSave(predicate) {
      const end=Date.now()+20000;
      while(Date.now()<end){const data=await readSave();if(data&&predicate(data))return data;await page.waitForTimeout(200)}
      assert.fail('expected recovery state was not persisted');
    }
    assert(await fixture(1,4,7,11));
    await page.reload();await ready();
    const down=await waitSave(d=>d.hp===0&&d.recovery>0&&d.world.docked);
    assert.deepEqual(down.world.position,[384,384],'actual enemy damage recalls mech to the carrier');
    await page.screenshot({path:'tests/carrier-recovery-mobile.png'});
    await tap(360,1181);
    const recovered=await waitSave(d=>d.hp===100&&d.recovery<=0&&d.world.docked);
    assert.deepEqual(recovered.world.position,[384,384],'revival occurs at the carrier');
    await page.screenshot({path:'tests/carrier-revived-mobile.png'});
    await tap(360,1181);
    await waitSave(d=>d.world.docked===false);
    await page.screenshot({path:'tests/carrier-departure-mobile.png'});
    assert.deepEqual(errors,[],'carrier recovery and departure have no runtime errors');
    console.log('BASE BROWSER PASS: real enemy kills mech, automatic recall, recovery hub, launch blocked during repair, full-armor carrier revival, explicit departure');
  } finally {await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1});
