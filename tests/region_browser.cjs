const nav=require('./ui_navigation.cjs');
const assert=require('node:assert/strict');
const {chromium}=require('../tools/browser/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 const page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text())});
 async function readSave(){return page.evaluate(async()=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){
     if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;
     const d=JSON.parse(new TextDecoder().decode(records.rows[i].contents));db.close();return d;
    }
   }db.close();
  }
 })}
 async function persisted(predicate,timeout=30000){const end=Date.now()+timeout;let d;while(Date.now()<end){d=await readSave();if(d&&predicate(d))return d;await page.waitForTimeout(500)}await page.screenshot({path:'tests/region-failure-mobile.png'});assert.fail(JSON.stringify({save:d,errors}))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 await page.goto(process.env.GAME_URL||'http://localhost:8060');await ready();await nav.sound(tap,readSave);
 await nav.facility(tap,'regions');await page.screenshot({path:'tests/regions-mobile.png'});
 await tap(360,339);await tap(360,664);await tap(360,749);
 const initial=await persisted(d=>d.expedition?.run?.schema===2&&d.world.docked===false);
 assert.equal(initial.expedition.run.focus,0);assert.equal(initial.expedition.run.phase,'explore');
 for(const key of ['route','step','auto'])assert(!(key in initial.expedition.run));
 assert.equal(initial.world.boss.active,false);
 const bossId=`map:${initial.expedition.run.id}:boss`;
 assert(!initial.expedition.run.discovered.includes(bossId));
 await page.screenshot({path:'tests/free-exploration-landing.png'});
 await page.waitForTimeout(5000);await nav.sound(tap,readSave);
 const stationary=await persisted(d=>d.sound===true);
 assert.deepEqual(stationary.world.position,initial.world.position,'waiting never explores the map automatically');
 assert.deepEqual(stationary.expedition.run.discovered,initial.expedition.run.discovered);
 // The first supply is east and north of the landing zone, in cleared terrain.
 await page.keyboard.down('KeyD');await page.keyboard.down('KeyW');await page.waitForTimeout(740);
 await page.keyboard.up('KeyW');await page.waitForTimeout(600);await page.keyboard.up('KeyD');
 await page.waitForTimeout(400);await tap(508,1056);
 await page.screenshot({path:'tests/free-exploration-supply.png'});await tap(360,780);
 const supplied=await persisted(d=>d.expedition?.run?.used?.length===1);
 assert(supplied.cores>=initial.cores+12);assert(supplied.expedition.run.bounty>=80);
 const visited=supplied.expedition.run.visited,seed=supplied.expedition.run.seed;
 await page.reload();await ready();await nav.sound(tap,readSave);
 const restored=await persisted(d=>d.sound===false&&d.expedition?.run?.used?.length===1);
 assert.equal(restored.expedition.run.seed,seed);assert.deepEqual(restored.expedition.run.visited,visited);
 assert(restored.expedition.run.bounty>=supplied.expedition.run.bounty);assert.equal(restored.world.boss.active,false);
 assert(!restored.expedition.run.discovered.includes(bossId),'nearby supply never reveals a distant boss');
 await tap(137,170);await page.screenshot({path:'tests/free-exploration-overview.png'});
 await tap(360,896);
 const banked=await persisted(d=>d.world.docked===true&&d.expedition.report.outcome==='withdrawn');
 assert(banked.credits>=initial.credits+banked.expedition.report.bounty);assert(banked.expedition.report.bounty>=80);
 assert.deepEqual(errors,[]);
 console.log('FREE EXPLORATION BROWSER PASS: one launch, stationary fog, real manual travel, nearby supply interaction, stable seed/fog/used sites on reload and one bounty settlement');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
