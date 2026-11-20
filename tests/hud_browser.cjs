const assert=require('node:assert/strict');
const {chromium}=require('../tools/browser/node_modules/playwright');
const nav=require('./ui_navigation.cjs');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROME_PATH||'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
 const page=await context.newPage(),errors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text())});
 async function read(){return page.evaluate(async()=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const data=await new Promise(resolve=>{let rows,keys;const s=db.transaction(name).objectStore(name),r=s.getAll(),k=s.getAllKeys();function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<data.keys.length;i++)if(String(data.keys[i]).endsWith('/crimson_front_v1.json')){db.close();return JSON.parse(new TextDecoder().decode(data.rows[i].contents))}
   }db.close();
  }
 })}
 async function persisted(predicate,timeout=30000){const end=Date.now()+timeout;let d;while(Date.now()<end){d=await read();if(d&&predicate(d))return d;await page.waitForTimeout(250)}await page.screenshot({path:'tests/hud-failure.png'});assert.fail(JSON.stringify({save:d,errors}))}
 function screen(x,y){const v=page.viewportSize(),s=Math.min(v.width/720,v.height/1280);return{x:x*s+(v.width-720*s)/2,y:y*s+(v.height-1280*s)/2}}
 async function tap(x,y){const p=screen(x,y);await page.touchscreen.tap(p.x,p.y);await page.waitForTimeout(300)}
 async function close(height){await tap(624,(1280-height)/2+57)}
 async function home(){await tap(51,52);await page.waitForTimeout(500)}
 async function shot(name){await page.screenshot({path:'tests/'+name+'.png'})}
 await page.goto(process.env.GAME_URL||'http://localhost:8060');await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200);
 await persisted(d=>d.narrative?.active==='prologue');await tap(610,74);
 await persisted(d=>d.narrative.seen.includes('prologue')&&!d.narrative.active);
 // Use the visible archive controls to pause guidance for this navigation pass.
 await nav.facility(tap,'story');await tap(208,280);await tap(208,891);
 await persisted(d=>d.narrative.tutorial===false);
 await tap(667,54);await persisted(d=>d.sound===false);await shot('hud-base-mobile');
 for(const [width,height,name] of [[360,640,'small-mobile'],[1440,900,'desktop']]){
  await page.setViewportSize({width,height});await page.waitForTimeout(400);await shot('hud-base-'+name);
 }
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(400);
 await nav.facility(tap,'hangar');await tap(360,1029);const upgraded=await persisted(d=>d.mechs?.units?.[0]?.level===2);assert(upgraded.credits<2400);await home();
 await nav.facility(tap,'pilots');await tap(534,1111);await shot('hud-pilot-access-mobile');await close(1060);await home();
 await nav.facility(tap,'salvage');await shot('hud-salvage-access-mobile');await close(1040);
 await nav.facility(tap,'regions');await shot('hud-regions-access-mobile');await close(1040);
 await shot('hud-facilities-mobile');
 const facilities=[['parts',1040],['manufacturing',1040],['training',880],['presets',720],['tactics',960],['carrier',1080],['exchange',900],['missions',640],['overflow',960],['cloud',1080],['story',1060]];
 for(const [name,height] of facilities){
  await nav.facility(tap,name);
  if(name==='training'){await tap(360,377);await page.waitForTimeout(1000);await shot('hud-training-access-mobile')}
  if(name==='presets'){await tap(400,461);await persisted(d=>d.parts.presets[0]?.[0]?.['0']===1)}
  if(name==='cloud')await shot('hud-cloud-access-mobile');
  await close(height);await home();
 }
 await nav.facility(tap,'recruit');await shot('hud-recruit-access-mobile');await home();
 console.log('HUD BROWSER PASS: four home shortcuts and all secondary facilities remain reachable, including actual upgrade, saved preset, training, cloud and archive controls');
 await nav.facility(tap,'regions');await tap(360,339);await tap(360,749);await persisted(d=>d.world.docked===false&&d.narrative.active==='briefing_0');await tap(610,74);await shot('hud-battle-mobile');
 await nav.fieldTool(tap,'status');await shot('hud-status-mobile');await close(850);
 await nav.fieldTool(tap,'radar');await shot('hud-radar-mobile');
 await nav.fieldTool(tap,'radar');
 const cdp=await context.newCDPSession(page),a=screen(230,500),b=screen(450,500);
 await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...a,id:1},{...b,id:2}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:a.x+40,y:a.y,id:1},{x:b.x+40,y:b.y,id:2}]});
 await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(300);
 await shot('hud-camera-recenter-mobile');await tap(656,960);
 for(const [width,height,name] of [[360,740,'small-mobile'],[1440,900,'desktop']]){
  await page.setViewportSize({width,height});await page.waitForTimeout(400);await shot('hud-battle-'+name);
 }
 await page.setViewportSize({width:390,height:844});await page.waitForTimeout(400);await tap(656,1056);await tap(360,783);await persisted(d=>d.world.docked===true);
 await persisted(d=>d.narrative.active==='first_return');await tap(610,74);await tap(510,1027);
 await shot('hud-base-returned-mobile');
 assert.deepEqual(errors,[]);
 console.log('HUD BROWSER PASS: expanded field, compact live gauges, optional radar, camera recenter, return to carrier, free exploration and phone/desktop viewports without errors');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
