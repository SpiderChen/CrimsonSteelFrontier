const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('../tools/browser/node_modules/playwright');
const nav = require('./ui_navigation.cjs');

(async () => {
 const output = process.env.OUTPUT_DIR || '.local/acceptance'; fs.mkdirSync(output, {recursive:true});
 const browser = await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:[...(process.env.SOFTWARE_GL?['--use-angle=swiftshader']:['--enable-gpu']),'--enable-webgl','--ignore-gpu-blocklist']});
 try {
  const video = process.env.RECORD_VIDEO ? {recordVideo:{dir:path.join(output,'videos'),size:{width:432,height:768}}} : {};
  const context = await browser.newContext({viewport:{width:432,height:768},hasTouch:true,...video});
  const page = await context.newPage(), errors=[];
  const opened = Date.now();
  const base = process.env.GAME_URL || 'http://localhost:8061';
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{if(m.type()==='error'||/SCRIPT ERROR|ERROR:/.test(m.text())){errors.push(m.text());console.error(m.text())}});
  await page.route('**/__fixture',r=>r.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>isolated acceptance fixture</title>'}));
  function point(x,y){const v=page.viewportSize(),s=Math.min(v.width/720,v.height/1280);return {x:x*s+(v.width-720*s)/2,y:y*s+(v.height-1280*s)/2}}
  async function tap(x,y,delay=180){const p=point(x,y);await page.touchscreen.tap(p.x,p.y);if(delay)await page.waitForTimeout(delay)}
  async function ready(){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(800)}
  async function snap(name){await page.screenshot({path:path.join(output,name+'.png')})}
  async function save(setup=false){return page.evaluate(async setup=>{
   for(const entry of await indexedDB.databases()){
    const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
    for(const name of db.objectStoreNames){
     const records=await new Promise(resolve=>{const s=db.transaction(name).objectStore(name),r=s.getAll(),k=s.getAllKeys();let rows,keys;const done=()=>{if(rows&&keys)resolve({rows,keys})};r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
     const i=records.keys.findIndex(k=>String(k).endsWith('/crimson_front_v1.json'));if(i<0)continue;
     const row=records.rows[i],d=JSON.parse(new TextDecoder().decode(row.contents));
     if(setup){
      d.narrative={...d.narrative,active:'',cursor:0,pending:[],tutorial:false,seen:['prologue','briefing_0']};d.sound=false;d.recovery=0;d.hp=100;
      const main=d.parts.inventory.find(p=>p.id===d.parts.loadouts[0]['0']);main.blueprint=15;main.mechanism='';
      delete d.parts.loadouts[0]['4'];d.auto_skill=false;
      row.contents=new TextEncoder().encode(JSON.stringify(d));row.timestamp=new Date();
      await new Promise((resolve,reject)=>{const t=db.transaction(name,'readwrite');t.objectStore(name).put(row,records.keys[i]);t.oncomplete=resolve;t.onerror=()=>reject(t.error)});
     }
     db.close();return d;
    }db.close();
   }
  },setup)}
  async function persisted(predicate){
   const until=Date.now()+15000;let d;
   while(Date.now()<until){d=await save();if(d&&predicate(d))return d;await page.waitForTimeout(150)}
   assert.fail(JSON.stringify({save:d,errors}));
  }
  await page.goto(base);await ready();
  fs.writeFileSync(path.join(output,'browser-run.json'),JSON.stringify({videoStartSeconds:(Date.now()-opened)/1000},null,2));
  console.log('Loaded real WebGL game');await tap(610,74);
  await nav.facility(tap,'hangar');await tap(534,1115);await tap(360,991); // half speed
  for(let model=0;model<3;model++){
   await tap(160+model*198,286);await page.waitForTimeout(350);await snap(`review-chassis-${model}`);
  }
  await tap(160,286);
  for(let mode=0;mode<6;mode++){
   await tap(112+mode*99,847);await page.waitForTimeout(650);await snap(`review-drive-${mode}`);
  }
  await tap(211,847);
  for(let i=0;i<10;i++){await page.waitForTimeout(65);await snap(`walk-after-${i}`)}
  await tap(210,1048);await page.waitForTimeout(600);
  for(let i=0;i<4;i++){await page.waitForTimeout(450);await snap(`turn-3d-${i}`)}
  await tap(210,1048);
  await tap(158,991);await tap(550,991,0);await snap('shield-hit-paused');await tap(158,991);
  await tap(122,911);await page.waitForTimeout(900);await snap("rifle-carry-idle");
  await tap(510,1048); // explicitly enable attacks; previews start with carry poses
  for(let weapon=0;weapon<5;weapon++){
   await tap(122+weapon*119,911);await page.waitForTimeout(weapon===4?1100:900);await snap(`review-weapon-${weapon}`);await page.waitForTimeout(700);
  }
  await tap(122,911);await page.waitForTimeout(900);await snap('rifle-firing');
  await tap(510,1048);await page.waitForTimeout(1500);await snap('rifle-lowered-after-fire');
  await page.setViewportSize({width:390,height:844});await snap('review-mobile');
  const frameTimes=await page.evaluate(()=>new Promise(resolve=>{
   const values=[];let previous=performance.now();const started=previous;
   function sample(now){values.push(now-previous);previous=now;if(values.length>=90||now-started>6000)resolve(values);else requestAnimationFrame(sample)}requestAnimationFrame(sample);
  }));
  frameTimes.shift();frameTimes.sort((a,b)=>a-b);
  const renderer=await page.evaluate(()=>{const gl=document.querySelector('canvas').getContext('webgl2');const ext=gl?.getExtension('WEBGL_debug_renderer_info');return ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):'unknown'});
  fs.writeFileSync(path.join(output,'frame-times.json'),JSON.stringify({renderer,samples:frameTimes.length,medianMs:frameTimes[Math.floor(frameTimes.length*.5)],p95Ms:frameTimes[Math.floor(frameTimes.length*.95)],note:'Chrome desktop at a 390x844 viewport; not a physical-phone benchmark.'},null,2));
  await page.setViewportSize({width:1440,height:900});await snap('review-desktop');
  console.log('Reviewed chassis, motion, weapon and shield controls');
  if(process.env.REVIEW_ONLY){
   assert.deepEqual(errors,[]);
   if(process.env.RECORD_VIDEO){const recording=page.video();await context.close();await recording.saveAs(path.join(output,'motion-acceptance.webm'));}else await context.close();
   console.log('MOTION REVIEW PASS: final holding anchors, moving arms, silhouette shield and muzzle effects captured.');return;
  }
  await page.setViewportSize({width:390,height:844});await tap(360,1107);await tap(51,52);
  await page.waitForTimeout(1200);const before=await save();assert(before?.world.docked);
  await page.goto(base+'/__fixture');await save(true);await page.goto(base);await ready();
  await nav.facility(tap,'training');await page.waitForTimeout(2000);await snap('training-laser-mobile');
  await tap(560,377);await page.waitForTimeout(2000);await snap('training-survival-mobile');
  await tap(555,1028);
  await nav.facility(tap,'regions');await tap(360,338);await tap(360,754);await page.waitForTimeout(900);
	const launch=await persisted(d=>d.world.docked===false);
	if(launch.narrative?.active)await tap(610,74);
  await snap('field-start-mobile');
  const start=(await persisted(d=>d.world.docked===false)).world.position;
  const touch=await context.newCDPSession(page);
  await touch.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point(200,700),id:1}]});
  await touch.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...point(270,700),id:1}]});
  await page.waitForTimeout(1000);await snap('field-moving-mobile');
  await touch.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await page.waitForTimeout(300);
  await persisted(d=>d.world.docked===false&&d.world.expedition_autopilot===false&&Math.hypot(d.world.position[0]-start[0],d.world.position[1]-start[1])>10);
  await tap(530,56);await persisted(d=>d.world.expedition_autopilot===true);
  await snap('field-auto-mobile');await page.setViewportSize({width:1440,height:900});await snap('field-desktop');
  assert.deepEqual(errors,[]);fs.writeFileSync(path.join(output,'browser-errors.json'),JSON.stringify(errors,null,2));
  if(process.env.RECORD_VIDEO){const recording=page.video();await context.close();await recording.saveAs(path.join(output,'motion-acceptance.webm'));}else await context.close();
  console.log('MOTION BROWSER PASS: three 3D chassis, six motion states, continuous turn, five weapons, paused shield impact, mobile/desktop, real laser/survival training, manual touch and auto battle; no JS/Godot errors.');
 } finally {await browser.close()}
})().catch(e=>{console.error(e);process.exitCode=1});
