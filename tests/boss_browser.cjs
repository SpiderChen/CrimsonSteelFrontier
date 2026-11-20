const nav=require('./ui_navigation.cjs');
const assert=require('node:assert/strict');
const {chromium}=require('../tools/browser/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});const page=await context.newPage();const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text())});
 async function readSave(){return page.evaluate(async()=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;try{const d=JSON.parse(new TextDecoder().decode(records.rows[i].contents));db.close();return d}catch{}}
   }db.close();
  }
 })}
 async function persisted(predicate,timeout=20000){const end=Date.now()+timeout;let data;while(Date.now()<end){data=await readSave();if(data&&predicate(data))return data;await page.waitForTimeout(250)}assert.fail(JSON.stringify(data))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 const gameUrl=process.env.GAME_URL||'http://localhost:8060';
 await page.goto(gameUrl);await ready();await nav.sound(tap,readSave);
 await nav.facility(tap,'regions');await tap(360,339);await tap(360,749);
 const landing=await persisted(d=>d.expedition?.run?.schema===2&&!d.world.docked);
 // Native region_checks covers walking to every boss. Stage H5 exploration saves
 // near possible lairs to test discovery, explicit challenge, rendering and reload.
 async function stage(fixture){
  await page.goto(new URL('/index.js',gameUrl).href);await page.waitForTimeout(600);
  await page.evaluate(async save=>{
   for(const entry of await indexedDB.databases()){
    const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
    for(const name of db.objectStoreNames){
     const data=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name),r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
     for(let i=0;i<data.keys.length;i++){
      if(!String(data.keys[i]).endsWith('/crimson_front_v1.json'))continue;
      const record=data.rows[i];record.contents=new TextEncoder().encode(JSON.stringify(save));record.timestamp=new Date();
      await new Promise((resolve,reject)=>{const tx=db.transaction(name,'readwrite');tx.objectStore(name).put(record,data.keys[i]);tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error)});
      db.close();return;
     }
    }db.close();
   }throw new Error('Test save not found');
  },fixture);
  await page.goto(gameUrl);await ready();
 }
 let found=false;
 for(const position of (landing.expedition.run.layout===2 ? [[440,-3072],[5944,-3072],[5944,1024],[3128,-3200]] : [[2552,-704],[2552,1088],[376,-704]])){
  const fixture=structuredClone(landing);fixture.world.position=position;fixture.world.expedition_autopilot=false;fixture.levels=[3,3,1];
  await stage(fixture);await nav.sound(tap,readSave);
  const probe=await persisted(d=>d.sound===true&&d.expedition?.run?.schema===2);
  found=probe.expedition.run.discovered.includes(`map:${probe.expedition.run.id}:boss`);
  if(found)break;
 }
 assert(found,'a boss is revealed by physical proximity');
 const discovered=await readSave();assert.equal(discovered.world.boss.active,false,'discovery does not force combat');
 await page.screenshot({path:'tests/boss-mission-mobile.png'});
 await tap(508,1056);await tap(360,691);
 const initial=await persisted(d=>d.world?.boss?.active);
 await page.screenshot({path:'tests/boss-phase-one-mobile.png'});
 await nav.bossTarget(tap,'cannon');
 const before=await persisted(d=>d.world?.boss?.active&&d.world.boss.selected==='cannon');
 await page.reload();await ready();await page.screenshot({path:'tests/boss-restored-mobile.png'});
 const resumed=await persisted(d=>d.world?.boss?.active);
 assert.equal(resumed.world.boss_autopilot,true,'automatic boss tactics survive reload');
 assert(resumed.world.boss.phase>=before.world.boss.phase,'boss phase persists through reload');
 assert(resumed.world.boss.parts.tracks<=before.world.boss.parts.tracks,'broken parts do not regenerate on reload');
 await nav.bossTarget(tap,'auto');
 await persisted(d=>d.world?.boss?.selected==='auto');
 const win=await persisted(d=>d.world?.boss?.victories===1&&d.world?.docked===true,180000);
 assert.equal(win.hp,100,'boss victory returns to the carrier with full armor');
 assert(win.credits>=initial.credits+900,'boss reward and dungeon bounty are settled');
 assert.equal(win.cores,initial.cores+30,'one boss alloy reward');
 assert.equal(win.expedition.report.outcome,'cleared','boss completes its explored map');
 assert.equal(win.expedition.clears[0],1,'first map clears once');
 assert.equal(win.gems,initial.gems+200,'first-clear gem reward');
 assert.equal(win.parts.inventory.length,initial.parts.inventory.length+1,'boss grants one epic part');
 assert.equal(win.parts.inventory.at(-1).quality,2);
 assert.equal(win.parts.inventory.at(-1).mechanism,'pierce');
 await page.screenshot({path:'tests/boss-victory-mobile.png'});
 assert.deepEqual(errors,[],'no boss rendering or runtime errors');
 console.log('BOSS BROWSER PASS: free map discovery, explicit challenge, real auto combat, target switching, phase progression, reload with broken parts, full encounter victory, single rewards and carrier return');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
