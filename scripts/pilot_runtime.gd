extends RefCounted
## Shared by sorties, training and detached certification actors.
const ART = preload("res://scripts/production_art.gd")
const ABILITIES = [
	{"active":"排热30；6秒内武器产热降低45%。发射三枚扇形热能弹，每枚造成80%攻击伤害。","passive":"高温操控：热量达到60时，额外散热4/秒。","perk":"破门专家：开启探索武器库时，额外获得40待结算赏金。"},
	{"active":"发射300%攻击的贯穿电磁弹，并标记目标6秒。左右武器对标记目标伤害提高15%。","passive":"稳态瞄准：连续静止1.2秒后，武器产热降低15%；移动重置。","perk":"情报回收：开启探索武器库时，额外获得1份机制研究资料。"},
	{"active":"排热25，获得30临时护盾（6秒），并在5秒内修复15装甲。可在无目标时使用。","passive":"应急防线：承伤后装甲不高于40时，获得12临时护盾（3秒），冷却12秒。","perk":"野外整备：探索补给点选择整备时，额外修复10装甲并排热10。"},
	{"active":"对120距离内目标挥出240%攻击的热能斩击；6秒内左右格斗武器额外增伤35%。","passive":"贴身破阵：左右格斗武器伤害提高15%，只强化能量刃、拳套和战锤。","perk":"突击回收：开启探索武器库时，额外获得60待结算赏金。"},
	{"active":"发射四枚追踪导弹，总伤害270%攻击；标记目标6秒，左右导弹对其额外增伤20%。","passive":"制导校准：左右导弹武器伤害提高10%，其他武器不受影响。","perk":"弹道解析：开启探索武器库时，额外获得2份机制研究资料。"},
	{"active":"排热40，获得18临时护盾（6秒）；6秒内武器产热降低35%。可在无目标时使用。","passive":"能量回流：同步能量每秒额外恢复1.5点，更快进入下一轮技能循环。","perk":"反应炉整备：探索补给点选择整备时，额外排热20。"}
]
var pilot_id: int = 0
var assault_ttl: float = 0
var reactor_ttl: float = 0
var heat_buff: float = 0
var mark_ttl: float = 0
var mark_target: String = ""
var repair_ttl: float = 0
var shield_ttl: float = 0
var stationary: float = 0
var passive_cooldown: float = 0
var pending: Dictionary = {"vented":0.0,"support":0.0,"marked_damage":0.0,"melee_damage":0.0,"missile_damage":0.0}
var casts: int = 0

func advance(delta: float, pilot: int, rig: RefCounted, defense: RefCounted, moving: bool, active: bool) -> void:
	pilot_id = pilot
	assault_ttl = maxf(0,assault_ttl-delta); reactor_ttl = maxf(0,reactor_ttl-delta)
	heat_buff = maxf(0,heat_buff-delta); mark_ttl = maxf(0,mark_ttl-delta)
	shield_ttl = maxf(0,shield_ttl-delta); passive_cooldown = maxf(0,passive_cooldown-delta)
	if mark_ttl<=0: mark_target = ""
	stationary = 0 if moving or not active else minf(2,stationary+delta)
	var healing := minf(repair_ttl,delta)*3
	repair_ttl = maxf(0,repair_ttl-delta)
	if active and defense.hp>0 and pilot==2 and healing>0:
		var before: float = defense.hp
		defense.heal(healing); pending.support += defense.hp-before

func cooling_bonus(pilot: int, heat: float) -> float: return 4.0 if pilot==0 and heat>=60 else 0.0
func energy_bonus(pilot: int) -> float: return 1.5 if pilot==5 else 0.0
func heat_factor(pilot: int) -> float:
	return 0.55 if pilot==0 and heat_buff>0 else 0.85 if pilot==1 and stationary>=1.2 else 0.65 if pilot==5 and reactor_ttl>0 else 1.0

func use(pilot: int, arena: Node, origin: Vector2, target: Dictionary, rig: RefCounted, defense: RefCounted, attack: int, ion: bool = false) -> bool:
	if pilot<0 or pilot>=ABILITIES.size() or defense.hp<=0 or (pilot not in [2,5] and target.is_empty()): return false
	if pilot==3 and origin.distance_to(target.p)>120: return false
	pilot_id = pilot
	casts += 1
	var vent: float = minf(rig.heat,30 if pilot==0 else 25 if pilot==2 else 40 if pilot==5 else 0)
	rig.heat -= vent; pending.vented += vent
	if rig.heat<=60: rig.overheated = false
	var engine = arena.attacks if arena!=null and "attacks" in arena else arena.engine if arena!=null else null
	var meta := {"slot":"skill","ion":ion,"target_id":target.get("id",""),"base_type":"thermal"}
	if pilot==0:
		heat_buff = 6
		if engine!=null:
			var direction := origin.direction_to(target.p)
			for angle in [-0.13,0.0,0.13]:
				engine.launch(origin,origin+direction.rotated(angle)*700,maxi(1,int(attack*0.8)),"standard","",-1,meta)
	elif pilot==1:
		mark_target = target.id; mark_ttl = 6
		if engine!=null: engine.launch(origin,target.p,attack*3,"rail","pierce",-1,{"slot":"skill","target_id":target.id})
	elif pilot==2:
		defense.grant_temporary(30,6); shield_ttl = 6; repair_ttl = 5
		if engine!=null: engine.effects.append({"p":origin,"radius":90.0,"ion":true,"t":0.35,"mode":"repair"})
	elif pilot==3:
		assault_ttl = 6
		if engine!=null: engine.launch(origin,target.p,maxi(1,int(attack*2.4)),"blade","",-1,{"slot":"skill","target_id":target.id})
	elif pilot==4:
		mark_target = target.id; mark_ttl = 6
		if engine!=null: engine.launch(origin,target.p,attack*3,"missile","swarm",-1,{"slot":"skill","target_id":target.id,"ion":ion})
	elif pilot==5:
		reactor_ttl = 6; shield_ttl = 6
		defense.grant_temporary(18,6)
		if engine!=null: engine.effects.append({"p":origin,"radius":65.0,"ion":true,"t":0.35,"mode":"pulse"})
	return true

func after_hit(pilot: int, defense: RefCounted, absorbed: float) -> void:
	if pilot not in [2,5]: return
	if shield_ttl>0: pending.support += maxf(0,absorbed)
	if pilot==2 and defense.hp>0 and defense.hp<=40 and passive_cooldown<=0:
		defense.grant_temporary(12,3); shield_ttl = maxf(shield_ttl,3); passive_cooldown = 12

func multiplier(event: Dictionary) -> float:
	if str(event.get("slot","")) not in ["0","4"]: return 1.0
	var mode: String = str(event.get("mode",""))
	if pilot_id==3 and mode in ["blade","gauntlet","hammer"]: return 1.15+(0.35 if assault_ttl>0 else 0.0)
	if pilot_id==4 and mode=="missile": return 1.1+(0.2 if mark_ttl>0 and event.get("target","")==mark_target else 0.0)
	return 1.15 if pilot_id==1 and mark_ttl>0 and event.get("target","")==mark_target else 1.0

func record_hit(event: Dictionary, actual: float, factor: float) -> void:
	if pilot_id==1 and factor>1: pending.marked_damage += actual*(factor-1)/factor
	if pilot_id==3 and event.get("mode","") in ["blade","gauntlet","hammer"]: pending.melee_damage += maxf(0,actual)
	if pilot_id==4 and event.get("mode","")=="missile": pending.missile_damage += maxf(0,actual)

func collect() -> Dictionary:
	var result := pending.duplicate()
	for key in pending: pending[key] = 0.0
	return result

func export_save() -> Dictionary:
	return {"pilot_id":pilot_id,"assault_ttl":assault_ttl,"reactor_ttl":reactor_ttl,"heat_buff":heat_buff,"mark_ttl":mark_ttl,"mark_target":mark_target,"repair_ttl":repair_ttl,"shield_ttl":shield_ttl,"passive_cooldown":passive_cooldown}

func import_save(data: Variant) -> void:
	if not data is Dictionary: return
	pilot_id = clampi(int(data.get("pilot_id",0)),0,ABILITIES.size()-1)
	for key in ["heat_buff","mark_ttl","repair_ttl","shield_ttl","passive_cooldown","assault_ttl","reactor_ttl"]:
		var value: Variant = data.get(key,0)
		if (value is int or value is float) and is_finite(float(value)): set(key,clampf(float(value),0,12 if key=="passive_cooldown" else 5 if key=="repair_ttl" else 6))
	mark_target = str(data.get("mark_target","")).left(120)

func status(pilot: int) -> String:
	if pilot==0 and heat_buff>0: return "低热驱动 %.1fs"%heat_buff
	if pilot==1 and mark_ttl>0: return "目标标记 %.1fs"%mark_ttl
	if pilot==1 and stationary>=1.2: return "稳态瞄准"
	if pilot==2 and repair_ttl>0: return "持续维修 %.1fs"%repair_ttl
	if pilot==2 and passive_cooldown>0: return "应急冷却 %.1fs"%passive_cooldown
	if pilot==3 and assault_ttl>0: return "苍炎连击 %.1fs"%assault_ttl
	if pilot==3: return "格斗强化 +15%"
	if pilot==4 and mark_ttl>0: return "制导锁定 %.1fs"%mark_ttl
	if pilot==4: return "导弹强化 +10%"
	if pilot==5 and reactor_ttl>0: return "曙光回路 %.1fs"%reactor_ttl
	if pilot==5: return "能量回流 +1.5/s"
	return "同步待命"

func render(canvas: CanvasItem, origin: Vector2, targets: Array, project: Callable, scale_value: float, pilot: int) -> void:
	var point: Vector2 = project.call(origin)
	var clock: float = Time.get_ticks_msec()*0.001
	if pilot==0 and heat_buff>0:
		ART.fx(canvas,"fx-support",2,point,Vector2.ONE*110*scale_value,fmod(clock*3,1),0,0.7)
	if pilot in [1,4] and mark_ttl>0:
		for target in targets:
			if target.id==mark_target: ART.fx(canvas,"fx-support",3,project.call(target.p),Vector2.ONE*95*scale_value,fmod(clock*2.5,1),0,0.8)
	if pilot==2 and repair_ttl>0:
		ART.fx(canvas,"fx-support",1,point+Vector2(0,20)*scale_value,Vector2.ONE*65*scale_value,fmod(clock*3,1),0,0.45)
	if pilot==3 and assault_ttl>0:
		canvas.draw_arc(point,42*scale_value,clock*2,clock*2+1.3,16,Color(1,0.56,0.23,0.6),2*scale_value,true)
	if pilot==5 and reactor_ttl>0:
		canvas.draw_arc(point+Vector2(0,20)*scale_value,30*scale_value,0,TAU,32,Color(0.95,0.81,0.48,0.45),2*scale_value,true)
