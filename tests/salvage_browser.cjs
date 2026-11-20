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
       d.selected=0;d.levels=[1,1,1];d.unlocked=[true,true,false];d.stage=1;d.credits=2400;d.cores=120;d.gems=900;d.hp=100;d.recovery=0;d.sound=false;
       d.world={docked:true,position:[384,384]};d.expedition={clears:[1,0,0,0],samples:[0,0,0,0],sequence:0,run:{},report:{}};
       const models={1:0,2:5,3:8,4:10,5:1,7:12};
       for(const p of d.parts.inventory){if(models[p.id]!==undefined){p.blueprint=models[p.id];p.quality=0;p.affixes=[{stat:'attack',value:3}];p.mechanism=[1,5].includes(p.id)?'pierce':'';p.level=1}}
       d.parts.research={};d.parts.research_materials=0;d.parts.overflow=[];
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
 async function persisted(predicate,timeout=30000){const end=Date.now()+timeout;let d;while(Date.now()<end){d=await saveRecord();if(d&&predicate(d))return d;await page.waitForTimeout(250)}await page.screenshot({path:'tests/salvage-failure-mobile.png'});assert.fail(JSON.stringify({save:d,errors}))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 async function fixture(mode,hours=0){await page.goto(base+'/__fixture');await page.waitForTimeout(1000);await saveRecord(mode,hours);await page.goto(base);await ready()}
 await page.goto(base);await ready();await nav.sound(tap,() => saveRecord());await persisted(d=>d.sound===false);
 await fixture('setup');
 await nav.facility(tap,'salvage');await page.screenshot({path:'tests/salvage-base-mobile.png'});await tap(511,798);
 await page.screenshot({path:'tests/salvage-certificates-empty-mobile.png'});await tap(360,510);
 const first=await persisted(d=>d.salvage?.certificates?.length===1,90000);
 const a=first.salvage.certificates[0];assert.equal(a.trials.length,3);assert(a.trials.every(t=>t.damage>0&&t.hits>0));
 assert.equal(first.credits,2400);assert.equal(first.cores,120);assert.equal(first.gems,900);assert.equal(first.hp,100);assert.equal(first.parts.inventory.length,7);assert.equal(first.expedition.clears[0],1);
 await page.screenshot({path:'tests/salvage-certification-result-mobile.png'});await tap(360,919);
 await persisted(d=>d.salvage.active_id===a.id);await tap(360,1093);
 // Change the live rig through the actual hangar. The enabled archive must remain unchanged.
 await nav.facility(tap,'hangar');await tap(180,779);await tap(300,468);await tap(240,967);
 const changed=await persisted(d=>!d.parts.loadouts[0]['0']);
 assert.equal(changed.salvage.active_id,a.id);assert.equal(changed.salvage.certificates[0].snapshot.parts.loadouts[0]['0'],1);
 await tap(624,217);await tap(51,52);await nav.facility(tap,'salvage');await page.screenshot({path:'tests/salvage-old-snapshot-mobile.png'});
 await tap(511,798);await tap(360,510);
 const second=await persisted(d=>d.salvage.certificates.length===2,90000);
 const b=second.salvage.certificates[1];assert(!b.snapshot.parts.loadouts[0]['0']);assert.equal(second.salvage.active_id,a.id);
 assert.notEqual(b.rates.credits,a.rates.credits,'real gear changes must affect measured automatic yield');
 console.log('SALVAGE BROWSER PASS: two real three-trial certifications, no simulation rewards, immutable active snapshot and changed live-rig performance');
 await tap(511,1006);await tap(360,1093);await tap(360,1093);
 // A 48-hour absence must retain the first scheme and produce 36 effective hours.
 await fixture('fresh-window',48);
 await tap(360,884);await tap(360,884);
 const accumulated=await persisted(d=>d.salvage.age>=172800&&d.salvage.auto_recycle===false&&d.last_seen>Date.now()/1000-20);
 const rowA=accumulated.salvage.rows.find(r=>r.id===a.id);assert(rowA);
 const weighted=t=>Math.min(t,86400)+0.5*Math.min(Math.max(0,t-86400),172800);
 assert(Math.abs(rowA.effective_seconds-weighted(accumulated.salvage.age))<0.0001);
 assert(rowA.effective_seconds>=129600&&rowA.effective_seconds<129900);
 assert.deepEqual(rowA.rates,a.rates);assert.equal(accumulated.salvage.active_id,a.id);
 await page.screenshot({path:'tests/salvage-48-hours-mobile.png'});
 await tap(511,798);await tap(360,764);await tap(360,853);
 const switched=await persisted(d=>d.salvage.active_id===b.id);const frozenA=switched.salvage.rows.find(r=>r.id===a.id);
 // Add one more real clock interval under scheme B; its tier budget is already in the half-rate band.
 await fixture('backdate',1);await tap(360,884);await tap(360,884);
 const split=await persisted(d=>d.salvage.active_id===b.id&&d.salvage.rows.some(r=>r.id===b.id&&r.effective_seconds>=1800)&&d.last_seen>Date.now()/1000-20);
 const old=split.salvage.rows.find(r=>r.id===a.id),next=split.salvage.rows.find(r=>r.id===b.id);
 assert(Math.abs(old.credits-frozenA.credits)<0.0001,'old scheme balance freezes after the switch');
 assert(next.effective_seconds>=1800&&next.effective_seconds<1950&&Math.abs(next.effective_seconds-next.raw_seconds*0.5)<0.0001,'new scheme shares the existing half-rate band');
 await tap(209,798);await page.screenshot({path:'tests/salvage-source-accounts-mobile.png'});await tap(360,1054);
 const baseInventory=split.parts.inventory.length+split.parts.overflow.length,baseCredits=split.credits,baseCores=split.cores,baseSamples=split.expedition.samples[0];
 await tap(360,982);
 const paid=await persisted(d=>d.salvage.claims>=1&&d.salvage.last_claim.parts>0);
 const receipt=paid.salvage.last_claim;
 assert.equal(paid.credits,baseCredits+receipt.credits);assert.equal(paid.cores,baseCores+receipt.cores);
 assert.equal(paid.parts.inventory.length+paid.parts.overflow.length,baseInventory+receipt.parts);
 assert.equal(paid.parts.research_materials,receipt.research);assert.equal(paid.expedition.samples[0],baseSamples+receipt.samples);
 assert(paid.parts.overflow.length>0,'rare offline equipment is protected when the main inventory fills');
 assert(receipt.sources.some(r=>r.id===a.id)&&receipt.sources.some(r=>r.id===b.id));
 const savedIds=new Set([...paid.parts.inventory,...paid.parts.overflow].map(p=>p.id));assert.equal(savedIds.size,baseInventory+receipt.parts);
 const newLoot=[...paid.parts.inventory,...paid.parts.overflow].filter(p=>p.id>=8);
 assert(newLoot.every(p=>[0,1,4,8].includes(p.blueprint)),'offline loot comes from its certified region');
 await page.screenshot({path:'tests/salvage-paid-mobile.png'});
 console.log('SALVAGE BROWSER PASS: 24/72 tier math, per-snapshot switching, exact multi-source claim, actual regional equipment, research, samples and full-inventory overflow');
 // Spend an earned research material through the actual mechanism research interface.
 const materials=paid.parts.research_materials;
 await tap(360,1093);await nav.facility(tap,'hangar');await tap(180,779);await tap(300,468);await tap(570,369);await tap(360,764);
 await page.screenshot({path:'tests/salvage-research-materials-mobile.png'});await tap(523,456);
 const studied=await persisted(d=>d.parts.research.pierce===6&&d.parts.research_materials===materials-6);
 const creditsAfter=studied.credits,gearAfter=studied.parts.inventory.length+studied.parts.overflow.length;
 await page.reload();await ready();await nav.sound(tap,() => saveRecord());
 const final=await persisted(d=>d.sound===true&&d.salvage.active_id===b.id);
 assert.equal(final.credits,creditsAfter);assert.equal(final.parts.inventory.length+final.parts.overflow.length,gearAfter);
 assert.equal(final.parts.research.pierce,6);assert.equal(final.parts.research_materials,materials-6);assert.equal(final.salvage.certificates.length,2);
 assert(final.salvage.last_claim.sources.some(r=>r.id===a.id)&&final.salvage.last_claim.sources.some(r=>r.id===b.id));
 await nav.facility(tap,'salvage');await tap(209,798);await tap(511,321);await page.screenshot({path:'tests/salvage-receipt-restored-mobile.png'});
 assert.deepEqual(errors,[]);
 console.log('SALVAGE BROWSER PASS: usable research investment, certificate/receipt restoration and no duplicate paid gear, currency or research after refresh');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
