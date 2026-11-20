extends Node
## Persistent game economy and automatic combat. UI is a consumer of these signals.
signal changed
signal shot(friendly: bool, damage: int)
signal message(text: String)
signal victory
signal feedback(kind: String)
signal attack_hit(point: Vector2, damage: int, mode: String)
signal weapon_fired(mode: String, from: Vector2, target: Vector2, critical: bool)
signal pilot_radio(kind: String, pilot: int)
signal field_effect(kind: String, point: Vector2, target: Vector2)
const NARRATIVE = preload("res://scripts/narrative.gd")
var narrative = NARRATIVE.new()
var story_paused: bool = false

const PARTS = preload("res://scripts/parts.gd")
var parts = PARTS.new()
const MECHS = preload("res://scripts/mechs.gd")
const MELEE = preload("res://scripts/melee.gd")
var mechs = MECHS.new()
var selected_mech: int = 0
const PILOT_RUNTIME = preload("res://scripts/pilot_runtime.gd")
const PILOT_ROSTER = preload("res://scripts/pilot_roster.gd")
var pilot_runtime = PILOT_RUNTIME.new()
var pilot_roster = PILOT_ROSTER.new()
const RIG_RUNTIME = preload("res://scripts/rig_runtime.gd")
const TACTICS = preload("res://scripts/tactics.gd")
var tactics: Array = fresh_tactics()
var tactic_presets: Array = fresh_tactic_presets()
const EXPEDITION = preload("res://scripts/expedition.gd")
var expedition = EXPEDITION.new()
const CARRIER_SYSTEM = preload("res://scripts/carrier_system.gd")
var carrier = CARRIER_SYSTEM.new()
const SALVAGE = preload("res://scripts/salvage_ledger.gd")
var salvage = SALVAGE.new()
var certification_job: RefCounted = null
var certification_committed: bool = false
var certification_result_id: String = ""
var settlement_clock_override: float = -1
var rig = RIG_RUNTIME.new()
var burst_left: int:
	get: return int(rig.weapons[0].pending)
	set(value): rig.weapons[0].pending = value
var burst_clock: float:
	get: return float(rig.weapons[0].burst_clock)
	set(value): rig.weapons[0].burst_clock = value
var burst_target: String:
	get: return str(rig.weapons[0].target)
	set(value): rig.weapons[0].target = value
const DEFENSE_RUNTIME = preload("res://scripts/defense_runtime.gd")
var defense = DEFENSE_RUNTIME.new()
var barrier_clock: float:
	get: return defense.barrier_clock
	set(value): defense.barrier_clock = value

const PILOTS = [
	{"name": "绯夜", "code": "SCARLET", "role": "强袭型", "age": 26, "color": Color("ff5467"), "skill": "绯红歼灭", "bio": "前线的王牌。她的战术很简单——在敌人锁定之前，结束战斗。"},
	{"name": "鸦羽", "code": "RAVEN", "role": "狙击型", "age": 28, "color": Color("b49aff"), "skill": "寂静裁决", "bio": "冷静而精准的远程专家。没有目标能逃过她的视线。"},
	{"name": "凛", "code": "FROST", "role": "支援型", "age": 25, "color": Color("7ddfff"), "skill": "极光脉冲", "bio": "极地防线的守护者。冰蓝的装甲之下，是炽热的战意。"},
	{"name":"雷娜","code":"REINA","role":"格斗型","age":27,"color":Color("ffad69"),"skill":"苍炎断空","bio":"二十七岁的突击教官。用精准的步法切入火线，在最短的距离内结束交锋。"},
	{"name":"星澜","code":"ASTER","role":"导弹型","age":29,"color":Color("80d7a0"),"skill":"群星齐射","bio":"二十九岁的舰载火控专家。她把每一条制导航迹编成封锁敌人的星图。"},
	{"name":"伊芙","code":"EVE","role":"能源型","age":30,"color":Color("f1ce7a"),"skill":"曙光回路","bio":"三十岁的反应炉工程师。她擅长重新分配能量，让队伍在持续交火中保有余力。"}
]
const SAVE_VERSION = 1
var credits: int = 2400
var cores: int = 120
var gems: int = 900
var levels: Array = initial_pilot_levels()
var unlocked: Array = initial_pilot_unlocks()
var selected: int = 0
var stage: int = 1
var wins: int = 0
var upgrades: int = 0
var recruits: int = 0
var claimed: Array = []
var auto: bool = true
var auto_skill: bool = true
var energy: float = 25.0
var hp: float:
	get: return defense.hp
	set(value): defense.hp = value
var enemy_hp: float = 100.0
var enemy_max: float = 100.0
var pending_credits: int:
	get: return int(salvage.pending().credits)
	set(value): salvage.override_legacy("credits",value)
var pending_cores: int:
	get: return int(salvage.pending().cores)
	set(value): salvage.override_legacy("cores",value)
var offline_seconds: int = 0
var battle_clock: float:
	get: return float(rig.weapons[0].clock)
	set(value): rig.weapons[0].clock = value
var idle_clock: float = 0.0
var save_clock: float = 0.0
var recovery: float = 0.0
var last_result: String = ""
var last_pull: Array = []
var sound_enabled: bool = true
var test_mode: bool = false
var save_override: String = ""
var core_clock: float = 0.0
var cloud_binding: Dictionary = {}
var world_save: Dictionary = {"docked":true}
var world_override: Node = null
var combat_rng: RandomNumberGenerator = null

static func initial_pilot_levels() -> Array:
	var result: Array = []
	for _pilot in PILOTS: result.append(1)
	return result

static func initial_pilot_unlocks() -> Array:
	var result: Array = []
	for i in range(PILOTS.size()): result.append(i<2)
	return result

static func fresh_tactics() -> Array:
	var result: Array = []
	for _model in MECHS.MODELS: result.append(TACTICS.defaults())
	return result

static func fresh_tactic_presets() -> Array:
	var result: Array = []
	for _model in MECHS.MODELS: result.append([])
	return result

func combat_world() -> Node:
	return world_override if is_instance_valid(world_override) else get_node_or_null("/root/World")

func combat_randomf() -> float:
	return combat_rng.randf() if combat_rng!=null else randf()

func combat_randomi(low: int, high: int) -> int:
	return combat_rng.randi_range(low,high) if combat_rng!=null else randi_range(low,high)

func settlement_now() -> float:
	if settlement_clock_override>=0: return settlement_clock_override
	if not cloud_binding.is_empty():
		var cloud = get_node_or_null("/root/Cloud")
		return cloud.trusted_now() if cloud!=null else salvage.cursor
	return Time.get_unix_time_from_system()

func _ready() -> void:
	test_mode = "--test" in OS.get_cmdline_user_args()
	salvage.anchor(settlement_now())
	parts.starter()
	narrative.unlock("prologue")
	defense.configure(equipment_stats(),true)
	if not test_mode:
		load_game()
	if not World.boss.active: reset_enemy()

func save_path() -> String:
	if save_override != "": return save_override
	if OS.has_feature("web"):
		return "user://crimson_front_v1.json"
	return ProjectSettings.globalize_path("res://.local/save.json")

func total_attack() -> int:
	var value := 0
	for i in range(mini(PILOTS.size(),mini(unlocked.size(),levels.size()))):
		if unlocked[i]:
			value += 17 + int(levels[i]) * 7
	return value + int(equipment_stats().attack)

func power() -> int:
	var stats: Dictionary = equipment_stats()
	return total_attack()*37+mech_level()*120+int((stats.haste+stats.crit+stats.armor)*12+stats.speed*6+stats.energy*35)

func mech_level() -> int:
	return int(mechs.units[selected_mech].level)

func equipment_stats(mech: int = -1, equipment: Variant = null) -> Dictionary:
	if mech<0: mech = selected_mech
	var source = parts if equipment==null else equipment
	var result: Dictionary = source.stats(mech)
	var chassis: Dictionary = mechs.stats(mech)
	result.attack += chassis.attack
	result.shield += chassis.shield
	return result

func mech_configuration(mech: int = -1, equipment: Variant = null) -> Dictionary:
	if mech<0: mech = selected_mech
	var source = parts if equipment==null else equipment
	var result: Dictionary = source.configuration(mech)
	var chassis: Dictionary = mechs.stats(mech)
	for key in ["cooling","capacity","supply"]: result[key] += chassis[key]
	result.base_speed = float(MECHS.MODELS[mechs.units[mech].model].speed)
	result.valid = result.weight<=result.capacity and result.power<=result.supply
	result.speed_factor = 1.0-0.35*clampf((result.weight/result.capacity-0.85)/0.15,0,1)
	result.reason = "超出机体载重" if result.weight>result.capacity else "核心供能不足" if result.power>result.supply else "配置可出击"
	var has_shield := false
	var has_attack := false
	for slot in [0,4]:
		var part: Dictionary = source.equipped(mech,slot)
		if part.is_empty(): continue
		if PARTS.BLUEPRINTS[part.blueprint].trait=="hand_shield": has_shield = true
		else: has_attack = true
	if has_shield and not has_attack: result.valid = false; result.reason = "盾牌需搭配攻击武器"
	return result

func mech_upgrade_cost() -> int:
	return 140+mech_level()*85

func mech_core_cost() -> int:
	return 5+mech_level()*2

func upgrade_mech() -> bool:
	if mech_level()>=9999 or credits<mech_upgrade_cost() or cores<mech_core_cost():
		message.emit("资源不足或机体等级已满")
		return false
	credits -= mech_upgrade_cost(); cores -= mech_core_cost()
	mechs.units[selected_mech].level = mech_level()+1
	upgrades += 1
	feedback.emit("upgrade")
	message.emit(mechs.name_of(selected_mech)+"强化成功 · Lv.%02d" % mech_level())
	changed.emit(); save_game()
	return true

func choose_mech(index: int) -> bool:
	if index<0 or index>=mechs.units.size() or not World.docked or recovery>0: return false
	if index==selected_mech: return true
	selected_mech = index
	World.tactical.reset()
	reset_part_combat()
	changed.emit(); save_game()
	return true

func upgrade_cost(i: int) -> int:
	return 140 + int(levels[i]) * 85

func core_cost(i: int) -> int:
	return 5 + int(levels[i]) * 2

func upgrade(i: int) -> bool:
	if i<0 or i>=PILOTS.size() or i>=unlocked.size(): return false
	if not unlocked[i]:
		message.emit("招募这位机师后即可强化")
		return false
	if credits < upgrade_cost(i) or cores < core_cost(i):
		message.emit("资源不足，领取补给或继续挂机积累")
		return false
	credits -= upgrade_cost(i)
	cores -= core_cost(i)
	levels[i] = int(levels[i]) + 1
	upgrades += 1
	feedback.emit("upgrade")
	message.emit("%s强化成功 · Lv.%02d" % [PILOTS[i].name, levels[i]])
	changed.emit()
	save_game()
	return true

func choose(i: int) -> void:
	if i<0 or i>=PILOTS.size() or i>=unlocked.size(): return
	if not unlocked[i]:
		message.emit("前往招募可定向邀请这位机师")
		return
	if selected!=i:
		flush_pilot_progress()
		var cooldown: float = pilot_runtime.passive_cooldown
		pilot_runtime = PILOT_RUNTIME.new(); pilot_runtime.passive_cooldown = cooldown
	selected = i
	pilot_runtime.pilot_id = selected
	story_event("select",i)
	World.tactical.reset()
	reset_part_combat()
	changed.emit()
	save_game()

func reset_enemy() -> void:
	enemy_max = (100.0 + stage * 32.0) * (2.0 if stage % 5 == 0 else 1.0)
	enemy_hp = enemy_max

func _process(delta: float) -> void:
	var cloud = get_node_or_null("/root/Cloud")
	if cloud!=null and cloud.holds_combat(): return
	salvage.catch_up(settlement_now())
	advance(delta,false)

func advance(delta: float, passive_clock: bool = true) -> void:
	if story_paused and world_override==null: return
	if certification_job!=null and not certification_committed and world_override==null:
		certification_job.advance(24)
		if certification_job.done:
			certification_committed = true
			if certification_job.success:
				certification_result_id = salvage.add_certificate(certification_job.result(),certification_job.snapshot.pilot_name)
				message.emit("自动清剿认证通过 · 可启用已保存的回收方案")
			else: message.emit("认证未通过 · "+certification_job.reason)
			changed.emit(); save_game()
	var pilot_world = combat_world()
	var in_combat: bool = pilot_world!=null and pilot_world.enabled and not pilot_world.docked and recovery<=0
	pilot_runtime.advance(delta,selected,rig,defense,pilot_world.actual_velocity.length_squared()>1 if in_combat else false,in_combat)
	var cooling_config: Dictionary = combat_configuration()
	cooling_config.cooling += pilot_runtime.cooling_bonus(selected,rig.heat)
	var granted := rig.cool(delta,cooling_config)
	flush_pilot_progress()
	if granted>0: defense.grant_temporary(granted,3)
	if granted>0 and world_override==null and pilot_world!=null and not pilot_world.docked:
		field_effect.emit("vent",pilot_world.position,Vector2.ZERO)
	var world = combat_world()
	if granted>0 and world!=null and world.enabled and not world.docked: world.attacks.stats.triggers += 1
	if world != null and world.enabled:
		world.advance(delta)
		defense.guard_facing = world.guard_direction()
	idle_clock += delta
	save_clock += delta
	if idle_clock >= 1.0:
		var seconds := int(idle_clock)
		idle_clock -= seconds
		if passive_clock: salvage.accrue(seconds)
		changed.emit()
	if save_clock >= 10.0:
		save_clock = 0
		save_game()
	if not auto:
		return
	if recovery > 0:
		recovery -= delta
		if recovery <= 0:
			hp = 100
			reset_enemy()
			if world != null and world.enabled: world.enter_base()
			save_game()
			changed.emit()
		return
	if world != null and world.enabled and world.docked: return
	defense.advance(delta,equipment_stats(),parts.has_trait(selected_mech,"nanite"))
	energy = minf(100.0, energy + delta * (4.5+equipment_stats().energy+pilot_runtime.energy_bonus(selected)))
	if world != null and world.enabled:
		if selected in [2,5] and auto_skill and energy>=100 and world.auto_skill_allowed(): ultimate()
		if not world.target_in_range():
			rig.reset_clocks()
			return
		if auto_skill and energy>=100 and world.auto_skill_allowed():
			ultimate()
			if not world.target_in_range(): return
	var configuration: Dictionary = combat_configuration()
	configuration.pilot_heat_factor = pilot_runtime.heat_factor(selected)
	var profiles := weapon_profiles()
	var distance: float = world.position.distance_to(world.encounter_position) if world!=null and world.enabled else 0
	var target: String = world.current_target_id() if world!=null and world.enabled else ""
	var shots_before: int = int(rig.fired_by_slot[0])+int(rig.fired_by_slot[4])
	configuration.moving = world!=null and world.enabled and world.actual_velocity.length_squared()>1
	rig.advance(delta,profiles,distance,target,configuration,func(profile): fire_profile(profile,false),active_tactics())
	if recovery<=0 and (world==null or not world.enabled) and shots_before<int(rig.fired_by_slot[0])+int(rig.fired_by_slot[4]):
		receive_enemy_hit(maxi(2,4+stage-int(total_attack()/22.0)))
	changed.emit()

func weapon_mode(slot: int = 0) -> String:
	var weapon: Dictionary = parts.equipped(selected_mech,slot)
	return PARTS.BLUEPRINTS[weapon.blueprint].trait if not weapon.is_empty() else "standard"

func attack_interval(slot: int = 0) -> float:
	var mode := weapon_mode(slot)
	var base: float = MELEE.RULES[mode].interval if MELEE.is_mode(mode) else 0.9*(1.5 if mode=="rail" else 2.0 if mode=="missile" else 1.0)
	var interval: float = base/(1+equipment_stats().haste/100.0)*(0.82 if parts.has_trait(selected_mech,"overdrive") else 1.0)
	return maxf(interval,float(MELEE.RULES[mode].duration)+0.04) if MELEE.is_mode(mode) else interval

func attack_range() -> float:
	var reach := 0.0
	var equipped_weapon := false
	for slot in [0,4]:
		if not parts.equipped(selected_mech,slot).is_empty():
			equipped_weapon = true
			reach = maxf(reach,weapon_range(slot))
	return reach if equipped_weapon else weapon_range(0)

func engagement_range() -> float:
	return MELEE.engagement_range(weapon_profiles())

func movement_tactics() -> Dictionary:
	return TACTICS.resolve(active_tactics(),weapon_profiles(),selected,int(mechs.units[selected_mech].model))

func weapon_range(slot: int) -> float:
	if weapon_mode(slot)=="hand_shield": return 0.0
	if MELEE.is_mode(weapon_mode(slot)): return float(MELEE.RULES[weapon_mode(slot)].range)
	var distance: float = 390.0 if weapon_mode(slot)=="rail" else 420.0 if weapon_mode(slot)=="missile" else 350.0 if weapon_mode(slot)=="laser" else 300.0
	return distance*(1.0+mechs.stats(selected_mech).range)

func weapon_profile(slot: int) -> Dictionary:
	var weapon: Dictionary = parts.equipped(selected_mech,slot)
	if not weapon.is_empty() and PARTS.BLUEPRINTS[weapon.blueprint].trait=="hand_shield": return {}
	if weapon.is_empty() and (slot==4 or not parts.equipped(selected_mech,4).is_empty()): return {}
	var mode := weapon_mode(slot)
	var mechanism: String = weapon.get("mechanism","")
	if mode=="rail" and mechanism=="": mechanism = "pierce"
	var damage: float = total_attack()
	var other: Dictionary = parts.equipped(selected_mech,4 if slot==0 else 0)
	if not other.is_empty() and PARTS.BLUEPRINTS[other.blueprint].trait!="hand_shield":
		var growth := 1.0+0.1*(int(other.get("level",1))-1)
		damage -= 5*(int(other.quality)+1)*growth
		for affix in other.affixes:
			if affix.stat=="attack": damage -= float(affix.value)*growth
	var interval := attack_interval(slot)
	var multiplier := 0.45 if mode=="burst" else 2.0 if mode=="rail" else 1.1 if mode=="plasma" else 0.14 if mode=="laser" else 2.2 if mode=="missile" else 1.0
	if MELEE.is_mode(mode): multiplier = float(MELEE.RULES[mode].multiplier)
	if mode=="laser" and mechanism=="pulse": mode = "pulse"; interval *= 1.25; multiplier = 1.35
	if not weapon.is_empty():
		interval *= float(PARTS.BLUEPRINTS[weapon.blueprint].get("interval_factor",1.0))
		multiplier *= float(PARTS.BLUEPRINTS[weapon.blueprint].get("damage_factor",1.0))
	return {"ion":parts.equipped(selected_mech,3).get("mechanism","")=="ion","slot":slot,"id":weapon.get("id",0),"mode":mode,"mechanism":mechanism,"range":weapon_range(slot),"interval":interval,"attack":maxf(1,damage),"heat":parts.specs(weapon).heat if not weapon.is_empty() else 6.0,"multiplier":multiplier}

func weapon_profiles() -> Array:
	return [weapon_profile(0),weapon_profile(4)]

func weapon_style_summary() -> String:
	var names := PackedStringArray()
	var styles := {"burst":"移动三连射","rail":"蓄能贯穿","pulse":"蓄能脉冲","laser":"持续照射","missile":"移动锁定追踪","plasma":"范围爆破","blade":"扇形横斩","gauntlet":"三段格斗","hammer":"蓄力砸击"}
	for profile in weapon_profiles():
		if not profile.is_empty(): names.append(styles.get(profile.mode,"自动射击"))
	return " / ".join(names)

func combat_configuration() -> Dictionary:
	var configuration: Dictionary = mech_configuration()
	configuration.cooling *= expedition.cooling_factor()
	return configuration

func active_tactics() -> Dictionary:
	return tactics[selected_mech]

func set_tactic(key: String, value: String) -> bool:
	if not TACTICS.OPTIONS.has(key) or value not in TACTICS.OPTIONS[key]: return false
	if key=="heat" and value!=tactics[selected_mech][key]: rig.cooling_hold = false
	tactics[selected_mech][key] = value
	World.tactical.clock = 0
	if key=="survival": World.tactical.shield_retreat = false
	changed.emit(); save_game()
	return true

func save_configuration(index: int) -> bool:
	if not parts.save_preset(selected_mech,index): return false
	while tactic_presets[selected_mech].size()<=index: tactic_presets[selected_mech].append({})
	tactic_presets[selected_mech][index] = active_tactics().duplicate(true)
	changed.emit(); save_game()
	return true

func apply_configuration(index: int) -> bool:
	if not parts.apply_preset(selected_mech,index): return false
	if index<tactic_presets[selected_mech].size() and not tactic_presets[selected_mech][index].is_empty(): tactics[selected_mech] = TACTICS.sanitize(tactic_presets[selected_mech][index])
	World.tactical.reset()
	reset_part_combat()
	changed.emit(); save_game()
	return true

func import_tactics(data: Dictionary) -> void:
	tactics = fresh_tactics()
	tactic_presets = fresh_tactic_presets()
	var raw = data.get("tactics",[])
	if raw is Array:
		for i in range(mini(MECHS.MODELS.size(),raw.size())): tactics[i] = TACTICS.sanitize(raw[i])
	raw = data.get("tactic_presets",[])
	if raw is Array:
		for i in range(mini(MECHS.MODELS.size(),raw.size())):
			if not raw[i] is Array: continue
			for item in raw[i].slice(0,3): tactic_presets[i].append(TACTICS.sanitize(item) if item is Dictionary and not item.is_empty() else {})

func fire_weapon(mode: String, multiplier: float, slot: int = 0, charge_heat: bool = true) -> void:
	var profile := weapon_profile(slot)
	if profile.is_empty(): return
	profile.mode = mode; profile.multiplier = multiplier
	fire_profile(profile,charge_heat)

func fire_profile(profile: Dictionary, charge_heat: bool = true) -> void:
	var world = combat_world()
	if world!=null and world.enabled:
		if not world.target_in_range() or world.position.distance_to(world.encounter_position)>profile.range: return
	if charge_heat: rig.add_heat(profile.heat)
	var critical: bool = combat_randomf()*100<equipment_stats().crit
	var damage := maxi(1,int((profile.attack+combat_randomi(0,8))*profile.multiplier*(2 if critical else 1)))
	var target: Vector2 = world.encounter_position if world!=null and world.enabled else Vector2.ZERO
	weapon_fired.emit(profile.mode,world.position if world!=null else Vector2.ZERO,target,critical)
	shot.emit(true,damage)
	if world!=null and world.enabled:
		var meta := profile.duplicate(true)
		meta.target_id = world.current_target_id()
		if profile.mechanism=="swarm": meta.candidates = world.attack_targets()
		world.attacks.launch(world.position,target,damage,profile.mode,profile.mechanism,profile.id,meta)
	else: damage_enemy(damage)
	changed.emit()

func reset_part_combat() -> void:
	rig.reset_clocks()
	defense.configure(equipment_stats(),World.docked and recovery<=0)
	# Swapping parts cannot refresh a spent shield.
	barrier_clock = maxf(barrier_clock,6)
	var world = get_node_or_null("/root/World")
	if world!=null:
		world.drive_clock = 0
		world.attacks.swings.clear()

func equip_part(id: int, slot: int = -1) -> bool:
	if not parts.equip(selected_mech,id,slot): return false
	reset_part_combat()
	feedback.emit("upgrade")
	changed.emit()
	save_game()
	return true

func unequip_part(slot: int) -> bool:
	if slot<0 or slot>=PARTS.SLOTS.size() or not parts.unequip(selected_mech,slot): return false
	reset_part_combat()
	changed.emit()
	save_game()
	return true

func craft_part(blueprint: int = -1) -> Dictionary:
	if blueprint< -1 or blueprint>=PARTS.BLUEPRINTS.size(): return {}
	if blueprint in PARTS.NAMED_BLUEPRINTS and not expedition.blueprint_unlocked(blueprint):
		message.emit("通关对应区域首领后解锁此命名蓝图")
		return {}
	if parts.inventory.size()>=PARTS.LIMIT:
		message.emit("部件仓库已满，请先分解闲置部件")
		return {}
	if credits<450 or cores<15:
		message.emit("制造需要 450 信用点和 15 合金芯")
		return {}
	credits -= 450
	cores -= 15
	var part: Dictionary = parts.roll(blueprint)
	feedback.emit("reward")
	changed.emit()
	save_game()
	return part

func recycle_part(id: int) -> bool:
	var reward: int = parts.recycle(id)
	if reward<=0:
		message.emit("已装备、预设引用、锁定或待选重铸的部件受到保护")
		return false
	cores += reward
	message.emit("部件已分解 · 合金芯 +%d" % reward)
	changed.emit()
	save_game()
	return true

func set_part_flag(id: int, flag: String, value: bool) -> bool:
	if not parts.set_flag(id,flag,value): return false
	changed.emit(); save_game()
	return true

func collect_overflow() -> int:
	var count: int = parts.collect_overflow()
	message.emit("溢出仓已取回 %d 件，仍保管 %d 件" % [count,parts.overflow.size()])
	changed.emit(); save_game()
	return count

func recycle_batch(ids: Array) -> int:
	var count := 0
	var reward := 0
	for id in ids:
		var amount: int = parts.recycle(int(id))
		if amount>0: count += 1; reward += amount
	cores += reward
	message.emit("已分解 %d 件 · 合金芯 +%d · 机制研究已累计" % [count,reward])
	changed.emit(); save_game()
	return count

func reforge_part(id: int, index: int) -> bool:
	if World.enabled and (not World.docked or recovery>0): return false
	if credits<150 or cores<8:
		message.emit("重铸需要 150 信用点和 8 合金芯，费用固定")
		return false
	if not parts.begin_reforge(id,index): return false
	credits -= 150; cores -= 8
	changed.emit(); save_game()
	return true

func resolve_reforge(choice: int) -> bool:
	if not parts.resolve_reforge(choice): return false
	reset_part_combat()
	message.emit("已保留旧词条" if choice<0 else "重铸词条已替换")
	changed.emit(); save_game()
	return true

func install_mechanism(id: int, mechanism: String) -> bool:
	if World.enabled and (not World.docked or recovery>0): return false
	if credits<400 or cores<20:
		message.emit("机制安装需要 400 信用点和 20 合金芯")
		return false
	if not parts.install_mechanism(id,mechanism): return false
	credits -= 400; cores -= 20
	reset_part_combat()
	message.emit("研究机制已安装，替换原有机制")
	changed.emit(); save_game()
	return true

func upgrade_part(id: int) -> bool:
	if World.enabled and (not World.docked or recovery>0): return false
	var part: Dictionary = parts.find_part(id)
	if part.is_empty(): return false
	var level: int = part.get("level",1)
	if credits<300*level or cores<10*level:
		message.emit("部件升级需要 C%d / 合金%d" % [300*level,10*level])
		return false
	if not parts.upgrade_part(id,stage):
		message.emit("已达当前区域等级上限，或需先完成待选重铸")
		return false
	credits -= 300*level; cores -= 10*level
	reset_part_combat()
	message.emit("部件升级成功 · 原有品质、机制和词条保留")
	changed.emit(); save_game()
	return true

func receive_enemy_hit(damage: int, contact: Dictionary = {}) -> bool:
	var world := combat_world()
	if recovery>0 or hp<=0 or (world!=null and world.enabled and world.docked): return false
	var temporary_before: float = defense.temporary_shield
	if world_override==null and world!=null and world.enabled: damage = carrier.ops.mitigate(world.position,damage)
	damage = defense.hit(damage,equipment_stats(),parts.has_trait(selected_mech,"barrier"),contact)
	pilot_runtime.after_hit(selected,defense,temporary_before-defense.temporary_shield)
	flush_pilot_progress()
	if defense.counter_ready:
		defense.counter_ready = false
		if world!=null and world.enabled and not world.docked: world.attacks.counter(world,world.position,maxi(1,int(total_attack()*0.7)),int(parts.equipped(selected_mech,1).get("id",0)))
	shot.emit(false,damage)
	if hp<=0:
		recovery = 5
		last_result = "装甲耗尽 · 已由母舰回收，5 秒后完成修复"
		message.emit(last_result)
		if world!=null and world.enabled: world.on_player_down()
	changed.emit()
	return true

func damage_enemy(damage: int) -> void:
	var world := combat_world()
	if world!=null and world.enabled and world.boss.active:
		world.boss.hit(world,world.boss.target_id(),damage,"skill",world.boss.target_position())
		return
	enemy_hp -= damage
	if enemy_hp <= 0:
		reward_victory()
		reset_enemy()
		if world != null and world.enabled: world.finish_encounter()
		rig.reset_clocks()
		victory.emit()
		save_game()

func reward_victory() -> void:
	story_event("victory")
	if expedition.active() and expedition.run.phase=="explore":
		expedition.reward_enemy()
		return
	var boss := stage%5==0
	var reward := 80+stage*18
	credits += reward
	cores += 12 if boss else 3
	wins += 1
	last_result = "区域 %02d 肃清  +%d 信用点" % [stage,reward]
	stage += 1
	hp = minf(100,hp+14)
	if boss:
		gems += 100
		message.emit("首领击破！获得 100 星晶")
	if boss or randf()<0.3:
		var part: Dictionary = parts.roll(-1,2 if boss else -1,true)
		if not part.is_empty():
			message.emit(("满仓掉落已保存在溢出仓 · " if part in parts.overflow else "回收%s部件 · " % PARTS.QUALITIES[part.quality])+parts.name_of(part))

func ultimate() -> bool:
	var world = combat_world()
	if world!=null and world.enabled and (world.docked or (selected not in [2,5] and not world.target_in_range())):
		message.emit("出击后，目标进入射程即可释放攻击技能")
		return false
	if energy<100 or recovery>0 or hp<=0:
		message.emit("同步充能中 · 100% 后可释放")
		return false
	var target: Dictionary = {"id":world.current_target_id(),"p":world.encounter_position} if world!=null and world.enabled and world.target_in_range() else {"id":"legacy","p":Vector2.RIGHT}
	if not pilot_runtime.use(selected,world if world!=null and world.enabled else null,world.position if world!=null else Vector2.ZERO,target,rig,defense,total_attack(),parts.equipped(selected_mech,3).get("mechanism","")=="ion"): return false
	energy = 0
	story_event("skill")
	feedback.emit("shield" if selected in [2,5] else "rail" if selected==1 else "ultimate")
	flush_pilot_progress()
	message.emit(PILOTS[selected].name+" · "+PILOTS[selected].skill)
	changed.emit()
	return true

func record_pilot(key: String, amount: float) -> void:
	if world_override==null: pilot_roster.record(selected,key,amount)

func flush_pilot_progress() -> void:
	var progress: Dictionary = pilot_runtime.collect()
	for key in progress: record_pilot(key,float(progress[key]))

func claim_pilot_task(pilot: int, chapter: int) -> bool:
	if pilot<0 or pilot>=PILOTS.size() or pilot>=unlocked.size() or not unlocked[pilot] or not pilot_roster.claim(pilot,chapter): return false
	narrative.unlock("personal_%d_%d"%[pilot,chapter],false)
	credits += 200; parts.research_materials += 1
	message.emit("个人任务完成 · 信赖 +5 / 信用点 +200 / 研究资料 +1")
	changed.emit(); save_game()
	return true

func talk_pilot(pilot: int, chapter: int) -> String:
	if pilot<0 or pilot>=PILOTS.size() or pilot>=unlocked.size() or not unlocked[pilot]: return ""
	var text: String = pilot_roster.talk(pilot,chapter)
	if text!="":
		narrative.unlock("talk_%d_%d"%[pilot,chapter],false)
		story_event("talk")
		changed.emit(); save_game()
	return text

func idle_rate() -> int:
	return int(float(salvage.active_record().rates.credits)/3600.0)

func start_certification(region: int) -> bool:
	if region<0 or region>=4 or expedition.clears[region]<=0 or not World.docked or recovery>0: return false
	if certification_job!=null and not certification_job.done: return false
	if salvage.certificates.size()>=256: message.emit("认证档案已满，请先删除不再使用的旧档案"); return false
	if not mech_configuration().valid: message.emit("装机约束不满足，请先调整配装"); return false
	var simulator = load("res://scripts/certification.gd")
	var snapshot: Dictionary = simulator.capture(self)
	certification_job = simulator.new(snapshot,region)
	certification_committed = false; certification_result_id = ""
	changed.emit()
	return true

func cancel_certification() -> void:
	certification_job = null; certification_committed = false; certification_result_id = ""
	changed.emit()

func activate_salvage(id: String) -> bool:
	if id!="base":
		var record: Dictionary = {}
		for candidate in salvage.certificates:
			if candidate.id==id: record = candidate
		if record.is_empty() or expedition.clears[int(record.region)]<=0: return false
	if not cloud_binding.is_empty() and not test_mode:
		var cloud = get_node_or_null("/root/Cloud")
		if cloud==null or cloud.busy or not cloud.can_upload():
			message.emit("请先登录并同步云档案，再切换回收方案"); return false
		cloud.activate_salvage(id)
		return true
	if not salvage.activate(id,settlement_now()): return false
	message.emit("已切换回收方案 · 旧方案收益已独立记账")
	changed.emit(); save_game()
	return true

func delete_certificate(id: String) -> bool:
	if id==salvage.active_id: return false
	for record in salvage.certificates:
		if record.id==id:
			salvage.certificates.erase(record)
			if certification_result_id==id: certification_result_id = ""
			changed.emit(); save_game()
			return true
	return false

func invest_research(mechanism: String) -> bool:
	var used: int = parts.invest_research(mechanism)
	if used<=0: return false
	message.emit("投入研究资料 %d · %s" % [used,PARTS.MECHANISMS[mechanism].name])
	changed.emit(); save_game()
	return true

func claim_idle() -> bool:
	if not cloud_binding.is_empty() and not test_mode:
		var cloud = get_node_or_null("/root/Cloud")
		if cloud!=null: cloud.claim_current()
		else: message.emit("请联网登录云账号后领取")
		return false
	if not test_mode: salvage.catch_up(settlement_now())
	var rewards: Dictionary = salvage.claim()
	if rewards.is_empty():
		message.emit("补给仓正在生产，请稍后领取")
		return false
	credits += int(rewards.credits)
	cores += int(rewards.cores)
	parts.research_materials += int(rewards.research)
	var recycled := 0
	var saved_ids: Array = []
	for area in rewards.regions:
		var region: int = area.region
		expedition.samples[region] = int(expedition.samples[region])+int(area.samples)
		for _i in range(int(area.parts)):
			var part: Dictionary = parts.roll(expedition.DATA.REGIONS[region].pool.pick_random(),-1,true)
			var materials: int = parts.recycle_fresh_common(part.id) if salvage.auto_recycle else 0
			if materials>0: cores += materials; recycled += 1
			else: saved_ids.append(part.id)
	rewards.recycled = recycled; rewards.saved_part_ids = saved_ids
	salvage.last_claim = rewards.duplicate(true)
	offline_seconds = 0
	feedback.emit("reward")
	message.emit("回收结算 · 信用点 +%d / 部件 %d / 研究资料 %d" % [rewards.credits,saved_ids.size(),rewards.research])
	changed.emit()
	save_game()
	return true

func recruit(count: int) -> bool:
	if count not in [1, 10] or gems < count * 100:
		message.emit("星晶不足 · 击败首领或完成任务可获得")
		return false
	gems -= count * 100
	last_pull.clear()
	for j in range(count):
		if not unlocked[2]:
			unlocked[2] = true
			narrative.unlock("arrival_2")
			last_pull.append("SSR  凛 · 新机师加入")
		else:
			var i := randi_range(0,PILOTS.size()-1)
			if not unlocked[i]:
				unlocked[i] = true
				narrative.unlock("arrival_%d"%i)
				last_pull.append("SSR  %s · 新机师加入"%PILOTS[i].name)
			else:
				levels[i] = int(levels[i]) + 1
				last_pull.append("%s · 同调提升至 Lv.%02d" % [PILOTS[i].name, levels[i]])
		recruits += 1
	feedback.emit("recruit")
	changed.emit()
	save_game()
	return true

func recruit_pilot(index: int) -> bool:
	if index<0 or index>=PILOTS.size() or index>=unlocked.size() or unlocked[index]: return false
	if gems<300:
		message.emit("定向邀请需要300星晶")
		return false
	gems -= 300; unlocked[index] = true; recruits += 1
	narrative.unlock("arrival_%d"%index)
	last_pull = ["SSR  %s · 定向邀请成功"%PILOTS[index].name]
	feedback.emit("recruit"); changed.emit(); save_game()
	return true

func mission_progress(i: int) -> int:
	return [wins, upgrades, recruits][i]

func mission_goal(i: int) -> int:
	return [5, 3, 1][i]

func claim_mission(i: int) -> bool:
	if i in claimed or mission_progress(i) < mission_goal(i):
		return false
	claimed.append(i)
	gems += [200, 200, 100][i]
	feedback.emit("reward")
	message.emit("行动任务完成 · 星晶已发放")
	changed.emit()
	save_game()
	return true

func save_payload() -> Dictionary:
	return {"narrative":narrative.export_save(),"version": SAVE_VERSION,"cloud_binding":cloud_binding.duplicate(true),"pilot_roster":pilot_roster.export_save(),"pilot_runtime":pilot_runtime.export_save(), "salvage":salvage.export_save(), "expedition":expedition.export_save(), "carrier":carrier.export_save(), "tactics":tactics,"tactic_presets":tactic_presets,"cooling_hold":rig.cooling_hold, "temporary_shield":defense.temporary_shield,"temporary_ttl":defense.temporary_ttl,"vent_cooldown":rig.vent_cooldown,"counter_charge":defense.counter_charge,"counter_cooldown":defense.counter_cooldown,"guard":defense.guard,"guard_break":defense.guard_break,"guard_quiet":defense.guard_quiet,"guard_facing":[defense.guard_facing.x,defense.guard_facing.y],"shield":defense.shield,"barrier_clock":defense.barrier_clock,"heat":rig.heat,"overheated":rig.overheated,"hp":hp,"recovery":recovery, "parts": parts.export_save(), "credits": credits, "cores": cores, "gems": gems, "levels": levels, "unlocked": unlocked, "selected": selected,"selected_mech":selected_mech,"mechs":mechs.export_save(), "stage": stage, "wins": wins, "upgrades": upgrades, "recruits": recruits, "claimed": claimed, "pending_credits": pending_credits, "pending_cores": pending_cores, "last_seen": int(settlement_now()), "sound": sound_enabled, "world": get_node("/root/World").export_save() if has_node("/root/World") else world_save}

func save_game() -> void:
	if test_mode and save_override == "":
		return
	if not test_mode: salvage.catch_up(settlement_now())
	else: salvage.anchor(settlement_now())
	var path := save_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_payload()))
		file.close()
		DirAccess.rename_absolute(path + ".tmp", path)

func load_game() -> void:
	if not FileAccess.file_exists(save_path()):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
	if import_game(data) and (not data.has("mechs") or data.levels.size()<PILOTS.size() or not expedition.legacy_return.is_empty()):
		save_game()

func import_game(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	for key in ["levels", "unlocked"]:
		if not data.get(key) is Array or data[key].size() not in [3,PILOTS.size()]: return false
	if data.levels.size()!=data.unlocked.size(): return false
	for value in data.levels:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	if not data.get("claimed", []) is Array: return false
	cloud_binding = data.get("cloud_binding",{}).duplicate(true) if data.get("cloud_binding") is Dictionary else {}
	certification_job = null; certification_committed = false; certification_result_id = ""
	pilot_roster.import_save(data.get("pilot_roster"))
	pilot_runtime = PILOT_RUNTIME.new(); pilot_runtime.import_save(data.get("pilot_runtime"))
	parts.import_save(data.get("parts"))
	mechs.import_save(data.get("mechs"))
	carrier.import_save(data.get("carrier"))
	selected_mech = clampi(int(data.get("selected_mech",data.get("selected",0))),0,MECHS.MODELS.size()-1)
	expedition.import_save(data.get("expedition"))
	import_tactics(data)
	reset_part_combat()
	defense.configure(equipment_stats())
	defense.guard = clampf(float(data.get("guard",defense.max_guard)),0,defense.max_guard)
	defense.guard_break = clampf(float(data.get("guard_break",0)),0,2)
	defense.guard_quiet = clampf(float(data.get("guard_quiet",0)),0,10)
	var facing = data.get("guard_facing",[])
	defense.guard_facing = Vector2.RIGHT
	if facing is Array and facing.size()==2 and (facing[0] is int or facing[0] is float) and (facing[1] is int or facing[1] is float) and is_finite(float(facing[0])) and is_finite(float(facing[1])):
		var direction := Vector2(float(facing[0]),float(facing[1]))
		if direction.length_squared()>0.001: defense.guard_facing = direction.normalized()
	defense.temporary_shield = clampf(float(data.get("temporary_shield",0)),0,30)
	defense.temporary_ttl = clampf(float(data.get("temporary_ttl",0)),0,6)
	defense.counter_charge = clampf(float(data.get("counter_charge",0)),0,100)
	defense.counter_cooldown = clampf(float(data.get("counter_cooldown",0)),0,5)
	rig.vent_cooldown = clampf(float(data.get("vent_cooldown",0)),0,8)
	defense.shield = clampf(float(data.get("shield",0)),0,defense.max_shield)
	defense.barrier_clock = clampf(float(data.get("barrier_clock",0)),0,6)
	rig.heat = clampf(float(data.get("heat",0)),0,100)
	rig.overheated = bool(data.get("overheated",false)) and rig.heat>60
	hp = clampf(float(data.get("hp",100)),0,100)
	recovery = clampf(float(data.get("recovery",0)),0,5)
	if hp<=0 and recovery<=0: recovery = 5
	world_save = data.get("world",{}) if data.get("world",{}) is Dictionary else {}
	if not expedition.legacy_return.is_empty():
		world_save = expedition.legacy_return.overworld.duplicate(true)
		world_save.docked = true
		if world_save.get("boss") is Dictionary: world_save.boss.active = false
		if recovery<=0: hp = 100; rig.heat = 0
	if recovery>0: world_save["docked"] = true
	if world_save.get("docked",false) and expedition.active():
		var overworld: Dictionary = expedition.run.overworld.duplicate(true)
		overworld.boss = world_save.get("boss",{})
		overworld.docked = true
		expedition.run.clear()
		world_save = overworld
	var world = get_node_or_null("/root/World")
	if world != null: world.import_save(world_save)
	if not data.has("expedition") and world!=null and world.boss.victories>0: expedition.clears[0] = 1
	credits = maxi(0, int(data.get("credits", 2400)))
	if not expedition.legacy_return.is_empty(): credits += int(expedition.legacy_return.bounty)
	cores = maxi(0, int(data.get("cores", 120)))
	gems = maxi(0, int(data.get("gems", 900)))
	levels = initial_pilot_levels(); unlocked = initial_pilot_unlocks()
	for i in range(data.levels.size()):
		levels[i] = clampi(int(data.levels[i]),1,9999)
		unlocked[i] = bool(data.unlocked[i])
	unlocked[0] = true
	selected = clampi(int(data.get("selected", 0)),0,PILOTS.size()-1)
	if not unlocked[selected]: selected = 0
	pilot_runtime.pilot_id = selected
	rig.cooling_hold = bool(data.get("cooling_hold",false)) and rig.heat>45 and active_tactics().heat=="conserve"
	stage = maxi(1, int(data.get("stage", 1)))
	wins = int(data.get("wins", 0))
	upgrades = int(data.get("upgrades", 0))
	recruits = int(data.get("recruits", 0))
	claimed = data.get("claimed", [])
	sound_enabled = bool(data.get("sound", true))
	if data.get("salvage") is Dictionary:
		salvage.import_save(data.salvage)
	else:
		salvage.import_save({})
		salvage.cursor = float(data.get("last_seen",settlement_now()))
		pending_credits = maxi(0,int(data.get("pending_credits",0)))
		pending_cores = maxi(0,int(data.get("pending_cores",0)))
	var record: Dictionary = salvage.active_record()
	if int(record.region)>=0 and expedition.clears[int(record.region)]<=0: salvage.active_id = "base"
	offline_seconds = salvage.catch_up(settlement_now()) if cloud_binding.is_empty() else 0
	story_paused = false
	narrative.import_save(data.get("narrative"),wins>0 or recruits>0 or upgrades>0 or expedition.sequence>0)
	# Existing progress unlocks its corresponding archive without interrupting play.
	for region in range(4):
		if expedition.clears[region]>0:
			for prefix in ["briefing_","boss_","debrief_"]: narrative.unlock(prefix+str(region),false)
	for pilot in range(PILOTS.size()):
		if pilot>=2 and unlocked[pilot]: narrative.unlock("arrival_%d"%pilot,false)
		for chapter in pilot_roster.claimed[pilot]: narrative.unlock("personal_%d_%d"%[pilot,chapter],false)
		for chapter in pilot_roster.heard[pilot]: narrative.unlock("talk_%d_%d"%[pilot,chapter],false)
	if unlocked[2]: narrative.unlock("arrival_2",false)
	return true

func story_event(kind: String, value: int = -1) -> void:
	if world_override!=null: return
	var was_learning: bool = narrative.tutorial_enabled and not narrative.objective().is_empty()
	if kind in ["clear","return","failed"]:
		# Unread briefings remain in the archive, but must not interrupt a later
		# sortie as if the player were still approaching the previous boss.
		narrative.pending.erase("briefing_%d"%value)
		narrative.pending.erase("boss_%d"%value)
	match kind:
		"launch": narrative.mark("launch"); narrative.unlock("briefing_%d"%value)
		"boss": narrative.unlock("boss_%d"%value)
		"clear": narrative.unlock("debrief_%d"%value)
		"return": narrative.mark("return"); narrative.unlock("first_return")
		"failed": narrative.mark("return"); narrative.unlock("recovery")
		"select": narrative.unlock("bond_%d"%value)
		"facility": narrative.mark("interact")
		"auto", "fleet", "hangar", "talk": narrative.mark(kind)
	if NARRATIVE.CONTENT.RADIO.has(kind): pilot_radio.emit(kind,selected)
	if was_learning and narrative.objective().is_empty(): message.emit("基础带教完成 · 机师会继续陪你探索，航行日志可随时回看")
	if kind not in ["victory","skill","danger","discovery"]: save_game()

func record_story_movement(distance: float) -> void:
	if world_override!=null or narrative.milestones.has("move"): return
	narrative.manual_distance += distance
	if narrative.manual_distance>=80:
		narrative.manual_distance = 80; narrative.mark("move"); save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
