extends SceneTree
const PARTS = preload("res://scripts/parts.gd")
const REGIONS = preload("res://scripts/region_data.gd")
const MECHS = preload("res://scripts/mechs.gd")
const PILOTS = preload("res://scripts/pilot_runtime.gd")
func _initialize() -> void:
	var parts = PARTS.new()
	var pools: Array = []
	for blueprint in range(PARTS.BLUEPRINTS.size()): pools.append(parts.mechanism_pool(blueprint))
	var file := FileAccess.open("res://server/catalog.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":1,"blueprints":PARTS.BLUEPRINTS,"affixes":PARTS.AFFIXES,"mech_affixes":MECHS.AFFIXES,"mech_count":MECHS.MODELS.size(),"pilot_count":PILOTS.ABILITIES.size(),"mechanism_pools":pools,"regions":REGIONS.REGIONS,"research_target":PARTS.RESEARCH_TARGET,"inventory_limit":PARTS.LIMIT},"  "))
	file.close(); quit()
