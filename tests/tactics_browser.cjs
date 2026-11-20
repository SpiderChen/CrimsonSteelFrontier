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
 async function saveRecord(armor){return page.evaluate(async(armor)=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){
     if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;
     const row=records.rows[i],d=JSON.parse(new TextDecoder().decode(row.contents));
     if(armor!==null){
      d.selected=0;d.stage=1;d.sound=false;d.hp=armor;d.recovery=0;d.heat=100;d.overheated=true;d.shield=20;d.temporary_shield=0;d.last_seen=Math.floor(Date.now()/1000);
      d.world={position:[544,554],docked:false,enemies:{'enemy:0:0':{hp:1000000,max:1000000}},ai:{'enemy:0:0':{position:[704,554],home:[704,554],mode:'guard',name:'重装精英',elite:true}},cleared:{},explored:{},shots:0,moving_shots:0};
      row.contents=new TextEncoder().encode(JSON.stringify(d));row.timestamp=new Date();
      await new Promise((resolve,reject)=>{const t=db.transaction(name,'readwrite');t.objectStore(name).put(row,records.keys[i]);t.oncomplete=resolve;t.onerror=()=>reject(t.error)});
     }
     db.close();return d;
    }
   }db.close();
  }
 },armor)}
 async function persisted(predicate){const end=Date.now()+25000;let d;while(Date.now()<end){d=await saveRecord(null);if(d&&predicate(d))return d;await page.waitForTimeout(250)}assert.fail(JSON.stringify({save:d,errors}))}
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 function screen(x,y){return{x:x*390/720,y:y*390/720+(844-1280*390/720)/2}}
 async function tap(x,y){const p=screen(x,y);await page.touchscreen.tap(p.x,p.y);await page.waitForTimeout(350)}
 const expected={target:'elite',distance:'far',heat:'conserve',survival:'withdraw',skill:'elite'};
 await page.goto(base);await ready();await nav.facility(tap,'tactics');
 await tap(440,325);await tap(440,325);await tap(440,453);await tap(440,453);
 await tap(440,581);await tap(440,709);await tap(440,837);
 const configured=await persisted(d=>d.tactics?.[0]?.skill==='elite');assert.deepEqual(configured.tactics[0],expected);
 await page.screenshot({path:'tests/tactics-settings-mobile.png'});
 await tap(360,1066);await nav.facility(tap,'presets');await tap(400,461);
 await persisted(d=>d.tactic_presets?.[0]?.[0]?.distance==='far');await tap(624,337);
 await nav.facility(tap,'tactics');await tap(440,325);await tap(440,453);await tap(440,581);await tap(360,1066);
 await nav.facility(tap,'presets');await tap(400,601);
 await persisted(d=>d.tactic_presets?.[0]?.[1]?.heat==='alternate');await tap(560,461);
 const applied=await persisted(d=>d.tactics[0].heat==='conserve');assert.deepEqual(applied.tactics[0],expected);
 await tap(624,337);await nav.facility(tap,'training');await tap(360,377);await page.waitForTimeout(10000);
 await page.screenshot({path:'tests/tactics-training-mobile.png'});await tap(360,1028);
 console.log('TACTICS BROWSER PASS: all five controls, independent saved loadout policies, restoration and actual group training');
 // Use a stopped engine to install a durable enemy, then exercise real autonomous movement and manual takeover.
 await page.goto(base+'/__fixture');await page.waitForTimeout(1000);await saveRecord(100);
 await page.goto(base);await ready();await tap(526,56);await page.waitForTimeout(3500);await nav.sound(tap,() => saveRecord(null));
 const moved=await persisted(d=>d.sound===true&&d.world.docked===false&&d.world.shots>0&&Math.hypot(d.world.position[0]-544,d.world.position[1]-554)>30);
 assert(moved.heat<=100);assert.deepEqual(moved.tactics[0],expected);assert.equal(moved.world.ai['enemy:0:0'].elite,true);
 await page.screenshot({path:'tests/tactics-field-mobile.png'});
 const start=screen(230,820),end=screen(330,820);const touch=await context.newCDPSession(page);
 await touch.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...start,id:1}]});
 await touch.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...end,id:1}]});await page.waitForTimeout(650);
 await touch.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(400);
 await nav.sound(tap,() => saveRecord(null));const stopped=await persisted(d=>d.sound===false);
 await page.waitForTimeout(900);await nav.sound(tap,() => saveRecord(null));const still=await persisted(d=>d.sound===true);
 assert(Math.hypot(still.world.position[0]-stopped.world.position[0],still.world.position[1]-stopped.world.position[1])<2,'releasing manual control cancels the automatic distance route');
 console.log('TACTICS BROWSER PASS: real field distance movement, heat policy, actual shots and manual release without drift');
 await page.goto(base+'/__fixture');await page.waitForTimeout(1000);await saveRecord(25);
 await page.goto(base);await ready();await tap(526,56);await nav.sound(tap,() => saveRecord(null));
 const withdrawn=await persisted(d=>d.sound===true&&d.world.docked===true&&d.hp===100);
 assert.deepEqual(withdrawn.tactics[0],expected);await page.screenshot({path:'tests/tactics-withdrawal-mobile.png'});
 await page.reload();await ready();await nav.sound(tap,() => saveRecord(null));
 const final=await persisted(d=>d.sound===false&&d.world.docked===true);
 assert.deepEqual(final.tactics[0],expected);assert.deepEqual(final.tactic_presets[0][0],expected);assert.equal(final.tactic_presets[0][1].heat,'alternate');
 await nav.facility(tap,'tactics');await page.screenshot({path:'tests/tactics-restored-mobile.png'});
 assert.deepEqual(errors,[]);
 console.log('TACTICS BROWSER PASS: critical armor recalls to the carrier, repairs and preserves policies/presets across reload');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
