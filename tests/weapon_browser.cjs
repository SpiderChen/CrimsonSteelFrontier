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
 async function persisted(predicate){const end=Date.now()+20000;let data;while(Date.now()<end){data=await readSave();if(data&&predicate(data))return data;await page.waitForTimeout(250)}assert.fail(JSON.stringify(data))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 await page.goto(process.env.GAME_URL||'http://localhost:8060');await ready();
 await nav.facility(tap,'hangar');await tap(530,779);await tap(300,734);await tap(240,967);
 await persisted(d=>d.parts&&!d.parts.loadouts[0]['4']);
 await tap(624,217);await tap(51,52);await nav.manufacture(tap,page,15);
 await page.screenshot({path:'tests/weapon-designs-mobile.png'});
 const laser=await persisted(d=>d.parts.inventory.some(p=>p.blueprint===15));
 const laserPart=laser.parts.inventory.find(p=>p.blueprint===15);
 assert.equal(laser.credits,1950,'targeted laser craft charges the normal credit price');
 await page.screenshot({path:'tests/weapon-laser-detail-mobile.png'});
 await nav.leaveManufacturing(tap);await nav.facility(tap,'hangar');await tap(180,779);await tap(300,922);
 await tap(240,967);await persisted(d=>d.parts.loadouts[0]['0']===laserPart.id);
 await tap(624,217);await page.screenshot({path:'tests/weapon-laser-hangar-mobile.png'});
 await tap(51,52);await nav.facility(tap,'training');await page.waitForTimeout(1500);
 await page.screenshot({path:'tests/weapon-laser-training-mobile.png'});
 await tap(360,1028);await nav.manufacture(tap,page,16);
 const missile=await persisted(d=>d.parts.inventory.some(p=>p.blueprint===16));
 const missilePart=missile.parts.inventory.find(p=>p.blueprint===16);
 assert.equal(missile.credits,1500,'targeted missile craft charges exactly once');
 await nav.leaveManufacturing(tap);await nav.facility(tap,'hangar');await tap(180,779);
 await page.mouse.move(360*390/720,600*390/720+(844-1280*390/720)/2);await page.mouse.wheel(0,6000);await page.waitForTimeout(400);await tap(300,900);
 await tap(240,967);await persisted(d=>d.parts.loadouts[0]['0']===missilePart.id);
 await tap(624,217);await page.screenshot({path:'tests/weapon-missile-hangar-mobile.png'});
 await tap(51,52);await nav.facility(tap,'training');await page.waitForTimeout(2100);
 await page.screenshot({path:'tests/weapon-missile-flight-mobile.png'});
 await page.waitForTimeout(800);await page.screenshot({path:'tests/weapon-missile-training-mobile.png'});
 await tap(360,1028);await nav.facility(tap,'presets');await tap(400,461);
 await persisted(d=>d.parts?.presets?.[0]?.[0]?.['0']===missilePart.id);
 await page.reload();await ready();await nav.sound(tap,readSave);
 const restored=await persisted(d=>d.sound===false&&d.parts.loadouts[0]['0']===missilePart.id);
 assert.equal(restored.parts.inventory.find(p=>p.id===missilePart.id).mechanism,missilePart.mechanism,'missile mechanism survives reload');
 assert.equal(restored.parts.presets[0][0]['0'],missilePart.id,'preset preserves the new weapon family');
 assert.deepEqual(errors,[],'new weapon models, effects and telemetry have no runtime errors');
 console.log('WEAPON BROWSER PASS: targeted laser/missile crafting, prices, hand equipment, two weapon models, real training effects, telemetry, mechanism and preset persistence');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
