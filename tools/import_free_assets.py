"""Copy the selected original CC0 files and record their provenance and SHA-256."""
from pathlib import Path
import hashlib,json,shutil
root=Path(__file__).resolve().parent.parent
source=root/'tools/downloads';target=root/'assets/free';target.mkdir(parents=True,exist_ok=True)
entries=[]
selections={
 'sci-fi-sounds':('https://kenney.nl/assets/sci-fi-sounds',{
  'Audio/laserSmall_000.ogg':('audio/laser.ogg','自动攻击'),
  'Audio/laserLarge_000.ogg':('audio/ultimate.ogg','机师技能'),
  'Audio/impactMetal_000.ogg':('audio/impact.ogg','装甲命中'),
  'Audio/explosionCrunch_000.ogg':('audio/explosion.ogg','敌机击破'),
  'Audio/forceField_000.ogg':('audio/resonance.ogg','招募同调与强化'),
  'Audio/laserRetro_002.ogg':('audio/ui_click.ogg','按钮反馈'),
  'Audio/laserRetro_000.ogg':('audio/autocannon.ogg','实弹与连射炮'),
  'Audio/laserLarge_003.ogg':('audio/rail.ogg','轨道炮与贯穿技能'),
  'Audio/laserLarge_001.ogg':('audio/plasma.ogg','等离子发射'),
  'Audio/laserSmall_002.ogg':('audio/beam.ogg','持续激光起振'),
  'Audio/thrusterFire_000.ogg':('audio/missile.ogg','导弹点火'),
  'Audio/forceField_002.ogg':('audio/blade.ogg','能量剑挥斩'),
  'Audio/impactMetal_002.ogg':('audio/punch.ogg','动力拳套命中'),
  'Audio/impactMetal_004.ogg':('audio/hammer.ogg','重锤命中'),
  'Audio/lowFrequency_explosion_000.ogg':('audio/heavy_explosion.ogg','重型爆破'),
  'Audio/computerNoise_001.ogg':('audio/reward.ogg','物资与任务奖励'),
  'Audio/forceField_003.ogg':('audio/shield.ogg','机师维修与护盾技能'),
  'Audio/laserRetro_001.ogg':('audio/autocannon_alt.ogg','连射炮变体'),
  'Audio/laserRetro_004.ogg':('audio/autocannon_tail.ogg','连射炮机械尾音变体'),
  'Audio/laserLarge_004.ogg':('audio/rail_alt.ogg','轨道炮变体'),
  'Audio/laserLarge_002.ogg':('audio/plasma_alt.ogg','等离子变体'),
  'Audio/laserSmall_003.ogg':('audio/beam_alt.ogg','持续激光变体'),
  'Audio/laserRetro_003.ogg':('audio/pulse.ogg','脉冲光束独立发射'),
  'Audio/laserSmall_001.ogg':('audio/laser_alt.ogg','敌军射击变体'),
  'Audio/impactMetal_001.ogg':('audio/impact_alt.ogg','装甲命中与落脚变体'),
  'Audio/impactMetal_003.ogg':('audio/impact_heavy.ogg','重型接触与刹停'),
  'Audio/explosionCrunch_001.ogg':('audio/explosion_alt.ogg','敌机击破变体'),
  'Audio/lowFrequency_explosion_001.ogg':('audio/heavy_explosion_alt.ogg','低频爆破变体'),
  'Audio/forceField_004.ogg':('audio/shield_alt.ogg','护盾与能量接触变体'),
  'Audio/thrusterFire_001.ogg':('audio/missile_alt.ogg','导弹点火变体'),
  'Audio/thrusterFire_002.ogg':('audio/boost.ogg','推进起步'),
  'Audio/thrusterFire_003.ogg':('audio/vent.ogg','排热喷流'),
  'Audio/computerNoise_000.ogg':('audio/discover.ogg','地点发现扫描'),
  'Audio/computerNoise_002.ogg':('audio/repair.ogg','维修设施反馈'),
  'Audio/computerNoise_003.ogg':('audio/recruit.ogg','招募同调独立反馈'),
  'Audio/forceField_001.ogg':('audio/critical.ogg','暴击发射能量重音'),
 }),
 'ui-pack-sci-fi':('https://kenney.nl/assets/ui-pack-sci-fi',{
  'PNG/Grey/Double/bar_square_gloss_small.png':('ui/meter_frame.png','状态条边框'),
  'PNG/Grey/Double/bar_square_gloss_small_m.png':('ui/meter_fill.png','状态条填充'),
  'PNG/Grey/Double/button_square_header_small_rectangle.png':('ui/button.png','次级按钮九宫格'),
  'PNG/Red/Double/button_square_header_small_rectangle.png':('ui/button_primary.png','主要按钮九宫格'),
  'PNG/Blue/Double/crosshair_color_a.png':('ui/crosshair.png','战斗锁定标记'),
  'PNG/Grey/Double/button_square_header_blade_rectangle_screws.png':('ui/armor_wide.png','工业建筑屋顶与母舰装甲'),
  'PNG/Grey/Double/button_square_header_notch_square_screws.png':('ui/armor_plate.png','机甲胸甲、肩甲与补给箱'),
  'PNG/Grey/Double/button_square_header_large_rectangle_screws.png':('ui/facility_panel.png','母舰设施卡片九宫格'),
  'PNG/Blue/Double/bar_square_gloss_small.png':('ui/energy_bar.png','建筑反应堆与机甲装甲灯带'),
 }),
 'background-elements-redux':('https://kenney.nl/assets/background-elements-remastered',{
  'PNG/Retina/moonFull.png':('background/moon.png','灰烬都市月亮'),
  'PNG/Retina/cloud3.png':('background/cloud.png','战场视差云层'),
  'PNG/Retina/cloud5.png':('background/haze.png','地平线雾层'),
  'PNG/Retina/treeDead.png':('background/tree_dead.png','荒原枯树与地表残骸'),
  'PNG/Retina/treePineFrozen.png':('background/tree_frozen.png','冷却区霜冻植被'),
  'PNG/Retina/bushOrange1.png':('background/scrub.png','沙海低矮灌丛'),
  'PNG/Retina/fenceIron.png':('background/fence.png','军工建筑围栏'),
 }),
 'game-icons':('https://kenney.nl/assets/game-icons',{
  'PNG/White/2x/'+name+'.png':('icons/'+name+'.png',usage)
  for name,usage in [('target','作战导航'),('wrench','机库导航'),('singleplayer','机师导航'),('star','招募导航和星晶'),('medal1','信用点'),('gear','合金芯'),('audioOn','音效开启'),('audioOff','静音'),('question','指挥官手册'),('menuGrid','仓库与溢出仓'),('power','制造工坊与供能'),('gamepad','构筑训练舱'),('save','配装档案库'),('joystick','自动战术'),('trophy','行动任务'),('home','母舰与前线据点'),('share1','云端档案'),('plus','补给维修设施'),('warning','首领区域'),('locked','武器库')]
 })
}
for pack,(url,files) in selections.items():
 lic=next(p for p in (source/pack).iterdir() if p.name.lower()=='license.txt')
 dest=target/'licenses'/(pack+'.txt');dest.parent.mkdir(exist_ok=True);shutil.copy2(lic,dest)
 for original,(relative,usage) in files.items():
  src=source/pack/original;dest=target/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dest)
  entries.append({'file':relative,'author':'Kenney','pack':pack,'source':url,'original_file':original,'license':'CC0-1.0','usage':usage,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
retired = {'ui/button.png','ui/button_primary.png','ui/armor_plate.png','ui/energy_bar.png','icons/plus.png','icons/locked.png','icons/warning.png'}
for entry in entries:
 entry['active_in_game'] = not entry['file'].startswith('background/') and entry['file'] not in retired
(target/'manifest.json').write_text(json.dumps({'assets':entries},ensure_ascii=False,indent=2))
print('Imported',len(entries),'CC0 assets;',sum((target/e['file']).stat().st_size for e in entries),'bytes')
