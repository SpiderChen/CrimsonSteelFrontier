extends RefCounted
## Inventory owns immutable rolls; loadouts reference unique IDs, never array positions.
const SLOTS = ["左手武器", "躯干", "腿部", "核心", "右手武器", "背包"]
const DISPLAY_SLOTS = [3,1,2,5,0,4]
const QUALITIES = ["精良", "稀有", "史诗"]
const COLORS = [Color("8cdec3"), Color("78bdff"), Color("c49bff")]
const MECHANISMS = {
 "pierce":{"name":"贯穿弹芯","desc":"沿实际弹道贯穿最多 3 个额外目标，每次伤害衰减 30%。","tags":["projectile"]},
 "bounce":{"name":"跳弹磁轨","desc":"首击伤害为 80%，向 180 范围内不同目标弹射最多 3 次，每跳伤害衰减 25%。","tags":["kinetic","electric"]},
 "split":{"name":"碎裂弹头","desc":"主弹伤害为 70%，首次命中后产生两枚 30% 伤害分裂弹；分裂弹不再分裂且不命中原目标。","tags":["kinetic"]},
 "pulse":{"name":"脉冲调制","desc":"持续光束改为蓄光后的单次粗脉冲，间隔延长 25%。","tags":["beam"]},
 "sweep":{"name":"扇面扫射","desc":"光束沿 40 度扇面扫动，实际伤害随光束路径逐段判定。","tags":["beam"]},
 "swarm":{"name":"蜂群弹仓","desc":"发射 4 枚独立追踪微型导弹，共享 90% 的原始伤害预算。","tags":["missile"]},
 "proximity":{"name":"近爆引信","desc":"距离目标 50 时提前引爆，爆炸半径 110，直击伤害为 85%。","tags":["missile"]},
 "incendiary":{"name":"燃烧覆盖","desc":"将 35% 主弹伤害转成持续 3 秒的地面灼烧；区域外不受伤。","tags":["explosive"]},
 "ion":{"name":"电离转换","desc":"将 40% 原伤害转为电能，伤害总预算保持不变。","tags":["attack","reactor"]},
 "hot_drive":{"name":"超温驱动","desc":"热量达到 60 时攻击提高 20%，产热始终提高 30%。","tags":["attack"]},
 "vent":{"name":"散热回路","desc":"达到 80 热量时排热 30 并获得 3 秒临时护盾 15，冷却 8 秒。","tags":["reactor","backpack"]},
 "counter":{"name":"蓄能反击","desc":"累计损失 35 装甲后释放 210 范围反击；冷却 5 秒，致命伤不触发。","tags":["armor","shield"]}
}
const LIMIT = 120
const RESEARCH_TARGET = 6
const BASIC_BLUEPRINTS = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,21,22,23,24]
const NAMED_BLUEPRINTS = [17,18,19,20]
const MELEE_BLUEPRINTS = [21,22,23]
const HAND_SHIELDS = [24]
const BLUEPRINTS = [
	{"slot":0,"name":"蜂群连射炮","trait":"burst","title":"三连击","desc":"每轮连续发射 3 发，每发造成 45% 攻击伤害。"},
	{"slot":0,"name":"苍穹轨道炮","trait":"rail","title":"轨道贯穿","desc":"攻击间隔 ×1.5，伤害 ×2，射程增至 390。"},
	{"slot":0,"name":"熔星等离子炮","trait":"plasma","title":"等离子爆破","desc":"主目标伤害 ×1.1，并对其周围 150 范围敌军造成 50% 溅射。"},
	{"slot":1,"name":"棱镜反应装甲","trait":"barrier","title":"反应屏障","desc":"每 6 秒格挡下一次伤害的 60%。"},
	{"slot":1,"name":"重型复合装甲","trait":"fortress","title":"坚壁","desc":"额外减伤 18%，移动速度降低 8%。"},
	{"slot":1,"name":"纳米修复装甲","trait":"nanite","title":"自修复","desc":"非修复状态每秒恢复 1.2% 装甲。"},
	{"slot":2,"name":"离子悬浮引擎","trait":"hover","title":"悬浮推进","desc":"持续悬浮移动，速度提高 16%，留下离子光环。"},
	{"slot":2,"name":"脉冲矢量喷口","trait":"dash","title":"脉冲冲刺","desc":"移动时每 3 秒触发 0.6 秒两倍速冲刺，留下喷焰。"},
	{"slot":2,"name":"重装履带底盘","trait":"treads","title":"履带行进","desc":"速度降低 12%，额外减伤 15%，底盘替换为履带。"},
	{"slot":3,"name":"赤焰超频核心","trait":"overdrive","title":"超频","desc":"普攻间隔缩短 18%，弹道变为赤焰。"},
	{"slot":3,"name":"极光同步核心","trait":"charge","title":"能量回流","desc":"技能每秒额外充能 3 点，弹道变为冰蓝。"},
	{"slot":3,"name":"鹰眼演算核心","trait":"precision","title":"弱点演算","desc":"暴击率额外提高 15%，暴击造成双倍伤害。"},
	{"slot":5,"name":"霜翼散热背包","trait":"cooler","title":"散热翼","desc":"每秒额外散热 18 点。"},
	{"slot":5,"name":"疾风推进背包","trait":"boost_pack","title":"矢量推进","desc":"移速额外提高 12%，需要较高供能，散热较低。"},
	{"slot":5,"name":"远航储能背包","trait":"battery","title":"辅助供能","desc":"额外提供 50 点供能，适合双重型武器。"},
	{"slot":0,"name":"白炽粒子束","trait":"laser","title":"持续照射","desc":"持续 0.75 秒照射，每 0.1 秒按实际射线判定，需维持射界。"},
	{"slot":0,"name":"鸢尾追踪导弹","trait":"missile","title":"锁定制导","desc":"导弹转向追踪目标，命中引爆；飞行与爆炸按实际位置结算。"},
	{"slot":0,"name":"掘墓者·钨芯轨道炮","trait":"rail","title":"钨芯重击","signature":"pierce","damage_factor":1.12,"interval_factor":1.2,"desc":"命名蓝图：轨道炮单发伤害提高12%，间隔延长20%；产热与重量更高。出厂机制为贯穿，占用原有机制位。"},
	{"slot":0,"name":"白噪·脉冲激光器","trait":"laser","title":"冷站聚焦","signature":"pulse","damage_factor":1.1,"interval_factor":1.15,"desc":"命名蓝图：伤害提高10%，间隔延长15%；供能和产热更高。出厂机制为脉冲，占用原有机制位。"},
	{"slot":0,"name":"沙海·蜂群弹舱","trait":"missile","title":"试验弹舱","signature":"swarm","damage_factor":1.05,"interval_factor":1.1,"desc":"命名蓝图：伤害提高5%，间隔延长10%；产热更高。出厂机制为蜂群，占用原有机制位。"},
	{"slot":3,"name":"轨道·电离反应炉","trait":"precision","title":"轨道供能","signature":"ion","supply_bonus":20,"desc":"命名蓝图：额外供能20，重量更高；保留弱点演算。出厂机制为电离，占用原有机制位。"},
	{"slot":0,"name":"焰刃能量剑","trait":"blade","title":"近战横斩","desc":"射程120，基础间隔1秒；前摇0.18秒后挥出120度扇形斩击，造成160%热能伤害，最多命中4个目标。同次挥击不重复命中。"},
	{"slot":0,"name":"破阵动力拳套","trait":"gauntlet","title":"三段格斗","desc":"射程84，基础间隔0.95秒；依次在0.10、0.24、0.40秒打出三拳，每拳造成62%动能伤害。每拳独立检查距离、朝向与障碍，离开拳路可躲开后续连击。"},
	{"slot":0,"name":"震岳重型战锤","trait":"hammer","title":"蓄力重击","desc":"射程108，基础间隔1.6秒；前摇0.36秒后打出100度重击，造成280%动能伤害，最多命中3个目标。较慢的出手需要保持贴近。"},
	{"slot":0,"name":"堡垒防暴盾","trait":"hand_shield","title":"正面格挡","desc":"占用一只手，自动面向交战目标。正面120度内的直射攻击可格挡60%伤害并消耗等量格挡耐久；背后攻击和地面范围攻击不能格挡。基础耐久60，稀有/史诗为80/100；耗尽后破防2秒，停受击2秒后每秒恢复12耐久。另一只手可搭配剑、拳套或枪械。"}
]
const AFFIXES = {
	"attack":{"name":"火力","min":3,"max":8,"unit":""},
	"haste":{"name":"攻速","min":2,"max":5,"unit":"%"},
	"speed":{"name":"移速","min":2,"max":6,"unit":"%"},
	"armor":{"name":"减伤","min":1,"max":4,"unit":"%"},
	"crit":{"name":"暴击率","min":2,"max":5,"unit":"%"},
	"energy":{"name":"每秒充能","min":1,"max":2,"unit":""}
}
var inventory: Array = []
const CHASSIS = preload("res://scripts/mechs.gd")
var loadouts: Array = []
var presets: Array = []
var next_id: int = 1
var overflow: Array = []
var research: Dictionary = {}
var reforge: Dictionary = {}
var research_materials: int = 0

func _init() -> void:
	reset_chassis_slots()

func reset_chassis_slots() -> void:
	loadouts.clear(); presets.clear()
	for _model in CHASSIS.MODELS:
		loadouts.append({}); presets.append([])

func starter() -> void:
	inventory.clear()
	reset_chassis_slots()
	overflow.clear(); research.clear(); reforge.clear()
	research_materials = 0
	next_id = 1
	for index in [0,3,6,10,1,7,12]:
		var part := roll(index,0)
		if part.slot!=0: part.mechanism = ""
		if index==0: part.mechanism = "pierce"
		if index==1: part.mechanism = "bounce"
		if inventory.size()<=4 or index==12: loadouts[0][str(part.slot)] = part.id
		if index==1: loadouts[0]["4"] = part.id

func roll(blueprint: int = -1, quality: int = -1, protect_drop: bool = false) -> Dictionary:
	if inventory.size()>=LIMIT and not protect_drop: return {}
	if blueprint<0: blueprint = BASIC_BLUEPRINTS.pick_random()
	if quality<0:
		var chance := randf()
		quality = 2 if chance<0.1 else 1 if chance<0.4 else 0
	blueprint = clampi(blueprint,0,BLUEPRINTS.size()-1)
	quality = clampi(quality,0,2)
	var pool := AFFIXES.keys()
	pool.shuffle()
	var affixes: Array = []
	for i in range(quality+1):
		var stat: String = pool[i]
		affixes.append({"stat":stat,"value":randi_range(AFFIXES[stat].min,AFFIXES[stat].max)*(quality+1)})
	var part := {"id":next_id,"blueprint":blueprint,"slot":BLUEPRINTS[blueprint].slot,"quality":quality,"affixes":affixes,"level":1,"locked":false,"favorite":false,"reforge_slot":-1}
	part["mechanism"] = ""
	var compatible := mechanism_pool(blueprint)
	if not compatible.is_empty() and (part.slot==0 or randf()<0.35+quality*0.3): part.mechanism = compatible.pick_random()
	if BLUEPRINTS[blueprint].has("signature"): part.mechanism = BLUEPRINTS[blueprint].signature
	next_id += 1
	if inventory.size()>=LIMIT: overflow.append(part)
	else: inventory.append(part)
	return part

func find_part(id: int) -> Dictionary:
	for part in inventory:
		if part.id==id: return part
	return {}

func find_any(id: int) -> Dictionary:
	var part := find_part(id)
	if not part.is_empty(): return part
	for extra in overflow:
		if extra.id==id: return extra
	return {}

func collect_overflow() -> int:
	var count := 0
	while inventory.size()<LIMIT and not overflow.is_empty():
		inventory.append(overflow.pop_front())
		count += 1
	return count

func set_flag(id: int, flag: String, value: bool) -> bool:
	if flag not in ["locked","favorite"]: return false
	var part := find_part(id)
	if part.is_empty(): return false
	# The legacy favorite API maps to the single lock flag.
	part.locked = value
	part.favorite = false
	return true

func is_locked(part: Dictionary) -> bool:
	return bool(part.get("locked",false)) or bool(part.get("favorite",false))

func matches(part: Dictionary, slot: int = -1, mechanism: String = "all", locked_only: bool = false) -> bool:
	return (slot<0 or fits_slot(part,slot)) and (mechanism=="all" or part.get("mechanism","")==mechanism) and (not locked_only or is_locked(part))

func recyclable(part: Dictionary) -> bool:
	return owner(part.id)<0 and not protected(part.id) and not is_locked(part) and int(reforge.get("id",0))!=int(part.id)

func recycle_candidates(slot: int = -1, mechanism: String = "all", locked_only: bool = false) -> Array:
	return inventory.filter(func(part): return matches(part,slot,mechanism,locked_only) and recyclable(part))

func begin_reforge(id: int, index: int) -> bool:
	var part := find_part(id)
	if part.is_empty() or not reforge.is_empty() or index<0 or index>=part.affixes.size(): return false
	if int(part.get("reforge_slot",-1))>=0 and int(part.reforge_slot)!=index: return false
	part.reforge_slot = index
	var pool: Array = AFFIXES.keys()
	for i in range(part.affixes.size()):
		if i!=index: pool.erase(part.affixes[i].stat)
	pool.shuffle()
	var choices: Array = []
	for stat in pool.slice(0,3): choices.append({"stat":stat,"value":randi_range(AFFIXES[stat].min,AFFIXES[stat].max)*(int(part.quality)+1)})
	reforge = {"id":id,"choices":choices}
	return true

func resolve_reforge(choice: int) -> bool:
	if reforge.is_empty() or choice< -1 or choice>=3: return false
	var part := find_part(int(reforge.id))
	if part.is_empty(): return false
	var index: int = part.get("reforge_slot",-1)
	if index<0 or index>=part.affixes.size(): return false
	if choice>=0: part.affixes[index] = reforge.choices[choice].duplicate(true)
	reforge.clear()
	return true

func research_ready(mechanism: String) -> bool:
	return MECHANISMS.has(mechanism) and int(research.get(mechanism,0))>=RESEARCH_TARGET

func install_mechanism(id: int, mechanism: String) -> bool:
	var part := find_part(id)
	if part.is_empty() or not research_ready(mechanism) or mechanism not in mechanism_pool(int(part.blueprint)) or part.get("mechanism","")==mechanism: return false
	part.mechanism = mechanism
	return true

func upgrade_limit(stage: int) -> int:
	return mini(20,1+int(maxi(0,stage-1)/5.0))

func upgrade_part(id: int, stage: int) -> bool:
	var part := find_part(id)
	if part.is_empty() or int(part.get("level",1))>=upgrade_limit(stage) or int(reforge.get("id",0))==id: return false
	part.level = int(part.get("level",1))+1
	return true

func equipped(mech: int, slot: int) -> Dictionary:
	return find_part(int(loadouts[mech].get(str(slot),0)))

func owner(id: int) -> int:
	for i in range(loadouts.size()):
		if id in loadouts[i].values(): return i
	return -1

func equip(mech: int, id: int, target_slot: int = -1) -> bool:
	var part := find_part(id)
	if part.is_empty() or mech<0 or mech>=loadouts.size(): return false
	if target_slot<0: target_slot = part.slot
	if not fits_slot(part,target_slot): return false
	for loadout in loadouts:
		for slot in loadout.keys():
			if int(loadout[slot])==id: loadout.erase(slot)
	loadouts[mech][str(target_slot)] = id
	return true

func unequip(mech: int, slot: int) -> bool:
	return loadouts[mech].erase(str(slot))

func recycle(id: int) -> int:
	var part := find_part(id)
	if part.is_empty() or owner(id)>=0 or protected(id) or is_locked(part) or int(reforge.get("id",0))==id: return 0
	var reward := 6*(int(part.quality)+1)
	var mechanism: String = part.get("mechanism","")
	if mechanism!="": research[mechanism] = mini(RESEARCH_TARGET,int(research.get(mechanism,0))+int(part.quality)+1)
	inventory.erase(part)
	return reward

func recycle_fresh_common(id: int) -> int:
	var part := find_any(id)
	if part.is_empty() or int(part.quality)!=0 or not recyclable(part): return 0
	var mechanism: String = part.get("mechanism","")
	if mechanism!="": research[mechanism] = mini(RESEARCH_TARGET,int(research.get(mechanism,0))+1)
	if part in inventory: inventory.erase(part)
	else: overflow.erase(part)
	return 6

func invest_research(mechanism: String) -> int:
	if not MECHANISMS.has(mechanism): return 0
	var used := mini(research_materials,maxi(0,RESEARCH_TARGET-int(research.get(mechanism,0))))
	if used<=0: return 0
	research_materials -= used
	research[mechanism] = int(research.get(mechanism,0))+used
	return used

func has_trait(mech: int, trait_id: String) -> bool:
	for slot in range(SLOTS.size()):
		var part := equipped(mech,slot)
		if not part.is_empty() and BLUEPRINTS[part.blueprint].trait==trait_id: return true
	return false

func stats(mech: int) -> Dictionary:
	var result := {"attack":0.0,"haste":0.0,"speed":0.0,"armor":0.0,"crit":0.0,"energy":0.0,"shield":0.0,"counter":0.0,"guard_capacity":0.0}
	for slot in range(SLOTS.size()):
		var part := equipped(mech,slot)
		if part.is_empty(): continue
		# Each slot has an inherent bonus, separate from its random affixes.
		var category: int = 0 if slot==4 else slot
		var growth := 1.0+0.1*(int(part.get("level",1))-1)
		if BLUEPRINTS[part.blueprint].trait=="hand_shield": result.guard_capacity = maxf(result.guard_capacity,(60+20*int(part.quality))*growth)
		elif category<4: result[["attack","armor","speed","energy"][category]] += [5,3,4,1][category]*(int(part.quality)+1)*growth
		for affix in part.affixes: result[affix.stat] += float(affix.value)*growth
	var torso := equipped(mech,1)
	if not torso.is_empty() and torso.blueprint==3: result.shield = 20*(int(torso.quality)+1)*(1.0+0.1*(int(torso.get("level",1))-1))
	if has_trait(mech,"fortress"):
		result.armor += 18; result.speed -= 8
	if has_trait(mech,"hover"): result.speed += 16
	if has_trait(mech,"treads"):
		result.speed -= 12; result.armor += 15
	if has_trait(mech,"precision"): result.crit += 15
	if has_trait(mech,"charge"): result.energy += 3
	if has_trait(mech,"boost_pack"): result.speed += 12
	if mechanism_active(mech,"counter"): result.counter = 1
	result.armor = minf(65,result.armor)
	result.haste = minf(50,result.haste)
	result.crit = minf(75,result.crit)
	return result

func name_of(part: Dictionary) -> String:
	return "空槽位" if part.is_empty() else BLUEPRINTS[part.blueprint].name

func affix_text(part: Dictionary) -> String:
	var lines := PackedStringArray()
	for affix in part.affixes:
		var info: Dictionary = AFFIXES[affix.stat]
		lines.append("%s +%d%s" % [info.name,affix.value,info.unit])
	return "  ·  ".join(lines)

func export_save() -> Dictionary:
	var saved := {"schema":3,"research_materials":research_materials,"research":research.duplicate(true),"reforge":reforge.duplicate(true),"overflow":overflow.duplicate(true),"presets":presets.duplicate(true),"inventory":inventory.duplicate(true),"loadouts":loadouts.duplicate(true),"next_id":next_id}
	for field in ["inventory","overflow"]:
		for part in saved[field]: part.locked = is_locked(part); part.favorite = false
	return saved

func import_save(data: Variant) -> void:
	if not data is Dictionary:
		starter()
		return
	inventory.clear()
	reset_chassis_slots()
	overflow.clear(); research.clear(); reforge.clear()
	research_materials = int(data.get("research_materials",0)) if valid_integer(data.get("research_materials",0),0,1000000) else 0
	next_id = 1
	var main_items = data.get("inventory",[])
	var overflow_items = data.get("overflow",[])
	var items: Array = (main_items if main_items is Array else []).duplicate()
	var main_count: int = mini(LIMIT,items.size())
	if overflow_items is Array: items.append_array(overflow_items)
	if items is Array:
		for item in items:
			if not item is Dictionary: continue
			if not valid_integer(item.get("id"),1,1000000000) or not valid_integer(item.get("blueprint"),0,BLUEPRINTS.size()-1) or not valid_integer(item.get("quality"),0,2): continue
			var id := int(item.id)
			if not find_any(id).is_empty(): continue
			var affixes: Array = []
			var used: Array = []
			var raw = item.get("affixes",[])
			if raw is Array:
				for affix in raw:
					if affixes.size()>=int(item.quality)+1: break
					if not affix is Dictionary or not affix.get("stat") is String: continue
					var stat: String = affix.stat
					if not AFFIXES.has(stat) or stat in used: continue
					if not valid_integer(affix.get("value"),1,int(AFFIXES[stat].max)*(int(item.quality)+1)): continue
					used.append(stat)
					affixes.append({"stat":stat,"value":int(affix.value)})
			var mechanism = item.get("mechanism","")
			if not mechanism is String or mechanism not in mechanism_pool(int(item.blueprint)): mechanism = ""
			var level: int = int(item.get("level",1)) if valid_integer(item.get("level",1),1,20) else 1
			var calibration: int = int(item.get("reforge_slot",-1)) if valid_integer(item.get("reforge_slot",-1),-1,affixes.size()-1) else -1
			var part := {"mechanism":mechanism,"id":id,"blueprint":int(item.blueprint),"slot":BLUEPRINTS[int(item.blueprint)].slot,"quality":int(item.quality),"affixes":affixes,"level":level,"locked":item.get("locked",false)==true or item.get("favorite",false)==true,"favorite":false,"reforge_slot":calibration}
			if inventory.size()<main_count: inventory.append(part)
			else: overflow.append(part)
			next_id = maxi(next_id,id+1)
	if valid_integer(data.get("next_id"),1,1000000001): next_id = maxi(next_id,int(data.next_id))
	var saved = data.get("loadouts",[])
	if saved is Array:
		for mech in range(mini(saved.size(),loadouts.size())):
			if not saved[mech] is Dictionary: continue
			for slot in range(SLOTS.size()):
				var id = saved[mech].get(str(slot),0)
				if not valid_integer(id,1,1000000000): continue
				var part := find_part(int(id))
				if not part.is_empty() and fits_slot(part,slot) and owner(int(id))<0:
					loadouts[mech][str(slot)] = int(id)

	var raw_presets = data.get("presets",[])
	if raw_presets is Array:
		for mech in range(mini(raw_presets.size(),presets.size())):
			if not raw_presets[mech] is Array: continue
			for raw in raw_presets[mech].slice(0,3):
				var preset: Dictionary = {}
				if raw is Dictionary:
					for slot in range(SLOTS.size()):
						var id = raw.get(str(slot),0)
						if not valid_integer(id,1,1000000000): continue
						var part := find_part(int(id))
						if not part.is_empty() and fits_slot(part,slot) and int(id) not in preset.values(): preset[str(slot)] = int(id)
				presets[mech].append(preset)
	var raw_research = data.get("research",{})
	if raw_research is Dictionary:
		for key in MECHANISMS:
			if raw_research.has(key) and valid_integer(raw_research[key],0,RESEARCH_TARGET): research[key] = int(raw_research[key])
	var pending = data.get("reforge",{})
	if pending is Dictionary:
		var target := find_part(int(pending.get("id",0))) if valid_integer(pending.get("id",0),1,1000000000) else {}
		var index: int = target.get("reforge_slot",-1)
		var proposals = pending.get("choices",[])
		if not target.is_empty() and index>=0 and index<target.affixes.size() and proposals is Array and proposals.size()==3:
			var valid := true
			for choice in proposals:
				if not choice is Dictionary: valid = false; break
				if not choice.get("stat","") is String: valid = false; break
				var stat: String = choice.get("stat","")
				if not AFFIXES.has(stat) or not valid_integer(choice.get("value"),int(AFFIXES[stat].min)*(int(target.quality)+1),int(AFFIXES[stat].max)*(int(target.quality)+1)): valid = false; break
				for i in range(target.affixes.size()):
					if i!=index and target.affixes[i].stat==stat: valid = false
			if valid: reforge = {"id":target.id,"choices":proposals.duplicate(true)}

func protected(id: int) -> bool:
	for mech_presets in presets:
		for preset in mech_presets:
			if id in preset.values(): return true
	return false

func save_preset(mech: int, index: int) -> bool:
	if mech<0 or mech>=loadouts.size() or index<0 or index>=3: return false
	while presets[mech].size()<=index: presets[mech].append({})
	presets[mech][index] = loadouts[mech].duplicate(true)
	return true

func apply_preset(mech: int, index: int) -> bool:
	if mech<0 or mech>=loadouts.size() or index<0 or index>=presets[mech].size(): return false
	var preset: Dictionary = presets[mech][index]
	var seen: Array = []
	for slot in preset:
		if int(preset[slot]) in seen: return false
		seen.append(int(preset[slot]))
		var part := find_part(int(preset[slot]))
		if part.is_empty() or not fits_slot(part,int(slot)): return false
	loadouts[mech].clear()
	for slot in preset: equip(mech,int(preset[slot]),int(slot))
	return true

func fits_slot(part: Dictionary, slot: int) -> bool:
	return slot>=0 and slot<SLOTS.size() and (int(part.slot)==slot or (int(part.slot)==0 and slot==4))

func specs(part: Dictionary) -> Dictionary:
	if part.is_empty(): return {"weight":0.0,"power":0.0,"heat":0.0,"cooling":0.0}
	var index: int = part.blueprint
	var weights := [18,36,38,22,40,24,16,20,35,12,12,12,14,10,20,26,32,40,30,34,18,22,18,42,30]
	var powers := [18,40,44,8,6,14,30,18,4,0,0,0,20,25,0,50,42,44,54,46,0,24,12,18,8]
	var heating := [9,40,30,0,0,0,0,0,0,0,0,0,0,0,0,28,36,44,32,40,0,8,3,5,0]
	return {"weight":float(weights[index])+int(part.quality)*2,"power":float(powers[index])+int(part.quality)*2 if part.slot!=3 else 0.0,"heat":float(heating[index])+int(part.quality)*2 if part.slot==0 else 0.0,"cooling":18.0+int(part.quality)*4 if index==12 else 0.0}

func configuration(mech: int, replacement: Dictionary = {}, target_slot: int = -1) -> Dictionary:
	var loadout: Dictionary = loadouts[mech].duplicate()
	if not replacement.is_empty():
		for slot in loadout.keys():
			if int(loadout[slot])==int(replacement.id): loadout.erase(slot)
		loadout[str(replacement.slot if target_slot<0 else target_slot)] = replacement.id
	var weight: float = 0
	var power: float = 0
	var cooling: float = 12
	for id in loadout.values():
		var values := specs(find_part(int(id)))
		weight += values.weight; power += values.power; cooling += values.cooling
	var legs := find_part(int(loadout.get("2",0)))
	var core := find_part(int(loadout.get("3",0)))
	var pack := find_part(int(loadout.get("5",0)))
	var capacity: float = 100 if legs.is_empty() else (130 if legs.blueprint==6 else 220 if legs.blueprint==8 else 150)+int(legs.quality)*15
	var supply: float = 80 if core.is_empty() else 130+int(core.quality)*15
	if not core.is_empty(): supply += float(BLUEPRINTS[core.blueprint].get("supply_bonus",0))
	if not pack.is_empty() and pack.blueprint==14: supply += 50
	var valid: bool = weight<=capacity and power<=supply
	return {"vent":mechanism_active(mech,"vent"),"weight":weight,"capacity":capacity,"power":power,"supply":supply,"cooling":cooling,"valid":valid,"speed_factor":1.0-0.35*clampf((weight/capacity-0.85)/0.15,0,1),"reason":"超出腿部载重" if weight>capacity else "核心供能不足" if power>supply else "配置可出击"}

func mechanism_active(mech: int, id: String) -> bool:
	for slot in range(SLOTS.size()):
		if equipped(mech,slot).get("mechanism","")==id: return true
	return false

func tags_for(blueprint: int) -> Array:
	var slot: int = BLUEPRINTS[blueprint].slot
	if slot==1: return ["armor"]
	if slot==3: return ["reactor"]
	if slot==5: return ["backpack"]
	if slot!=0: return []
	var trait_id: String = BLUEPRINTS[blueprint].trait
	if trait_id=="hand_shield": return ["shield"]
	if preload("res://scripts/melee.gd").is_mode(trait_id): return ["melee","attack"]
	if trait_id=="laser": return ["beam","thermal","attack"]
	if trait_id=="missile": return ["missile","explosive","thermal","attack"]
	return ["projectile","kinetic","attack"] if trait_id=="burst" else ["projectile","electric","attack"] if trait_id=="rail" else ["projectile","thermal","explosive","attack"]

func mechanism_pool(blueprint: int) -> Array:
	var pool: Array = []
	var tags := tags_for(blueprint)
	for id in MECHANISMS:
		if id=="ion" and "electric" in tags: continue
		for tag in MECHANISMS[id].tags:
			if tag in tags: pool.append(id); break
	return pool

func mechanism_text(part: Dictionary) -> String:
	var id: String = part.get("mechanism","")
	return "无随机机制" if id=="" else MECHANISMS[id].name+" / "+MECHANISMS[id].desc

func valid_integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=low and value<=high
