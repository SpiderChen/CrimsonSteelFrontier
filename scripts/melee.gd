extends RefCounted
## Shared geometry and timing for real melee attacks, training and visuals.
const RULES = {
	"blade":{"range":120.0,"interval":1.0,"multiplier":1.6,"timings":[0.18],"window":0.10,"duration":0.48,"arc":2.094395,"targets":4,"type":"thermal","color":Color("ff927d")},
	"gauntlet":{"range":84.0,"interval":0.95,"multiplier":0.62,"timings":[0.10,0.24,0.40],"window":0.06,"duration":0.60,"arc":1.117011,"targets":1,"type":"kinetic","color":Color("8cdec3")},
	"hammer":{"range":108.0,"interval":1.6,"multiplier":2.8,"timings":[0.36],"window":0.10,"duration":0.78,"arc":1.745329,"targets":3,"type":"kinetic","color":Color("e9c78e")}
}

static func is_mode(mode: String) -> bool:
	return RULES.has(mode)

static func swing_angle(mode: String, age: float) -> float:
	var rule: Dictionary = RULES[mode]
	var contact: float = rule.timings[0]
	var windup: float = contact-0.06
	if age<windup: return -0.85*smoothstep(0,windup,age)
	if age<contact+0.10: return lerpf(-0.85,0.9,smoothstep(windup,contact+0.10,age))
	return 0.9*(1-smoothstep(contact+0.10,float(rule.duration),age))

static func engagement_range(profiles: Array, fallback: float = 300.0) -> float:
	var melee_range := INF
	var ranged_range := INF
	for profile in profiles:
		if profile.is_empty(): continue
		if is_mode(profile.mode): melee_range = minf(melee_range,float(profile.range))
		else: ranged_range = minf(ranged_range,float(profile.range))
	return melee_range if melee_range<INF else ranged_range if ranged_range<INF else fallback

static func draw_weapon(canvas: CanvasItem, mode: String, grip: Vector2, direction: Vector2, scale_value: float = 1.0) -> void:
	var art = preload("res://scripts/production_art.gd")
	var index: int = {"blade":21,"gauntlet":22,"hammer":23}[mode]
	var bounds: Vector2 = {"blade":Vector2(105,32),"gauntlet":Vector2(43,43),"hammer":Vector2(95,55)}[mode]
	art.item(canvas,index,grip+direction*(12 if mode=="gauntlet" else 28)*scale_value,bounds*scale_value,0,direction.x<0)
