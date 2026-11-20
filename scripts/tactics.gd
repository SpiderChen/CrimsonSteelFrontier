extends RefCounted
## The same policy selects targets, movement and skill timing in the field and training.
const OPTIONS = {
	"target":["parts","nearest","elite","weak"],
	"distance":["balanced","close","far","melee"],
	"heat":["pressure","conserve","alternate"],
	"survival":["steady","withdraw","clear"],
	"skill":["ready","elite","danger"]
}
const LABELS = {
	"parts":"可破坏部位", "nearest":"最近目标", "elite":"精英优先", "weak":"低装甲目标",
	"balanced":"配装自适应", "close":"近距压制", "far":"远距保持",
	"melee":"近战贴身",
	"pressure":"持续压制", "conserve":"控热停火", "alternate":"双手交替",
	"steady":"保持交战", "withdraw":"护盾撤离 / 低装甲回舰", "clear":"优先清除近身目标",
	"ready":"充能完成即用", "danger":"危险阶段使用"
}
var clock: float = 0
var navigation_clock: float = 0
var shield_retreat: bool = false
var status: String = "交战"

static func defaults() -> Dictionary:
	return {"target":"parts","distance":"balanced","heat":"pressure","survival":"steady","skill":"ready"}

static func sanitize(raw: Variant) -> Dictionary:
	var settings := defaults()
	if raw is Dictionary:
		for key in OPTIONS:
			if raw.get(key) is String and raw[key] in OPTIONS[key]: settings[key] = raw[key]
	return settings

func reset() -> void:
	clock = 0; navigation_clock = 0; shield_retreat = false; status = "交战"

static func resolve(settings: Dictionary, profiles: Array, pilot: int, model: int) -> Dictionary:
	var result := settings.duplicate(true)
	var modes: Array = []
	for weapon in profiles:
		if not weapon.is_empty(): modes.append(str(weapon.mode))
	var melee: bool = modes.any(func(mode): return mode in ["blade","gauntlet","hammer"])
	var precision: bool = not modes.is_empty() and modes[0] in ["rail","laser","pulse"]
	var stationary_pilot: bool = pilot in [1,4]
	result.orbit = not melee and not stationary_pilot and (model==3 or (model==0 and not precision))
	result.style = "贴身格斗" if melee else "长程炮击" if model==4 else "堡垒压阵" if model==5 else "稳态狙击" if pilot==1 else "制导炮击" if pilot==4 else "矢量游击" if model==3 else "重装压阵" if model==2 else "定点射击" if precision or model==1 else "机动游击"
	result.range_factor = 0.78
	if "plasma" in modes: result.range_factor = 0.65
	elif precision or "missile" in modes: result.range_factor = 0.88
	if model==4 and not melee: result.range_factor = maxf(result.range_factor,0.93)
	if pilot in [1,2,4,5]: result.range_factor = maxf(result.range_factor,0.88)
	return result

func select_target(origin: Vector2, targets: Array, settings: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var score := INF
	for target in targets:
		if float(target.get("hp",1))<=0: continue
		var distance: float = origin.distance_to(target.p)
		var value: float = distance
		if settings.target=="elite" and target.get("elite",false): value -= 10000
		if settings.target=="parts": value -= 10000*float(target.get("part_priority",1 if target.get("part",false) else 0))
		if settings.target=="weak": value = float(target.get("hp",1))/maxf(1,float(target.get("max",1)))*10000+distance*0.1
		if settings.survival=="clear" and distance<=160: value = -100000+distance
		if value<score or (is_equal_approx(value,score) and str(target.id)<str(best.get("id","~"))): best = target; score = value
	return best

func update_survival(hp: float, shield: float, maximum: float, settings: Dictionary) -> bool:
	if settings.survival!="withdraw": shield_retreat = false; return false
	if maximum>0:
		if shield<=maximum*0.2: shield_retreat = true
		elif shield>=maximum*0.6: shield_retreat = false
	else: shield_retreat = false
	return hp<=30

func desired_distance(settings: Dictionary, weapon_range: float) -> float:
	if shield_retreat: return weapon_range+55
	if settings.distance=="melee" or weapon_range<=140: return maxf(24,minf(60,weapon_range-36))
	if settings.distance=="close": return minf(120,weapon_range*0.55)
	if settings.distance=="far": return weapon_range*0.9
	return weapon_range*float(settings.get("range_factor",0.8))

static func projectile_warnings(origin: Vector2, projectiles: Array) -> Array:
	var result: Array = []
	for shot in projectiles:
		var offset: Vector2 = origin-shot.p
		if offset.length()>260 or offset.dot(shot.direction)<=0: continue
		var end: Vector2 = shot.p+shot.direction*320
		var closest := Geometry2D.get_closest_point_to_segment(origin,shot.p,end)
		if closest.distance_to(origin)>56: continue
		result.append({"p":closest,"from":shot.p,"to":end,"radius":24.0})
	return result

static func threat_distance(point: Vector2, warning: Dictionary) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point,warning.from,warning.to)) if warning.has("from") else point.distance_to(warning.p)

func destination(origin: Vector2, target: Vector2, settings: Dictionary, weapon_range: float, warnings: Array, orbit: bool, clamp_point: Callable, legal: Callable) -> Vector2:
	var desired := desired_distance(settings,weapon_range)
	var avoiding := false
	for warning in warnings:
		if threat_distance(origin,warning)<float(warning.radius)+42: avoiding = true
	if avoiding:
		status = "规避危险区域"
		var best := origin
		var best_score := -INF
		for radius in [145.0,210.0]:
			for i in range(16):
				var candidate: Vector2 = clamp_point.call(origin+Vector2.from_angle(i*TAU/16)*radius)
				if not legal.call(candidate): continue
				var clearance := INF
				for warning in warnings: clearance = minf(clearance,threat_distance(candidate,warning)-float(warning.radius)-22)
				var score: float = minf(clearance,90)-origin.distance_to(candidate)*0.12-absf(candidate.distance_to(target)-desired)*0.05
				if score>best_score: best_score = score; best = candidate
		return best
	status = "护盾撤离" if shield_retreat else str(settings.get("style",LABELS[settings.distance]))
	var radial := target.direction_to(origin)
	if radial==Vector2.ZERO: radial = Vector2.LEFT
	if orbit and not shield_retreat: radial = radial.rotated(0.4)
	if not orbit and absf(origin.distance_to(target)-desired)<25: return origin
	for angle in [0.0,0.25,-0.25,0.5,-0.5,1.0,-1.0,PI]:
		var goal: Vector2 = clamp_point.call(target+radial.rotated(angle)*desired)
		if legal.call(goal): return goal
	return origin

func skill_allowed(settings: Dictionary, elite: bool, danger: bool) -> bool:
	return settings.skill=="ready" or (settings.skill=="elite" and elite) or (settings.skill=="danger" and danger)
