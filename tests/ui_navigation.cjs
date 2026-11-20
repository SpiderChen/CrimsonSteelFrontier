// Shared touch paths through the carrier's four shortcuts and secondary sections.
async function facility(tap,name){
 // A previous secondary destination can leave the player on its parent page.
 await tap(51,52);
 const positions={hangar:[188,756],parts:[532,756],pilots:[188,898],salvage:[532,898]};
 if(positions[name]){await tap(...positions[name]);return}
 if(name==='regions'){await tap(360,568);return}
 if(name==='recruit'){await tap(...positions.pilots);await tap(360,1202);return}
 if(name==='overflow'){await tap(...positions.parts);await tap(513,1101);return}
 const build=['manufacturing','training','presets','tactics'];
 const fleet=['carrier','exchange','missions'];
 const archive=['cloud','story'];
 let index;
 if(build.includes(name)){await tap(...positions.hangar);await tap(532,900);index=build.indexOf(name)}
 else if(fleet.includes(name)){await tap(188,1044);index=fleet.indexOf(name)}
 else if(archive.includes(name)){await tap(532,1044);index=archive.indexOf(name)}
 else throw new Error('Unknown facility '+name);
 await tap(360,454+index*104);
}
async function fieldTool(tap,name){
 const names=['status','tactics','radar','locate','help','sound'];const index=names.indexOf(name);
 if(index<0)throw new Error('Unknown field tool '+name);
 await tap(646,56);await tap(360,424+index*94);
}
async function sound(tap,read){
 const data=await read();
 if(data?.world?.docked===false){await fieldTool(tap,'sound');await tap(624,297)}else await tap(667,54);
}
async function bossTarget(tap,name){
 const index=['auto','tracks','cannon','core'].indexOf(name);
 if(index<0)throw new Error('Unknown boss target '+name);
 await tap(379,170);await tap(360,508+index*104);
}
async function manufacture(tap,page,blueprint){
 const weapons=[21,22,23,24,0,1,2,15,16,17,18,19],row=weapons.indexOf(blueprint);
 if(row<0)throw new Error('Weapon blueprint required by browser helper');
 await facility(tap,'manufacturing');await tap(360,284);
 const viewport=page.viewportSize(),scale=viewport.width/720,offset=(viewport.height-1280*scale)/2;
 // Focus the first blueprint without releasing inside its button, then let the
 // scroll container follow keyboard focus to any model, including offscreen rows.
 await page.mouse.move(360*scale,459*scale+offset);await page.mouse.down();
 await page.mouse.move(360*scale,100*scale+offset);await page.mouse.up();
 for(let i=0;i<row;i++){await page.keyboard.press('Tab');await page.waitForTimeout(40)}
 await page.keyboard.press('Enter');await page.waitForTimeout(350);await tap(360,915);
}
async function leaveManufacturing(tap){await tap(360,971);await tap(624,177)}
module.exports={facility,fieldTool,sound,bossTarget,manufacture,leaveManufacturing};
