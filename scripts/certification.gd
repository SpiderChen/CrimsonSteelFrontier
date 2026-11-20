extends RefCounted
## Three real automatic cleanups, advanced in short batches without touching live state.
const ACTOR = preload("res://scripts/certification_actor.gd")
const WORLD = preload("res://scripts/world.gd")
const DATA = preload("res://scripts/region_data.gd")
const VERSION = 1
var snapshot: Dictionary = {}
var region: int = 0
var actor: Node = null
var arena: Node = null
var trial: int = 0
var elapsed: float = 0
var total_elapsed: float = 0
var lowest_hp: float = 100
var trials: Array = []
var done: bool = false
var success: bool = false
var reason: String = ""
var failure_details: Dictionary = {}

static func capture(player: Node) -> Dictionary:
	var inventory: Array = []
	var loadouts: Array = []
	var presets: Array = []
	for _model in player.mechs.MODELS:
		loadouts.append({}); presets.append([])
	loadouts[player.selected_mech] = player.parts.loadouts[player.selected_mech].duplicate(true)
	for id in loadouts[player.selected_mech].values(): inventory.append(player.parts.find_part(int(id)).duplicate(true))
	return {"pilot":player.selected,"pilot_name":player.PILOTS[player.selected].name,"mech":player.selected_mech,"mech_name":player.mechs.name_of(player.selected_mech),"mechs":player.mechs.export_save(),"levels":player.levels.duplicate(),"unlocked":player.unlocked.duplicate(),"stage":player.stage,"tactics":player.active_tactics().duplicate(true),"auto_skill":player.auto_skill,"parts":{"inventory":inventory,"loadouts":loadouts,"presets":presets,"next_id":player.parts.next_id}}

func _init(build: Dictionary, area: int) -> void:
	snapshot = build.duplicate(true); region = area
	start_trial()

func start_trial() -> void:
	dispose()
	elapsed = 0
	actor = ACTOR.new(snapshot,region,trial)
	arena = WORLD.new()
	actor.world_override = arena; arena.combatant = actor
	arena.certification_region = region
	arena.noise.seed = 19737; arena.noise.frequency = 0.00072
	arena.import_save({"docked":false,"position":[DATA.ARENA.x-280,DATA.ARENA.y+trial*35-35]})
	arena.patrol = true; arena.grace = 0
	actor.shot.connect(arena.record_shot)
	for i in range(3):
		var role: String = DATA.REGIONS[region].roles[(i+trial)%2]
		var elite: bool = i==trial%3
		var point: Vector2 = DATA.ARENA+Vector2((i%2)*115-25,-110+i*100)
		var id := "cert:%d:%d" % [trial,i]
		arena.certification_foes.append({"id":id,"kind":"enemy","p":point,"elite":elite,"role":role,"region":region,"name":"认证目标"})
		var stats := DATA.enemy(role,region,elite)
		arena.enemy_health[id] = {"hp":stats.hp,"max":stats.hp}
	if not actor.mech_configuration().valid:
		done = true; reason = "装机约束不满足"; dispose()

func advance(max_steps: int = 24) -> void:
	if done: return
	for _i in range(max_steps):
		elapsed += 0.05; total_elapsed += 0.05
		actor.advance(0.05)
		lowest_hp = minf(lowest_hp,actor.hp)
		if actor.hp<=0 or actor.recovery>0 or arena.docked or elapsed>=120:
			failure_details = {"trial":trial,"seconds":elapsed,"position":[arena.position.x,arena.position.y],"target":arena.encounter_id,"target_hp":actor.enemy_hp,"target_position":[arena.encounter_position.x,arena.encounter_position.y],"heat":actor.rig.heat,"shots":arena.shots_fired,"hits":arena.attacks.stats.hits,"damage":arena.attacks.stats.damage,"cleared":arena.cleared.keys(),"targets":arena.attack_targets(),"profile":actor.weapon_profiles()}
			done = true; reason = "装甲耗尽" if actor.recovery>0 or actor.hp<=0 else "自动战术选择撤离" if arena.docked else "清剿超时"
			dispose(); return
		if arena.cleared.size()>=3:
			trials.append({"seconds":elapsed,"hp":actor.hp,"hits":arena.attacks.stats.hits,"damage":arena.attacks.stats.damage,"taken":actor.defense.prevented+actor.defense.absorbed+100+actor.defense.healed-actor.hp,"overheated":actor.rig.overheated_seconds})
			trial += 1
			if trial>=3:
				done = true; success = true; reason = "连续三次自动清剿通过"; dispose(); return
			start_trial()
			return

func result() -> Dictionary:
	if not done or not success: return {}
	var average := total_elapsed/3.0
	var stability := clampf(lowest_hp/60.0,0.55,1.0)
	var efficiency := clampf((8.0+region*2)/maxf(1,average),0.5,1.5)*stability
	return {"version":VERSION,"region":region,"snapshot":snapshot.duplicate(true),"seconds":average,"minimum_hp":lowest_hp,"grade":"A" if lowest_hp>=60 else "B" if lowest_hp>=35 else "C","trials":trials.duplicate(true),"rates":{"credits":(12.0+region*6)*3600*efficiency,"cores":(120.0+region*30)*efficiency,"parts":(3.0+region*0.5)*efficiency,"research":(1.0+region*0.5)*efficiency,"samples":stability}}

func dispose() -> void:
	if is_instance_valid(arena): arena.free()
	if is_instance_valid(actor): actor.free()
	arena = null; actor = null

func _notification(what: int) -> void:
	if what==NOTIFICATION_PREDELETE:
		if is_instance_valid(arena): arena.free()
		if is_instance_valid(actor): actor.free()
