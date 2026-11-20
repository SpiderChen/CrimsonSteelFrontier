extends "res://scripts/state.gd"
## A detached instance of the real player controller. Its signals and economy are private.
var region: int = 0

func _init(snapshot: Dictionary, area: int, trial: int) -> void:
	test_mode = true
	region = area
	parts = PARTS.new(); parts.import_save(snapshot.parts)
	selected = clampi(int(snapshot.pilot),0,PILOTS.size()-1)
	pilot_runtime.pilot_id = selected
	selected_mech = clampi(int(snapshot.get("mech",selected)),0,MECHS.MODELS.size()-1)
	mechs.import_save(snapshot.get("mechs"))
	levels = snapshot.levels.duplicate(); unlocked = snapshot.unlocked.duplicate()
	while levels.size()<PILOTS.size(): levels.append(1)
	while unlocked.size()<PILOTS.size(): unlocked.append(false)
	tactics = []
	for _model in MECHS.MODELS: tactics.append(TACTICS.defaults())
	tactics[selected_mech] = TACTICS.sanitize(snapshot.tactics)
	stage = int(snapshot.get("stage",1))
	auto = true; auto_skill = bool(snapshot.get("auto_skill",true))
	energy = 25; recovery = 0
	rig = RIG_RUNTIME.new(); defense = DEFENSE_RUNTIME.new()
	defense.configure(equipment_stats(),true)
	combat_rng = RandomNumberGenerator.new()
	combat_rng.seed = 19737+area*997+trial*137

func _ready() -> void: set_process(false)
func save_game() -> void: pass
func reward_victory() -> void: wins += 1

func combat_configuration() -> Dictionary:
	var configuration: Dictionary = mech_configuration()
	configuration.cooling *= float(expedition.DATA.REGIONS[region].cooling)
	return configuration
