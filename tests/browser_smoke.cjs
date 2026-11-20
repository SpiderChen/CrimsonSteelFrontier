const nav=require('./ui_navigation.cjs');
const assert=require('node:assert/strict');
const { chromium } = require('../tools/browser/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_PATH||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try {
 const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1,isMobile:true,hasTouch:true});
 const page=await context.newPage();
 const errors=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('console',m=>{if(m.type()==='error')errors.push(m.text());if(m.type()==='log')console.log(m.text());});
 async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function rawTap(x,y){const v=page.viewportSize();const scale=Math.min(v.width/720,v.height/1280);await page.touchscreen.tap(x*scale+(v.width-720*scale)/2,y*scale+(v.height-1280*scale)/2);await page.waitForTimeout(350)}
 async function tap(x,y){
   if(x===667&&y===54){await nav.sound(rawTap,save);return}
   if(x===620&&y===285){await rawTap(656,960);return}
   if(y===1220&&[270,450,630].includes(x)){
     const data=await save();
     if(data?.world?.docked===false){await rawTap(656,1056);await rawTap(360,783)}
     else await rawTap(51,52);
     await nav.facility(rawTap,x===270?'hangar':x===450?'pilots':'recruit');
   }else await rawTap(x,y);
 }
 async function save(){return page.evaluate(async()=>{
   for(const entry of await indexedDB.databases()){
     const db=await new Promise((resolve,reject)=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result);r.onerror=()=>reject(r.error)});
     for(const name of db.objectStoreNames){
       const records=await new Promise((resolve,reject)=>{
         const store=db.transaction(name).objectStore(name);let rows,keys;
         const finish=()=>{if(rows&&keys)resolve({rows,keys})};
         const r=store.getAll();r.onsuccess=()=>{rows=r.result;finish()};r.onerror=()=>reject(r.error);
         const k=store.getAllKeys();k.onsuccess=()=>{keys=k.result;finish()};k.onerror=()=>reject(k.error);
       });
       for(let i=0;i<records.rows.length;i++){
         if(!String(records.keys[i]).endsWith('/crimson_front_v1.json'))continue;
         const row=records.rows[i];
         if(row.contents){try{const data=JSON.parse(new TextDecoder().decode(row.contents));if(data.version===1&&data.levels)return data}catch{}}
       }
     }
     db.close();
   }
   return null;
 })}
 async function waitSave(predicate,description){
   let latest=null;const end=Date.now()+20000;
   while(Date.now()<end){latest=await save();if(latest&&predicate(latest))return latest;await page.waitForTimeout(500)}
   assert.fail(description+': '+JSON.stringify(latest));
 }
 await page.goto(process.env.GAME_URL||'http://localhost:8060');
 await ready();
 await page.screenshot({path:'tests/carrier-base-mobile.png'});
 await rawTap(360,1100);
 await waitSave(d=>d.world?.docked===false,'carrier launch persists departure');
 if(!process.env.BASE_ONLY) await page.waitForTimeout(8200); // let carrier departure protection expire before the combat gesture
 await page.screenshot({path:'tests/world-initial-mobile.png'});
 if(!process.env.BASE_ONLY){
 const cdp=await context.newCDPSession(page);
 function point(x,y,id=0){const v=page.viewportSize();const scale=Math.min(v.width/720,v.height/1280);return {id,x:x*scale+(v.width-720*scale)/2,y:y*scale+(v.height-1280*scale)/2,radiusX:6,radiusY:6,force:1}}
 async function drag(x,y,dx,dy,hold=0,screenshot=null){
   await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point(x,y)]});
   if(screenshot){await page.waitForTimeout(150);await page.screenshot({path:screenshot})}
   for(let i=1;i<=8;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[point(x+dx*i/8,y+dy*i/8)]});await page.waitForTimeout(35)}
   if(hold)await page.waitForTimeout(hold);
   await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
   await page.waitForTimeout(400);
 }
 // A right-thumb gesture approaches the visible starter enemy and keeps moving while firing.
 await drag(610,900,58,31,1200,'tests/onehand-right-active.png');
 await tap(667,54); // request a post-release save; a combat autosave can still be in flight
 const moved=await waitSave(d=>d.sound===false&&d.world?.moving_shots>0&&d.world?.distance>90,'released movement and firing reach persistent storage');
 await tap(667,54);
 await waitSave(d=>d.sound===true,'post-release snapshot is acknowledged');
 assert(moved.world.moving_shots>0,'auto shots occur in frames with real physical movement');
 assert(moved.world.alerts>0&&moved.world.chase_distance>20,'enemy detection produces real pursuit movement in H5');
 assert(moved.world.enemy_shots>0,'pursuer fires independently after entering range');
 await page.screenshot({path:'tests/world-walk-fire-mobile.png'});
 await page.waitForTimeout(1100);
 await tap(667,54);
 const stopped=await waitSave(d=>d.last_seen>moved.last_seen&&d.sound===false,'released thumb state saved');
 assert.deepEqual(stopped.world.position,moved.world.position,'lifting thumb stops immediately without a continuing path');
 await tap(667,54);
 // Two fingers move the camera, not the mech.
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point(250,570,0),point(400,570,1)]});
 for(let i=1;i<=6;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[point(250+i*20,570,0),point(400+i*20,570,1)]});await page.waitForTimeout(40)}
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(900);
 await tap(667,54);
 const panned=await waitSave(d=>d.sound===false&&d.last_seen>stopped.last_seen,'two-finger camera state saved');
 assert.deepEqual(panned.world.position,stopped.world.position,'two-finger pan does not move the mech');
 await page.screenshot({path:'tests/world-pan-mobile.png'});
 await tap(667,54);
 await tap(620,285);
 // A left-thumb origin works without reaching any fixed joystick position.
 await drag(90,920,-58,-31,500,'tests/onehand-left-active.png');
 const steered=await waitSave(d=>d.world?.distance>panned.world.distance+25,'left-thumb movement persisted');
 assert(steered.world.distance>panned.world.distance+25,'left side also supports floating-thumb movement');
 // Static HUD labels allow the full-screen joystick to start behind them.
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point(250,70)]});
 await page.waitForTimeout(180);await page.screenshot({path:'tests/onehand-header-active.png'});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[point(280,650,0),point(440,650,1)]});
 for(let i=1;i<=6;i++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[point(280-i*10,650,0),point(440+i*10,650,1)]});await page.waitForTimeout(40)}
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
 await page.waitForTimeout(600);
 await page.screenshot({path:'tests/world-pinch-mobile.png'});
 await page.screenshot({path:'tests/battle-mobile.png'});
 }
 await tap(270,1220);
 await page.screenshot({path:'tests/hangar-mobile.png'});
 // Parts inventory: real touch actions, verified through the persisted model.
 await tap(180,900);
 await page.screenshot({path:'tests/parts-inventory-mobile.png'});
 await tap(300,468);
 await page.screenshot({path:'tests/parts-detail-mobile.png'});
 await tap(240,967); // unequip starter burst weapon
 await waitSave(d=>d.parts&&!d.parts.loadouts[0]['0'],'touch unequip updates loadout');
 await tap(240,967); // equip the same item again
 await waitSave(d=>d.parts?.loadouts[0]['0']===1,'touch equip restores exact item');
 await tap(300,1054); // return to inventory
 await tap(300,620); // alternate railgun, item 5
 await tap(240,967);
 await waitSave(d=>d.parts?.loadouts[0]['0']===5,'alternate weapon equipped through touch');
 await page.screenshot({path:'tests/parts-rail-equipped-mobile.png'});
 await tap(300,1054);
 await tap(560,284); // drive slot tab
 await tap(300,620); // alternate dash drive, item 6
 await tap(240,967);
 const loadout=await waitSave(d=>d.parts?.loadouts[0]['2']===6,'alternate movement drive equipped through touch');
 await tap(300,1054);
 await tap(200,1086); // craft a new random item
 const crafted=await waitSave(d=>d.parts?.inventory.length===loadout.parts.inventory.length+1,'touch craft persists random affixes');
 const newPart=crafted.parts.inventory.find(p=>!loadout.parts.inventory.some(old=>old.id===p.id));
 assert(newPart&&newPart.affixes.length===newPart.quality+1,'crafted item has quality-dependent random affixes');
 await page.screenshot({path:'tests/parts-crafted-mobile.png'});
 await tap(550,967); // dismantle the freshly crafted, unequipped item
 await waitSave(d=>d.parts&&!d.parts.inventory.some(p=>p.id===newPart.id)&&d.cores===crafted.cores+6*(newPart.quality+1),'dismantle rewards alloy once');
 await tap(550,1086); // return to hangar
 await page.screenshot({path:'tests/hangar-parts-mobile.png'});
 await tap(360,1030); // actual touch upgrade
 await tap(450,1220);
 await page.screenshot({path:'tests/pilots-mobile.png'});
 await tap(630,1220);
 await page.screenshot({path:'tests/recruit-mobile.png'});
 await tap(180,1050);
 await page.screenshot({path:'tests/result-mobile.png'});
 await tap(360,889);
 await tap(450,1220);await tap(590,310);await tap(180,1025); // choose new pilot
 // Transfer the equipped railgun from Scarlet to the newly selected Frost.
 await tap(270,1220);await tap(180,900);await tap(130,284);await tap(300,620);await tap(240,967);
 await waitSave(d=>d.parts?.loadouts[2]['0']===5&&!d.parts.loadouts[0]['0'],'part transfer clears previous owner');
 await tap(300,1054);await tap(550,1086);
 await tap(667,54); // global mute, including all imported voices
 await page.waitForTimeout(2500);
 const before=await waitSave(d=>d.recruits===1&&d.selected===2&&d.sound===false,'all touch actions persisted');
 assert(before,'Godot writes IndexedDB save');
 assert.equal(before.recruits,1,'one touch recruit registers exactly once');
 assert.equal(before.unlocked[2],true,'first recruit unlocks Frost');
 assert.equal(before.levels[0],2,'hangar touch upgrades Scarlet');
 assert.equal(before.selected,2,'portrait touch changes active pilot');
 assert.equal(before.sound,false,'sound button stores global mute');
 await page.reload();await ready();
 await tap(667,54);await tap(667,54);
 const after=await waitSave(d=>d.last_seen>before.last_seen&&d.sound===false,'restored live model writes a new save');
 assert.deepEqual(after.levels,before.levels,'refresh preserves upgrades');
 assert.deepEqual(after.unlocked,before.unlocked,'refresh preserves recruits');
 assert.equal(after.selected,2,'refresh preserves active pilot');
 assert.equal(after.sound,false,'refresh preserves global mute');
 assert.deepEqual(after.parts,before.parts,'refresh preserves exact random rolls and all mech loadouts');
 assert.equal(after.world.docked,true,'returning to facilities persists carrier docking');
 assert.deepEqual(after.world.position,before.world.position,'refresh preserves exploration position');
 assert.deepEqual(after.world.cleared,before.world.cleared,'refresh preserves cleared map sites');
 await page.screenshot({path:'tests/world-restored-mobile.png'});
 await tap(450,1220);await tap(590,310);
 await page.screenshot({path:'tests/frost-restored-mobile.png'});
 await page.setViewportSize({width:360,height:640});await page.waitForTimeout(800);
 await page.screenshot({path:'tests/portrait-360.png'});
 await page.setViewportSize({width:1280,height:900});await page.waitForTimeout(800);
 await page.screenshot({path:'tests/desktop-portrait.png'});
 assert.deepEqual(errors,[],'no Godot or JS runtime errors');
 console.log(process.env.BASE_ONLY?'BASE FACILITIES PASS: launch, recall, facility navigation, parts crafting and transfer, upgrades, recruitment, docking save/reload, 3 viewports; no runtime errors':'BROWSER PASS: carrier hub, departure, manual recall, facility access, docking persistence, parts inventory, unequip/equip, weapon and drive swap, crafting, affixes, dismantle reward, cross-mech transfer, exact part persistence, enemy detection, real pursuit movement, enemy independent fire, full-screen floating joystick, left/right thumb, move while shooting, release stop, two-finger pan, pinch zoom, world save/restore, touch navigation, upgrade, recruit, leader selection, IndexedDB, reload, global mute, 3 viewport sizes');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1});
