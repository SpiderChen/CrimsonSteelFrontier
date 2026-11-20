extends RefCounted
## Chassis own their growth and rolls. Pilots can use any chassis.
const MODELS = [
	{"name":"赤鸢 · RX-07","color":Color("ff5467"),"trait":"轻型突击","desc":"基础移速190；散热+8/秒，擅长游走。","cooling":8.0,"speed":190.0},
	{"name":"夜莺 · SR-02","color":Color("b49aff"),"trait":"狙击火控","desc":"基础移速160；远程射程+15%，停步射击。","range":0.15,"speed":160.0},
	{"name":"白隼 · SP-09","color":Color("7ddfff"),"trait":"重装阵地","desc":"基础移速130；载重+25、护盾+12，稳守阵地。","capacity":25.0,"shield":12.0,"speed":130.0},
	{"name":"苍狼 · CV-12","color":Color("72e6b0"),"trait":"矢量游击","desc":"基础移速210；散热+4/秒，迅速转移射击位置。","cooling":4.0,"speed":210.0},
	{"name":"曜隼 · AR-11","color":Color("f5c764"),"trait":"长程炮击","desc":"基础移速145；远程射程+25%、供能+12。","range":0.25,"supply":12.0,"speed":145.0},
	{"name":"玄甲 · GD-06","color":Color("47bfca"),"trait":"堡垒防线","desc":"基础移速110；载重+40、护盾+24，承受正面火力。","capacity":40.0,"shield":24.0,"speed":110.0}
]
const AFFIXES = {
	"attack":{"name":"机体火力","min":3,"max":7,"unit":""},
	"cooling":{"name":"散热","min":2,"max":4,"unit":"/秒"},
	"capacity":{"name":"载重上限","min":8,"max":15,"unit":""},
	"supply":{"name":"供能上限","min":6,"max":12,"unit":""}
}
var units: Array = []

func _init() -> void:
	starter()

func roll(model: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool: Array = AFFIXES.keys()
	var affixes: Array = []
	for _i in range(2):
		var stat: String = pool.pop_at(rng.randi_range(0,pool.size()-1))
		affixes.append({"stat":stat,"value":rng.randi_range(AFFIXES[stat].min,AFFIXES[stat].max)})
	return {"id":model+1,"model":model,"level":1,"affixes":affixes}

func starter() -> void:
	units.clear()
	for model in range(MODELS.size()): units.append(roll(model))

func stats(mech: int) -> Dictionary:
	var unit: Dictionary = units[mech]
	var model: Dictionary = MODELS[unit.model]
	var result := {"attack":float((int(unit.level)-1)*7),"shield":float(model.get("shield",0)),"cooling":float(model.get("cooling",0)),"capacity":float(model.get("capacity",0)),"supply":float(model.get("supply",0)),"range":float(model.get("range",0))}
	for affix in unit.affixes: result[affix.stat] += float(affix.value)
	return result

func name_of(mech: int) -> String:
	return MODELS[units[mech].model].name

func affix_text(mech: int) -> String:
	var lines := PackedStringArray()
	for affix in units[mech].affixes:
		var info: Dictionary = AFFIXES[affix.stat]
		lines.append("%s +%d%s" % [info.name,affix.value,info.unit])
	return " · ".join(lines)

func export_save() -> Dictionary:
	return {"schema":1,"units":units.duplicate(true)}

func import_save(raw: Variant) -> void:
	var saved: Array = raw.get("units",[]) if raw is Dictionary and raw.get("units") is Array else []
	var restored: Array = []
	for index in range(MODELS.size()):
		var item: Dictionary = saved[index] if index<saved.size() and saved[index] is Dictionary else {}
		var affixes: Array = []
		var seen: Array = []
		if item.get("affixes") is Array:
			for affix in item.affixes:
				if not affix is Dictionary or affix.get("stat") not in AFFIXES or affix.stat in seen: continue
				var value = affix.get("value")
				if not (value is int or value is float) or not is_finite(float(value)): continue
				seen.append(affix.stat)
				affixes.append({"stat":affix.stat,"value":clampi(int(value),AFFIXES[affix.stat].min,AFFIXES[affix.stat].max)})
				if affixes.size()==2: break
		if affixes.size()!=2:
			restored.append(roll(index))
			continue
		var level = item.get("level",1)
		if not (level is int or level is float) or not is_finite(float(level)): level = 1
		restored.append({"id":index+1,"model":index,"level":clampi(int(level),1,9999),"affixes":affixes})
	units = restored
