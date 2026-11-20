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
    const base = process.env.GAME_URL || 'http://localhost:8060';
    await page.route('**/__fixture', route => route.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>fixture writer</title>'}));
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
    async function fixture(weapon, armor, drive, core, mechanism) {
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
              save.stage = 1;
              save.sound = false;
              save.last_seen = Math.floor(Date.now() / 1000);
              save.world = {
                position: [544, 554], cleared: {}, explored: {},
                enemies: {'enemy:0:0': {hp: 100000, max: 100000}},
              };
              save.parts = {
                next_id: 18,
                loadouts: [Object.fromEntries(loadout.slice(0,4).map((id, slot) => [String(slot), id])), {}, {}],
                inventory: Array.from({length: 17}, (_, blueprint) => ({
                  id: blueprint + 1, blueprint, slot: blueprint<12?Math.floor(blueprint/3):blueprint<15?5:0, quality: 2, mechanism: blueprint+1===loadout[0]?loadout[4]:"",
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
      }, [weapon, armor, drive, core, mechanism]);
    }
 async function readSave(){return page.evaluate(async()=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;try{const d=JSON.parse(new TextDecoder().decode(records.rows[i].contents));db.close();return d}catch{}}
   }db.close();
  }
 })}

    for(const config of [
      {name:'continuous-ion',weapon:16,mechanism:'ion',delay:0},
      {name:'charged-pulse',weapon:16,mechanism:'pulse',delay:100},
      {name:'sweeping-beam',weapon:16,mechanism:'sweep',delay:0},
      {name:'homing-swarm',weapon:17,mechanism:'swarm',delay:850},
      {name:'proximity-blast',weapon:17,mechanism:'proximity',delay:950},
      {name:'burning-ground',weapon:17,mechanism:'incendiary',delay:1500},
    ].filter(config=>!process.env.MECHANISM_FILTER||process.env.MECHANISM_FILTER.split(',').some(term=>config.name.includes(term)))){
      // Stop the live engine before replacing its save; unload can otherwise overwrite the fixture.
      await page.goto(base+'/__fixture'); await page.waitForTimeout(1000);
      let applied=false;const deadline=Date.now()+25000;
      while(!applied&&Date.now()<deadline){applied=await fixture(config.weapon,4,7,11,config.mechanism);if(!applied)await page.waitForTimeout(500)}
      assert(applied,"initial save reached IndexedDB: "+JSON.stringify(errors));
      await page.goto(base);await ready();await tap(667,54);
      let loaded=false;const loadDeadline=Date.now()+20000;
      while(!loaded&&Date.now()<loadDeadline){const live=await readSave();loaded=live?.sound===true&&live?.world?.docked===false&&live?.parts?.loadouts?.[0]?.['0']===config.weapon&&live?.parts?.inventory?.find(p=>p.id===config.weapon)?.mechanism===config.mechanism;if(!loaded)await page.waitForTimeout(250)}
      assert(loaded,"live controller restored mechanism fixture: "+config.name+" "+JSON.stringify(errors));
      if(config.delay)await page.waitForTimeout(config.delay);
      await page.screenshot({path:`tests/mechanism-${config.name}-battle.png`});
      await tap(51,52);await tap(360,783);await tap(180,994);
      // Guided weapons have a long acquisition interval plus flight time; allow an actual hit and burn ticks.
      await page.waitForTimeout(config.weapon===17?5000:1800);
      await page.screenshot({path:`tests/mechanism-${config.name}-training.png`});
      console.log(`MECHANISM VISUAL PASS: ${config.name}, actual battle and training rendering`);
    }
    assert.deepEqual(errors,[],'all beam, missile and ground-effect branches render without runtime errors');
  }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
