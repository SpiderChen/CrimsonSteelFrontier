extends RefCounted
## Permanent carrier modules; ammunition and pending strikes belong to the active dungeon.
const MODULES = ["cannon","repair","logistics"]
const TITLES = {"cannon":"舰载主炮","repair":"维修无人机","logistics":"战术补给舱"}
var levels: Dictionary = {"cannon":1,"repair":1,"logistics":1}
const OPS = preload("res://scripts/carrier_ops.gd")
var ops = OPS.new()
var doctrine: String = "assault"
var report_seen: int = 0

func cost(module: String) -> Dictionary:
	var level: int = levels.get(module,1)
	return {"credits":600*level,"cores":20*level}

func upgrade(module: String) -> bool:
	if module not in MODULES or not World.docked or State.recovery>0 or int(levels[module])>=5: return false
	var price := cost(module)
	if State.credits<int(price.credits) or State.cores<int(price.cores): return false
	State.credits -= int(price.credits); State.cores -= int(price.cores)
	levels[module] = int(levels[module])+1
	State.message.emit(TITLES[module]+"改造完成 · Lv.%d" % levels[module])
	State.feedback.emit("upgrade"); State.changed.emit(); State.save_game()
	return true

func damage() -> int: return 140+70*(int(levels.cannon)-1)
func radius() -> float: return 180.0+10*(int(levels.cannon)-1)
func healing() -> int: return 20+5*(int(levels.repair)-1)
func venting() -> int: return 25+5*(int(levels.repair)-1)
func cooldown() -> float: return 30.0-2*(int(levels.logistics)-1)
func initial_support() -> Dictionary:
	var extra := int((int(levels.logistics)-1)/2.0)
	return {"cannon":2+extra,"repair":1+extra,"cooldown":0.0,"pending":{},"ops":ops.initial()}

func description(module: String) -> String:
	match module:
		"cannon": return "重型炮击 %d伤害 / 范围%.0f\n护航炮弹%d伤害 / 齐射每轮%d伤害\n升级：重炮+70、护航+8、齐射+10" % [damage(),radius(),24+8*(int(levels.cannon)-1),35+10*(int(levels.cannon)-1)]
		"repair": return "重型维修：装甲+%d / 排热%d\n前进补给：每秒修复%.1f / 排热4\n升级：重型维修+5、补给每秒+0.5" % [healing(),venting(),2+0.5*(int(levels.repair)-1)]
		_: return "每趟重炮%d次 / 维修%d次 · 共用冷却%.0fs\n舰能每秒恢复%.2f，升级+0.25\n重型支援冷却-2s；Lv.3、5各增加一次" % [initial_support().cannon,initial_support().repair,cooldown(),3+0.25*(int(levels.logistics)-1)]

func blocked(world: Node, kind: String) -> String:
	if kind not in ["cannon","repair"]: return "无效支援"
	if world.docked or State.recovery>0 or not State.expedition.active(): return "仅可在副本中呼叫"
	var run: Dictionary = State.expedition.run
	if run.phase not in ["explore","boss"]: return "支援暂不可用"
	var support: Dictionary = run.support
	if not support.pending.is_empty(): return "舰炮正在落弹"
	if float(support.cooldown)>0: return "支援冷却 %.0f 秒" % ceilf(support.cooldown)
	if int(support[kind])<=0: return "本趟支援次数已用尽"
	if kind=="repair" and State.hp>=100 and State.rig.heat<=0: return "装甲和热量状态良好"
	if kind=="cannon" and world.attack_targets().is_empty(): return "当前没有可锁定目标"
	return ""

func call_support(world: Node, kind: String) -> bool:
	var reason := blocked(world,kind)
	if reason!="": return false
	var support: Dictionary = State.expedition.run.support
	if kind=="cannon":
		var targets: Array = world.attack_targets()
		var target: Dictionary = targets[0]
		for candidate in targets:
			if candidate.id==world.current_target_id(): target = candidate; break
			if candidate.p.distance_to(world.position)<target.p.distance_to(world.position): target = candidate
		support.pending = {"point":[target.p.x,target.p.y],"remaining":1.2,"damage":damage(),"radius":radius(),"mission":State.expedition.run.id}
		State.message.emit("舰炮已锁定落点 · 1.2 秒后覆盖轰击")
	else:
		State.defense.heal(healing()); State.rig.heat = maxf(0,State.rig.heat-venting())
		world.attacks.effects.append({"p":world.position,"radius":55.0,"t":0.35,"mode":"repair","ion":true})
		State.feedback.emit("shield")
		State.message.emit("维修无人机抵达 · 装甲 +%d / 排热 %d" % [healing(),venting()])
	support[kind] = int(support[kind])-1; support.cooldown = cooldown()
	State.changed.emit(); State.save_game()
	return true

func advance(world: Node, delta: float) -> void:
	ops.advance(world,delta)
	if not State.expedition.active() or world.docked: return
	var run: Dictionary = State.expedition.run
	var support: Dictionary = run.support
	support.cooldown = maxf(0,float(support.cooldown)-delta)
	if support.pending.is_empty(): return
	var strike: Dictionary = support.pending
	if int(strike.mission)!=int(run.id) or run.phase not in ["explore","boss"]: support.pending = {}; return
	strike.remaining = maxf(0,float(strike.remaining)-delta)
	if float(strike.remaining)>0: return
	# Clear before applying damage: a lethal strike can finish the dungeon and save immediately.
	support.pending = {}
	var point := Vector2(strike.point[0],strike.point[1])
	world.attacks.effects.append({"p":point,"radius":float(strike.radius),"t":0.35,"mode":"missile","ion":true})
	for target in world.attack_targets().duplicate(true):
		# Boss limbs share the core's health pool. One area strike hits that pool once.
		if target.id in ["boss:tracks","boss:cannon"] or target.p.distance_to(point)>float(strike.radius): continue
		if world.docked: break
		world.apply_projectile_hit(target.id,int(strike.damage),"carrier",target.p)
	State.changed.emit(); State.save_game()

func export_save() -> Dictionary: return {"levels":levels.duplicate(),"doctrine":doctrine,"report_seen":report_seen}
func import_save(raw: Variant) -> void:
	levels = {"cannon":1,"repair":1,"logistics":1}
	doctrine = "assault"; ops.flashes.clear()
	report_seen = 0
	if not raw is Dictionary or not raw.get("levels") is Dictionary: return
	report_seen = State.expedition.integer(raw.get("report_seen"),0,0,100000000)
	if raw.get("doctrine") in OPS.DOCTRINES: doctrine = raw.doctrine
	for module in MODULES:
		var value = raw.levels.get(module)
		if (value is int or value is float) and is_finite(float(value)) and value==floorf(value): levels[module] = clampi(int(value),1,5)

func import_support(raw: Variant, mission: int) -> Dictionary:
	var result := initial_support()
	if not raw is Dictionary: return result
	result.ops = ops.import_save(raw.get("ops"))
	for key in ["cannon","repair"]: result[key] = State.expedition.integer(raw.get(key),0,0,int(result[key]))
	result.cooldown = State.expedition.finite_number(raw.get("cooldown"),0,0,30)
	var pending = raw.get("pending")
	if not pending is Dictionary or pending.is_empty() or not State.expedition.valid_index(pending.get("mission"),mission,mission): return result
	var p = pending.get("point")
	if not p is Array or p.size()!=2: return result
	for value in p:
		if not (value is int or value is float) or not is_finite(float(value)): return result
	if not State.expedition.bounds().has_point(Vector2(p[0],p[1])): return result
	result.pending = {"point":p.duplicate(),"mission":mission,"remaining":State.expedition.finite_number(pending.get("remaining"),1.2,0,1.2),"damage":State.expedition.integer(pending.get("damage"),damage(),1,damage()),"radius":State.expedition.finite_number(pending.get("radius"),radius(),1,radius())}
	return result
