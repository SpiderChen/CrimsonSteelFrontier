extends RefCounted
var emissions: Array = []
func capture(profile: Dictionary) -> void: emissions.append(profile.slot)
func item(parts: RefCounted, blueprint: int, slot: int = -1) -> Dictionary:
	var part: Dictionary = parts.roll(blueprint,0)
	part.affixes = []
	parts.equip(0,part.id,slot)
	return part
func run(check: Callable) -> void:
	var parts = State.PARTS.new()
	parts.starter()
	check.call(parts.loadouts[0].size()==6 and parts.equipped(0,4).blueprint==1 and parts.equipped(0,5).blueprint==12,"six-slot starter has independent weapons and a real cooling backpack")
	var id: int = parts.equipped(0,0).id
	parts.equip(0,id,4)
	check.call(parts.equipped(0,0).is_empty() and parts.equipped(0,4).id==id,"one weapon can change hands without being duplicated")
	check.call(not parts.equip(0,parts.equipped(0,1).id,4),"armor cannot occupy the secondary weapon slot")
	var legacy: Dictionary = parts.export_save()
	legacy.erase("schema")
	legacy.loadouts = [{"0":1,"1":2,"2":3,"3":4},{},{}]
	legacy.presets = [[{"0":1,"1":2,"2":3,"3":4}],[],[]]
	var original_items: Array = legacy.inventory.duplicate(true)
	parts.import_save(legacy)
	check.call(parts.loadouts[0].size()==4 and parts.inventory==original_items and parts.presets[0][0].size()==4,"four-slot saves migrate without rerolling items or changing old preset references")
	parts = State.PARTS.new()
	item(parts,1,0); item(parts,1,4); item(parts,4); item(parts,6); item(parts,10); item(parts,14)
	var configuration: Dictionary = parts.configuration(0)
	check.call(not configuration.valid and configuration.weight>configuration.capacity and configuration.power<configuration.supply,"load limit can fail independently of sufficient power")
	parts = State.PARTS.new()
	item(parts,2,0); item(parts,2,4); item(parts,6); item(parts,10); item(parts,12)
	configuration = parts.configuration(0)
	check.call(not configuration.valid and configuration.weight<configuration.capacity and configuration.power>configuration.supply,"dual energy weapons can exceed reactor power while still meeting the weight limit")
	item(parts,14)
	check.call(parts.configuration(0).valid and parts.configuration(0).cooling==12,"battery backpack solves power pressure while giving up cooler output")
	var original_chassis: Array = State.mechs.units[0].affixes.duplicate(true)
	State.mechs.units[0].affixes = [{"stat":"attack","value":3},{"stat":"cooling","value":2}]
	var original_parts = State.parts
	var original_rig = State.rig
	var selected: int = State.selected
	State.parts = parts; State.selected = 0
	World.docked = true
	item(parts,12)
	check.call(not World.launch() and World.docked,"departure rejects an invalid rig before moving the player")
	item(parts,8)
	check.call(World.launch(),"changing to low-power high-load tracks makes the dual energy rig launchable")
	State.rig = State.RIG_RUNTIME.new()
	State.rig.add_heat(100)
	World.grace = 10000; World.position = World.START; World.steering = Vector2.UP
	var before: Vector2 = World.position
	World.advance(0.1)
	check.call(World.position.distance_to(before)>0,"overheat never prevents locomotion")
	var rig = State.RIG_RUNTIME.new()
	var profiles := [{"slot":0,"mode":"burst","interval":0.9,"range":300.0,"heat":9.0},{"slot":4,"mode":"rail","interval":1.35,"range":390.0,"heat":40.0}]
	emissions.clear()
	rig.advance(0.91,profiles,200,"a",{"valid":true},capture)
	check.call(emissions==[0] and rig.weapons[0].pending==2,"left burst starts on its own cooldown")
	rig.advance(0.13,profiles,200,"a",{"valid":true},capture)
	rig.advance(0.13,profiles,200,"a",{"valid":true},capture)
	rig.advance(0.2,profiles,200,"a",{"valid":true},capture)
	check.call(emissions.count(0)==3 and emissions.count(4)==1,"independent rail cooldown advances while the other hand is bursting")
	rig = State.RIG_RUNTIME.new(); emissions.clear()
	rig.advance(1.4,profiles,350,"a",{"valid":true},capture)
	check.call(emissions==[4],"only the weapon whose own range reaches the target fires")
	rig = State.RIG_RUNTIME.new(); rig.add_heat(100); emissions.clear()
	rig.advance(1.4,profiles,200,"a",{"valid":true},capture)
	check.call(emissions.is_empty() and rig.overheated,"overheat extends cooldowns instead of emitting normal-rate shots")
	rig.cool(1,{"cooling":30.0})
	check.call(rig.overheated and rig.heat==70,"overheat hysteresis stays active above the recovery threshold")
	rig.cool(0.5,{"cooling":30.0})
	check.call(not rig.overheated and rig.heat==55,"cooling below sixty restores normal fire rate")
	State.rig.heat = 85
	State.rig.overheated = true
	State.save_override = ProjectSettings.globalize_path("res://tests/rig_save_fixture.json")
	State.save_game()
	State.rig.heat = 0; State.rig.overheated = false
	State.load_game()
	check.call(State.rig.heat==85 and State.rig.overheated and State.parts.equipped(0,4).blueprint==2,"heat hysteresis and the independent secondary weapon survive disk reload")
	DirAccess.remove_absolute(State.save_path()); State.save_override = ""
	State.equip_part(State.parts.equipped(0,0).id)
	check.call(State.rig.heat==85 and State.rig.overheated,"part swapping cannot clear heat or bypass overheat")
	World.enter_base()
	check.call(State.rig.heat==0 and not State.rig.overheated,"carrier maintenance clears thermal state")
	State.mechs.units[0].affixes = original_chassis
	State.parts = original_parts; State.rig = original_rig; State.selected = selected
	World.import_save({}); World.grace = 0
