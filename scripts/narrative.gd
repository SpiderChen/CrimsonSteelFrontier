extends RefCounted
const CONTENT = preload("res://scripts/story_content.gd")
var unlocked: Array = []
var seen: Array = []
var pending: Array = []
var active: String = ""
var cursor: int = 0
var choices: Dictionary = {}
var milestones: Dictionary = {}
var tutorial_enabled: bool = true
var radio_enabled: bool = true
var manual_distance: float = 0

func unlock(id: String, enqueue: bool = true) -> void:
	# Automatic presentation belongs to the first discovery only. Archived
	# unread scenes must not be queued again by a later sortie or boss attempt.
	if id in unlocked or CONTENT.scene(id).is_empty(): return
	unlocked.append(id)
	if enqueue and id not in seen and id not in pending and active!=id: pending.append(id)

func mark(key: String) -> void:
	for goal in CONTENT.GOALS:
		if goal.key==key: milestones[key] = true

func objective() -> Dictionary:
	if not tutorial_enabled: return {}
	for goal in CONTENT.GOALS:
		if not milestones.has(goal.key): return goal
	return {}

func finish(id: String) -> void:
	if id not in unlocked: return
	if id not in seen: seen.append(id)
	pending.erase(id)
	if active==id: active = ""; cursor = 0

func restart_tutorial() -> void:
	tutorial_enabled = true; milestones.clear(); manual_distance = 0

func export_save() -> Dictionary:
	return {"unlocked":unlocked.duplicate(),"seen":seen.duplicate(),"pending":pending.duplicate(),"active":active,"cursor":cursor,"choices":choices.duplicate(),"milestones":milestones.duplicate(),"tutorial":tutorial_enabled,"radio":radio_enabled,"manual_distance":manual_distance}

func import_save(raw: Variant, veteran: bool = false) -> void:
	unlocked.clear(); seen.clear(); pending.clear(); choices.clear(); milestones.clear()
	active = ""; cursor = 0; manual_distance = 0; tutorial_enabled = not veteran; radio_enabled = true
	if not raw is Dictionary:
		unlock("prologue",not veteran)
		return
	var valid: Array = CONTENT.ids()
	for key in ["unlocked","seen","pending"]:
		if not raw.get(key) is Array: continue
		for id in raw[key]:
			if id is String and id in valid and id not in get(key): get(key).append(id)
	seen = seen.filter(func(id): return id in unlocked)
	pending = pending.filter(func(id): return id in unlocked and id not in seen)
	if raw.get("active") is String and raw.active in unlocked and raw.active not in seen:
		active = raw.active; pending.erase(active)
		var value: Variant = raw.get("cursor",0)
		var data: Dictionary = CONTENT.scene(active)
		if (value is int or value is float) and is_finite(float(value)): cursor = clampi(int(value),0,data.lines.size()-1+(1 if data.has("guest_line") else 0))
	if raw.get("choices") is Dictionary:
		for id in raw.choices:
			var scene: Dictionary = CONTENT.scene(str(id)); var value: Variant = raw.choices[id]
			if id in unlocked and scene.has("choice") and (value is int or value is float) and is_finite(float(value)) and float(value)==floorf(float(value)) and value>=0 and value<scene.choice.options.size(): choices[id] = int(value)
	if raw.get("milestones") is Dictionary:
		for goal in CONTENT.GOALS:
			if raw.milestones.get(goal.key)==true: milestones[goal.key] = true
	if raw.get("manual_distance") is int or raw.get("manual_distance") is float:
		if is_finite(float(raw.manual_distance)): manual_distance = clampf(float(raw.manual_distance),0,80)
	tutorial_enabled = raw.get("tutorial",not veteran)==true
	radio_enabled = raw.get("radio",true)==true
	unlock("prologue",false)
