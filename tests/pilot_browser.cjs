const nav=require('./ui_navigation.cjs');
const assert=require('node:assert/strict');
const {chromium}=require('../tools/browser/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 const page=await context.newPage(),errors=[],base=process.env.GAME_URL||'http://localhost:8060';
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text())});
 await page.route('**/__fixture',r=>r.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>fixture writer</title>'}));
 async function saveRecord(mode=null,hours=0){return page.evaluate(async({mode,hours})=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){
     if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;
     const row=records.rows[i],d=JSON.parse(new TextDecoder().decode(row.contents));
     if(mode){
      const now=Date.now()/1000;
      if(mode==='setup'){
       d.selected=0;d.unlocked=[true,true,true];d.hp=100;d.recovery=0;d.sound=false;d.credits=2400;d.cores=120;d.gems=900;
       d.world={docked:true,position:[384,384]};d.expedition={clears:[0,0,0,0],samples:[0,0,0,0],sequence:0,run:{},report:{}};
       d.pilot_runtime={};
       d.narrative={...d.narrative,active:'',cursor:0,pending:[],tutorial:false};
       d.pilot_roster={trust:hours?[25,25,25]:[0,0,0],metrics:hours?[{nodes:3,vented:120,bosses:2},{nodes:3,marked_damage:1500,bosses:2},{nodes:3,support:100,bosses:2}]:[{},{},{}],claimed:[[],[],[]],heard:[[],[],[]]};
       d.parts.loadouts[1]=JSON.parse(JSON.stringify(d.parts.loadouts[0]));d.parts.loadouts[2]=JSON.parse(JSON.stringify(d.parts.loadouts[0]));
       d.salvage={version:1,cursor:now,age:0,sequence:0,certificates:[],active_id:'base',rows:[],claims:0,last_claim:{},auto_recycle:false};
      }else{
       d.salvage.cursor=now-hours*3600;
       if(mode==='fresh-window'){d.salvage.age=0;d.salvage.rows=[]}
      }
      d.last_seen=now-hours*3600;
      row.contents=new TextEncoder().encode(JSON.stringify(d));row.timestamp=new Date();
      await new Promise((resolve,reject)=>{const t=db.transaction(name,'readwrite');t.objectStore(name).put(row,records.keys[i]);t.oncomplete=resolve;t.onerror=()=>reject(t.error)});
     }
     db.close();return d;
    }
   }db.close();
  }
 },{mode,hours})}
 async function persisted(predicate,timeout=30000){const end=Date.now()+timeout;let d;while(Date.now()<end){d=await saveRecord();if(d&&predicate(d))return d;await page.waitForTimeout(250)}await page.screenshot({path:'tests/pilot-failure-mobile.png'});assert.fail(JSON.stringify({save:d,errors}))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 async function fixture(progress){await page.goto(base+'/__fixture');await page.waitForTimeout(800);await saveRecord('setup',progress?1:0);await page.goto(base);await ready()}
 async function pilots(){await tap(51,52);await nav.facility(tap,'pilots')}
 await page.goto(base);await ready();await tap(610,74);await nav.sound(tap,() => saveRecord());await persisted(d=>d.sound===false);await fixture(false);await pilots();
 await tap(180,1111);await page.screenshot({path:'tests/pilot-scarlet-abilities-mobile.png'});await tap(624,187);
 await tap(540,1111);await page.screenshot({path:'tests/pilot-initial-tasks-mobile.png'});await tap(360,942);
 const first=await persisted(d=>d.pilot_roster?.trust[0]===2);assert.deepEqual(first.pilot_roster.heard[0],[0]);
 await page.screenshot({path:'tests/pilot-first-conversation-mobile.png'});await tap(610,74);await tap(360,942);
 const replay=await saveRecord();assert.equal(replay.pilot_roster.trust[0],2);assert.equal(replay.credits,2400);
 await tap(610,74);await tap(360,1006);assert.equal((await saveRecord()).pilot_roster.trust[0],2);
 console.log('PILOT BROWSER PASS: first conversation grants trust once, replay does not farm trust, higher conversations stay locked');
 await fixture(true);
 for(let i=0;i<3;i++){
  await pilots();await tap(132+i*228,309);await tap(180,1029);await persisted(d=>d.selected===i);
  if((await saveRecord()).narrative?.active)await tap(610,74);
  await tap(180,1111);await page.screenshot({path:`tests/pilot-${i}-abilities-mobile.png`});await tap(624,187);
  await tap(540,1111);
  for(let chapter=0;chapter<3;chapter++){
   await tap(570,447+chapter*151);await persisted(d=>d.pilot_roster.claimed[i].length===chapter+1);
   await page.screenshot({path:`tests/pilot-${i}-story-${chapter}-mobile.png`});await tap(610,74);
  }
  const reward=await persisted(d=>d.pilot_roster.trust[i]===40);assert.equal(reward.credits,2400+600*(i+1));assert.equal(reward.parts.research_materials,3*(i+1));
  await tap(570,447);assert.equal((await saveRecord()).credits,reward.credits);await tap(610,74);
  await tap(360,1070);await persisted(d=>d.pilot_roster.heard[i].includes(2));await page.screenshot({path:`tests/pilot-${i}-trust-conversation-mobile.png`});await tap(610,74);await tap(624,167);
  await page.screenshot({path:`tests/pilot-${i}-badge-mobile.png`});
  await tap(51,52);await nav.facility(tap,'training');await tap(318,380);await page.waitForTimeout(12000);
  await page.screenshot({path:`tests/pilot-${i}-training-skill-mobile.png`});await tap(624,257);
  console.log(`PILOT BROWSER PASS: pilot ${i} dossier, three task rewards/stories, trust conversation, cockpit badge and real training skill render`);
 }
 const before=await saveRecord();await page.reload();await ready();await pilots();await tap(588,309);await tap(540,1111);
 const after=await saveRecord();assert.deepEqual(after.pilot_roster,before.pilot_roster);assert.equal(after.credits,before.credits);assert.equal(after.parts.research_materials,before.parts.research_materials);
 await page.screenshot({path:'tests/pilot-reload-tasks-mobile.png'});assert.deepEqual(errors,[]);
 console.log('PILOT BROWSER PASS: completed rewards, trust and read conversations survive IndexedDB reload without duplicate rewards; no browser errors');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
