const nav=require('./ui_navigation.cjs');
const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
const {chromium}=require('../tools/browser/node_modules/playwright');
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true,args:['--use-angle=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
 const base=process.env.GAME_URL||'http://localhost:8071', account='web_'+Date.now(), password='browser-test-password';
 const errors=[];
 async function device(){
  const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true});
  const page=await context.newPage();
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(/SCRIPT ERROR|ERROR:/.test(m.text()))errors.push(m.text())});
  await page.route('**/__fixture',r=>r.fulfill({status:200,contentType:'text/html',body:'<!doctype html><title>test fixture writer</title>'}));
  return {context,page};
 }
 async function record(page,kind='game',mode=null){return page.evaluate(async({kind,mode})=>{
  for(const entry of await indexedDB.databases()){
   const db=await new Promise(resolve=>{const r=indexedDB.open(entry.name);r.onsuccess=()=>resolve(r.result)});
   for(const name of db.objectStoreNames){
    const records=await new Promise(resolve=>{const st=db.transaction(name).objectStore(name);const r=st.getAll(),k=st.getAllKeys();let rows,keys;function done(){if(rows&&keys)resolve({rows,keys})}r.onsuccess=()=>{rows=r.result;done()};k.onsuccess=()=>{keys=k.result;done()}});
    for(let i=0;i<records.keys.length;i++){
     const suffix=kind==='session'?'/cloud_session.json':'/crimson_front_v1.json';
     if(!String(records.keys[i]).endsWith(suffix))continue;
     const row=records.rows[i],d=JSON.parse(new TextDecoder().decode(row.contents));
     if(mode==='setup'){
      d.sound=false;d.credits=2400;d.cores=120;d.gems=900;d.hp=100;d.recovery=0;d.cloud_binding={};d.selected=0;d.levels=[1,1,1];d.unlocked=[true,true,false];
      d.world={docked:true,position:[384,384]};d.expedition={clears:[1,0,0,0],samples:[0,0,0,0],sequence:0,run:{},report:{}};
      const template=d.parts.inventory[0];for(let id=d.parts.next_id;id<=120;id++){const part=JSON.parse(JSON.stringify(template));part.id=id;d.parts.inventory.push(part)}d.parts.next_id=121;d.parts.overflow=[];d.parts.research={};d.parts.research_materials=0;
      const ids=new Set(Object.values(d.parts.loadouts[0]));
      const snapshot={pilot:0,pilot_name:'绯夜',levels:[1,1,1],unlocked:[true,true,false],stage:1,tactics:d.tactics[0],auto_skill:true,parts:{inventory:d.parts.inventory.filter(p=>ids.has(p.id)),loadouts:[d.parts.loadouts[0],{},{}],presets:[[],[],[]],next_id:121}};
      const cert={version:1,id:'cert:1',name:'绯夜 · A级认证 1',grade:'A',region:0,seconds:12,minimum_hp:80,snapshot,trials:[0,1,2].map(()=>({seconds:12,hp:80,hits:10,damage:100})),rates:{credits:28800,cores:80,parts:2,research:2/3,samples:1}};
      d.salvage={version:1,cursor:Date.now()/1000,age:0,sequence:1,certificates:[cert],active_id:'cert:1',rows:[],claims:0,last_claim:{},auto_recycle:true};
     }else if(mode==='absence'){d.salvage.cursor-=48*3600;d.salvage.age=0;d.salvage.rows=[]}
     if(mode){row.contents=new TextEncoder().encode(JSON.stringify(d));row.timestamp=new Date();await new Promise((resolve,reject)=>{const t=db.transaction(name,'readwrite');t.objectStore(name).put(row,records.keys[i]);t.oncomplete=resolve;t.onerror=()=>reject(t.error)})}
     db.close();return d;
    }
   }db.close();
  }
 },{kind,mode})}
 async function persisted(page,predicate,kind='game',timeout=30000){const end=Date.now()+timeout;let d;while(Date.now()<end){d=await record(page,kind);if(d&&predicate(d))return d;await page.waitForTimeout(250)}await page.screenshot({path:'tests/cloud-failure-mobile.png'});assert.fail(JSON.stringify({kind,data:d,errors}))}
 async function ready(page){await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:120000});await page.waitForTimeout(1200)}
 async function tap(page,x,y){await page.touchscreen.tap(x*390/720,y*390/720+(844-1280*390/720)/2);await page.waitForTimeout(350)}
 async function openCloud(page){await tap(page,51,52);await nav.facility((x,y)=>tap(page,x,y),'cloud')}
 async function enter(page,x,y,value){await tap(page,x,y);await page.keyboard.press('Meta+A');await page.keyboard.type(value,{delay:25});await page.keyboard.press('Tab')}
 async function auth(page,register=false){await enter(page,150,429,account);await enter(page,475,429,password);await tap(page,register?475:170,503);await persisted(page,d=>d.username===account&&d.token,'session');await page.waitForTimeout(600)}
 async function backend(){return JSON.parse(execFileSync('python3',['-c',`import sqlite3,json,sys\ndb=sqlite3.connect('tests/cloud-integration.sqlite3')\nr=db.execute('SELECT s.body,s.revision FROM saves s JOIN accounts a ON a.id=s.account WHERE a.username=?',(sys.argv[1],)).fetchone()\nprint(json.dumps({'save':json.loads(r[0]),'revision':r[1]}))`,account],{encoding:'utf8'}))}
 try{
  const A=await device(), B=await device();
  await A.page.goto(base);await ready(A.page);await tap(A.page,667,54);await persisted(A.page,d=>d.sound===false);
  await A.page.goto(base+'/__fixture');await record(A.page,'game','setup');await A.page.goto(base);await ready(A.page);
  await openCloud(A.page);await A.page.screenshot({path:'tests/cloud-login-mobile.png'});await auth(A.page,true);
  await tap(A.page,360,846);const initial=await persisted(A.page,d=>d.cloud_binding?.revision===1);
  assert.equal(initial.parts.inventory.length,120);assert.equal(initial.credits,2400);
  await A.page.screenshot({path:'tests/cloud-first-save-mobile.png'});
  await B.page.goto(base);await ready(B.page);await tap(B.page,667,54);await persisted(B.page,d=>d.sound===false);await openCloud(B.page);await auth(B.page);
  await tap(B.page,360,920);const copied=await persisted(B.page,d=>d.cloud_binding?.revision===1);
  assert.deepEqual(copied.parts,initial.parts);assert.deepEqual(copied.pilot_roster,initial.pilot_roster);assert.equal(copied.credits,initial.credits);
  await B.page.screenshot({path:'tests/cloud-second-device-mobile.png'});
  // A real upgrade is saved by A, while B still holds revision 1.
  await tap(A.page,624,157);await nav.facility((x,y)=>tap(A.page,x,y),'hangar');await tap(A.page,360,1029);
  const changed=await persisted(A.page,d=>d.levels[0]===2);assert(changed.credits<initial.credits);
  await openCloud(A.page);await tap(A.page,360,846);const second=await persisted(A.page,d=>d.cloud_binding.revision===2);
  const conflict=B.page.waitForResponse(r=>r.url().endsWith('/api/state')&&r.status()===409);await tap(B.page,360,846);await conflict;
  assert.equal((await record(B.page)).cloud_binding.revision,1);assert.equal((await backend()).revision,2);
  await B.page.screenshot({path:'tests/cloud-save-conflict-mobile.png'});await tap(B.page,360,920);
  const latest=await persisted(B.page,d=>d.cloud_binding.revision===2);assert.deepEqual(latest.levels,second.levels);assert.equal(latest.credits,second.credits);
  console.log('CLOUD BROWSER PASS: two independent browsers register/login, transfer a full bag and pilot progress, preserve a real upgrade and reject stale overwrite');
  // Model an actual 48-hour absence by backdating only this fixture's server ledger and local saved cursor.
  execFileSync('python3',['-c',`import sqlite3,json,sys\ndb=sqlite3.connect('tests/cloud-integration.sqlite3')\nr=db.execute('SELECT s.account,s.body FROM saves s JOIN accounts a ON a.id=s.account WHERE a.username=?',(sys.argv[1],)).fetchone()\nd=json.loads(r[1]);d['salvage']['cursor']-=48*3600;d['salvage']['age']=0;d['salvage']['rows']=[]\ndb.execute('UPDATE saves SET body=? WHERE account=?',(json.dumps(d),r[0]));db.commit()`,account]);
  await A.page.goto(base+'/__fixture');await record(A.page,'game','absence');await A.page.goto(base);await ready(A.page);await openCloud(A.page);
  await A.page.evaluate(()=>{const RealDate=window.Date;window.Date=class extends RealDate{constructor(...args){super(...(args.length?args:[RealDate.now()+3*365*86400000]))}static now(){return RealDate.now()+3*365*86400000}}});
  const payoutResponse=A.page.waitForResponse(r=>r.url().endsWith('/api/claim')&&r.status()===200);await tap(A.page,360,994);const payout=await (await payoutResponse).json();
  const paid=await persisted(A.page,d=>d.cloud_binding.revision===3);
  assert(payout.receipt.effective_seconds>=36*3600&&payout.receipt.effective_seconds<36*3600+60);
  assert.equal(paid.credits,second.credits+payout.receipt.credits);assert.equal(paid.parts.inventory.length,120);assert(paid.parts.overflow.length>0);
  assert(paid.parts.overflow.every(p=>p.quality>0));assert.equal(paid.parts.overflow.length+payout.receipt.recycled,payout.receipt.parts);
  assert.equal(paid.parts.research_materials,payout.receipt.research);assert.equal(paid.expedition.samples[0],payout.receipt.samples);
  assert(Math.abs(paid.last_seen-Date.now()/1000)<120,'cloud time must ignore browser Date advanced three years');
  await A.page.screenshot({path:'tests/cloud-trusted-claim-mobile.png'});
  const claimConflict=B.page.waitForResponse(r=>r.url().endsWith('/api/claim')&&r.status()===409);await tap(B.page,360,994);await claimConflict;
  assert.equal((await record(B.page)).credits,latest.credits);assert.equal((await backend()).save.credits,paid.credits);
  await tap(B.page,360,920);const shared=await persisted(B.page,d=>d.cloud_binding.revision===3);
  assert.deepEqual(shared.parts,paid.parts);assert.equal(shared.credits,paid.credits);
  console.log('CLOUD BROWSER PASS: server-calculated 48-hour/36-effective-hour rewards ignore client Date, create real regional gear/research/samples, preserve rares in overflow and cannot be claimed twice across devices');
  // Lose the response after the backend committed. Retrying must reuse its persisted request ID.
  const beforeLost=(await backend()).revision;let aborted=false;
  await A.page.route('**/api/claim',async route=>{if(!aborted){aborted=true;await route.fetch();await route.abort('failed')}else await route.continue()});
  await tap(A.page,360,994);await persisted(A.page,d=>d.pending_claim?.length===32,'session');
  for(let i=0;i<80&&((await backend()).revision===beforeLost);i++)await A.page.waitForTimeout(100);
  const committed=await backend();assert.equal(committed.revision,beforeLost+1);
  await A.page.waitForTimeout(1200);await A.page.screenshot({path:'tests/cloud-lost-response-mobile.png'});
  const pending=(await record(A.page,'session')).pending_claim;
  await tap(A.page,624,157);assert.equal((await record(A.page,'session')).pending_claim,pending);
  // The committed receipt must also survive session expiry and a full browser reload.
  const lostSession=await record(A.page,'session');
  execFileSync('python3',['-c',`import sqlite3,hashlib,sys
db=sqlite3.connect('tests/cloud-integration.sqlite3')
digest=hashlib.sha256(sys.stdin.read().encode()).hexdigest()
db.execute('UPDATE sessions SET expires=0 WHERE token_hash=?',(digest,));db.commit()`],{input:lostSession.token});
  const expired=A.page.waitForResponse(r=>r.url().endsWith('/api/claim')&&r.status()===401);
  await tap(A.page,360,994);await expired;
  await persisted(A.page,d=>d.token===''&&d.pending_claim===pending,'session');
  await A.page.reload();await ready(A.page);await A.page.screenshot({path:'tests/cloud-expired-session-pending-mobile.png'});
  await auth(A.page);assert.equal((await record(A.page,'session')).pending_claim,pending);
  await A.page.screenshot({path:'tests/cloud-pending-reauthenticated-mobile.png'});
  console.log('CLOUD BROWSER PASS: a lost claim survives session expiry and reload; the actual original-account login controls restore authentication while keeping its request ID');
  await tap(A.page,360,994);const recovered=await persisted(A.page,d=>d.cloud_binding.revision===committed.revision);
  await persisted(A.page,d=>d.pending_claim==='','session');assert.equal(recovered.credits,committed.save.credits);
  assert.equal((await backend()).revision,committed.revision);
  await A.page.screenshot({path:'tests/cloud-recovered-receipt-mobile.png'});
  await A.page.reload();await ready(A.page);const reloaded=await persisted(A.page,d=>d.cloud_binding.revision===committed.revision);
  assert.equal(reloaded.credits,recovered.credits);assert.deepEqual(reloaded.parts,recovered.parts);
  await openCloud(A.page);await A.page.screenshot({path:'tests/cloud-reload-mobile.png'});
  const beforeSwitch=await backend();
  await tap(A.page,624,167);await tap(A.page,51,52);await nav.facility((x,y)=>tap(A.page,x,y),'salvage');await tap(A.page,511,798);await tap(A.page,360,991);
  await persisted(A.page,d=>d.cloud_binding.revision===beforeSwitch.revision+1&&d.salvage.active_id==='base');
  assert.equal((await backend()).save.salvage.active_id,'base');
  await tap(A.page,624,167);await tap(A.page,51,52);await nav.facility((x,y)=>tap(A.page,x,y),'salvage');await tap(A.page,511,798);await tap(A.page,360,634);await tap(A.page,360,853);
  const switchedBack=await persisted(A.page,d=>d.cloud_binding.revision===beforeSwitch.revision+2&&d.salvage.active_id==='cert:1');
  const sourceState=await backend();assert.equal(sourceState.save.salvage.active_id,'cert:1');assert(sourceState.save.salvage.rows.some(r=>r.id==='base'&&r.effective_seconds>0));
  assert.equal(switchedBack.credits,reloaded.credits);await A.page.screenshot({path:'tests/cloud-immediate-source-switch-mobile.png'});
  console.log('CLOUD BROWSER PASS: actual archive controls immediately synchronize both source switches and retain server-accounted old-source income without an extra manual upload');
  assert.deepEqual(errors,[]);
  console.log('CLOUD BROWSER PASS: a committed claim with a lost network response persists its request ID, blocks conflicting actions, recovers the same receipt without extra payout and survives reload with credentials separate from game data');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
