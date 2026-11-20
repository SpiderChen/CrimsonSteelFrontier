const nav=require('./ui_navigation.cjs');
const assert=require('node:assert/strict');
const {chromium}=require('../tools/browser/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 const page=await context.newPage();const errors=[];const base=process.env.GAME_URL||'http://localhost:8060';
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text())});
 await page.route('**/__fixture',r=>r.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>fixture writer</title>'}));
 async function saveRecord(update){return page.evaluate(async(update)=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){
     if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;
     const row=records.rows[i],d=JSON.parse(new TextDecoder().decode(row.contents));
     if(update){
      d.stage=11;d.credits=10000;d.cores=1000;d.sound=false;d.last_seen=Math.floor(Date.now()/1000);
      d.world.docked=true;d.parts.research={};d.parts.reforge={};
      const item=(id,locked=false)=>({id,blueprint:0,slot:0,quality:2,mechanism:'bounce',level:1,locked,favorite:false,reforge_slot:-1,affixes:[{stat:'attack',value:18},{stat:'haste',value:6},{stat:'crit',value:6}]});
      d.parts.inventory.push(item(9001),item(9002),item(9003,true));
      d.parts.overflow=[{...item(9004),blueprint:16,mechanism:'swarm'}];d.parts.next_id=9005;
      row.contents=new TextEncoder().encode(JSON.stringify(d));row.timestamp=new Date();
      await new Promise((resolve,reject)=>{const t=db.transaction(name,'readwrite');t.objectStore(name).put(row,records.keys[i]);t.oncomplete=resolve;t.onerror=()=>reject(t.error)});
     }
     db.close();return d;
    }
   }db.close();
  }
 },update)}
 async function persisted(predicate){const end=Date.now()+25000;let d;while(Date.now()<end){d=await saveRecord(false);if(d&&predicate(d))return d;await page.waitForTimeout(250)}assert.fail(JSON.stringify({save:d,errors}))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 const firstPart=()=>tap(300,546),workshop=()=>tap(570,369);
 await page.goto(base);await ready();await nav.facility(tap,'hangar');await tap(180,900);await firstPart();
 await tap(271,369);
 const flags=await persisted(d=>d.parts.inventory[0].locked&&!d.parts.inventory[0].favorite);
 const original=structuredClone(flags.parts.inventory[0]);
 await workshop();await tap(360,575);
 const rolled=await persisted(d=>d.parts.reforge?.choices?.length===3);
 assert.equal(rolled.credits,2250);assert.equal(rolled.cores,112);
 await page.screenshot({path:'tests/workshop-reforge-mobile.png'});
 await page.reload();await ready();await nav.facility(tap,'hangar');await tap(180,900);await firstPart();await workshop();
 const restored=await persisted(d=>d.parts.reforge?.id===original.id);
 assert.deepEqual(restored.parts.reforge,rolled.parts.reforge,'pending choices survive reload without another charge');
 await tap(360,849);await persisted(d=>!d.parts.reforge?.id);
 const kept=await saveRecord(false);assert.deepEqual(kept.parts.inventory[0].affixes,original.affixes);
 await tap(360,575);const second=await persisted(d=>d.parts.reforge?.choices?.length===3);
 await tap(360,519);const chosen=await persisted(d=>!d.parts.reforge?.id&&d.credits===2100);
 assert.deepEqual(chosen.parts.inventory[0].affixes[0],second.parts.reforge.choices[0]);
 console.log('WORKSHOP BROWSER PASS: unified lock, paid reforge, refresh, retain old and select one proposal');
 // Stop the engine before installing a deterministic salvage/overflow scenario.
 await page.goto(base+'/__fixture');await page.waitForTimeout(1000);await saveRecord(true);
 await page.goto(base);await ready();await nav.sound(tap,() => saveRecord(false));await persisted(d=>d.sound&&d.stage===11&&d.parts.overflow.length===1);
 await nav.facility(tap,'hangar');await tap(180,900);await tap(190,1018);await tap(360,506);
 await page.screenshot({path:'tests/workshop-filter-mobile.png'});
 await tap(567,1018);await tap(210,286);await page.screenshot({path:'tests/workshop-batch-mobile.png'});await tap(360,1015);await tap(360,915);
 const salvaged=await persisted(d=>d.parts.research.bounce===6&&!d.parts.inventory.some(p=>p.id===9001||p.id===9002));
 assert(salvaged.parts.inventory.some(p=>p.id===9003&&p.locked));assert(salvaged.parts.inventory[0].locked);
 await tap(190,1018);await tap(360,326);await firstPart();await workshop();
 await tap(360,410);await persisted(d=>d.parts.inventory[0].level===2);
 await tap(360,410);const upgraded=await persisted(d=>d.parts.inventory[0].level===3);
 await tap(360,410);await page.waitForTimeout(500);assert.equal((await saveRecord(false)).credits,upgraded.credits,'disabled level cap does not charge');
 await tap(360,764);await page.screenshot({path:'tests/workshop-research-mobile.png'});await tap(523,606);
 const installed=await persisted(d=>d.parts.inventory[0].mechanism==='bounce');
 assert.equal(installed.credits,8700);assert.equal(installed.cores,986);
 assert.deepEqual(installed.parts.inventory[0].affixes,chosen.parts.inventory[0].affixes);
 await tap(360,1054);await tap(360,1054);await tap(624,217);await tap(51,52);await nav.facility(tap,'overflow');
 await page.screenshot({path:'tests/workshop-overflow-mobile.png'});await tap(360,993);
 const collected=await persisted(d=>d.parts.overflow.length===0&&d.parts.inventory.some(p=>p.id===9004));
 assert.equal(collected.parts.inventory.find(p=>p.id===9004).mechanism,'swarm');
 await page.reload();await ready();await nav.sound(tap,() => saveRecord(false));
 const final=await persisted(d=>d.sound===false&&d.parts.inventory[0].level===3&&d.parts.research.bounce===6);
 assert(final.parts.inventory[0].locked&&!final.parts.inventory[0].favorite);assert.equal(final.parts.inventory[0].mechanism,'bounce');
 assert.equal(final.parts.overflow.length,0);assert.equal(final.parts.inventory.filter(p=>p.id===9004).length,1);
 await nav.facility(tap,'hangar');await tap(180,900);await firstPart();await page.screenshot({path:'tests/workshop-restored-mobile.png'});
 assert.deepEqual(errors,[]);
 console.log('WORKSHOP BROWSER PASS: filtered batch salvage, protected items, research unlock/install, preserved upgrades/cap, overflow recovery and persistent results');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
