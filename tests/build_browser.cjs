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
 await page.screenshot({path:'tests/build-base-mobile.png'});
 await nav.facility(tap,'hangar');await page.screenshot({path:'tests/rig-six-slots-mobile.png'});
 await tap(530,779);await page.screenshot({path:'tests/rig-right-inventory-mobile.png'});
 await tap(300,546);await tap(240,967);
 await persisted(d=>d.parts?.loadouts?.[0]?.['4']===1&&!d.parts.loadouts[0]['0']);
 await page.screenshot({path:'tests/rig-change-hand-mobile.png'});
 await tap(422,967);await tap(240,967);
 await persisted(d=>d.parts?.loadouts?.[0]?.['0']===1&&!d.parts.loadouts[0]['4']);
 await tap(300,1054);await tap(300,734);await tap(422,967);await tap(240,967);
 await persisted(d=>d.parts?.loadouts?.[0]?.['4']===5&&d.parts.loadouts[0]['0']===1);
 await tap(624,217);await tap(530,701);await tap(300,546);
 await page.screenshot({path:'tests/rig-backpack-detail-mobile.png'});
 await tap(240,967);await persisted(d=>d.parts&&!d.parts.loadouts[0]['5']);
 await tap(240,967);await persisted(d=>d.parts?.loadouts?.[0]?.['5']===7);
 await tap(624,217);await tap(51,52);
 await nav.facility(tap,'training');await page.waitForTimeout(2000);await page.screenshot({path:'tests/training-single-mobile.png'});
 await tap(360,377);await page.waitForTimeout(2000);await page.screenshot({path:'tests/training-group-mobile.png'});
 await tap(560,377);await page.waitForTimeout(2000);await page.screenshot({path:'tests/training-survival-mobile.png'});
 await tap(360,1028);await nav.facility(tap,'presets');await tap(400,461);await tap(560,461);
 await page.screenshot({path:'tests/presets-mobile.png'});
 await persisted(d=>d.parts?.presets?.[0]?.[0]?.['0']===1);
 await page.reload();await ready();await nav.facility(tap,'presets');await page.screenshot({path:'tests/presets-restored-mobile.png'});
 await tap(624,337);await nav.sound(tap,readSave);
 const saved=await persisted(d=>d.sound===false&&d.parts?.presets?.[0]?.[0]?.["0"]===1);
 assert(saved.parts.presets[0][0]['0']===1,'preset holds the starter weapon after reload');
 assert(Object.keys(saved.parts.presets[0][0]).length===6,'six-slot preset survives browser storage');
 assert(saved.parts.loadouts[0]['4']===5&&saved.parts.loadouts[0]['5']===7,'secondary weapon and backpack survive reload');
 assert(saved.parts.inventory[0].mechanism==='pierce','random mechanism survives browser storage');
 assert.equal(saved.hp,100,'survival training does not consume real player armor');
 assert.equal(saved.recovery,0,'training defeat does not trigger real recovery');
 assert.deepEqual(errors,[],'no rendering or runtime errors');
 console.log('BUILD BROWSER PASS: six slots, weapon hand transfer, backpack equip/unequip, independent thermal training, six-slot persistence, three training scenarios, preset save/apply/reload, mechanism persistence, no runtime errors');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
