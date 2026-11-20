extends RefCounted
## Shared by real combat and training; armor, shield and repairs use identical rules.
const HAND_SHIELD = preload("res://scripts/hand_shield.gd")
var guard: float = 0
var max_guard: float = 0
var guard_break: float = 0
var guard_quiet: float = 0
var guard_blocked: float = 0
var guard_facing := Vector2.RIGHT
var hp: float = 100
var shield: float = 0
var max_shield: float = 0
var barrier_clock: float = 0
var quiet: float = 0
var absorbed: float = 0
var prevented: float = 0
var healed: float = 0
var temporary_shield: float = 0
var temporary_ttl: float = 0
var counter_charge: float = 0
var counter_cooldown: float = 0
var counter_ready: bool = false
var hits: int = 0
var shield_flash: float = 0
var shield_hit_angle: float = 0

func configure(stats: Dictionary, refill: bool = false) -> void:
	if refill: temporary_shield = 0; temporary_ttl = 0
	max_shield = maxf(0,float(stats.get("shield",0)))
	shield = max_shield if refill else minf(shield,max_shield)
	max_guard = maxf(0,float(stats.get("guard_capacity",0)))
	guard = max_guard if refill else minf(guard,max_guard)
	if refill: guard_break = 0; guard_quiet = 0

func advance(delta: float, stats: Dictionary, nanite: bool) -> void:
	shield_flash = maxf(0,shield_flash-delta)
	counter_cooldown = maxf(0,counter_cooldown-delta)
	temporary_ttl = maxf(0,temporary_ttl-delta)
	if temporary_ttl<=0: temporary_shield = 0
	barrier_clock = maxf(0,barrier_clock-delta)
	var prior_quiet := quiet
	quiet += delta
	configure(stats)
	var prior_guard_quiet := guard_quiet
	guard_quiet += delta
	guard_break = maxf(0,guard_break-delta)
	if guard_break<=0 and guard_quiet>HAND_SHIELD.RECOVERY_DELAY:
		guard = minf(max_guard,guard+(guard_quiet-maxf(HAND_SHIELD.RECOVERY_DELAY,prior_guard_quiet))*HAND_SHIELD.RECOVERY_RATE)
	if quiet>4: shield = minf(max_shield,shield+(quiet-maxf(4,prior_quiet))*4)
	if nanite and hp>0: heal(delta*1.2)

func heal(amount: float) -> void:
	var before := hp
	hp = minf(100,hp+maxf(0,amount))
	healed += hp-before

func hit(raw_damage: int, stats: Dictionary, barrier: bool, contact: Dictionary = {}) -> int:
	if hp<=0 or raw_damage<=0: return 0
	configure(stats)
	var damage := maxi(1,int(round(raw_damage*(1-clampf(float(stats.armor),0,65)/100.0))))
	var incoming: Vector2 = contact.get("incoming",Vector2.ZERO)
	var facing: Vector2 = contact.get("facing",guard_facing)
	if max_guard>0 and guard>0 and guard_break<=0 and incoming.length_squared()>0.001 and facing.length_squared()>0.001 and absf(facing.angle_to(incoming))<=HAND_SHIELD.ARC*0.5 and bool(contact.get("blockable",true)):
		var saved: int = mini(int(guard),int(round(damage*HAND_SHIELD.BLOCK)))
		guard -= saved; damage -= saved; guard_blocked += saved
		if guard<1: guard = 0; guard_break = HAND_SHIELD.BREAK_SECONDS
	if barrier and barrier_clock<=0 and damage>0:
		damage = maxi(1,int(round(damage*0.4)))
		barrier_clock = 6
		shield_flash = 0.22; shield_hit_angle = incoming.angle() if incoming!=Vector2.ZERO else -PI/2
	prevented += maxi(0,raw_damage-damage)
	var effective := damage
	var temporary := minf(temporary_shield,damage)
	temporary_shield -= temporary
	damage -= int(temporary)
	absorbed += temporary
	var blocked := minf(shield,damage)
	shield -= blocked
	absorbed += blocked
	if temporary+blocked>0:
		shield_flash = 0.22; shield_hit_angle = incoming.angle() if incoming!=Vector2.ZERO else -PI/2
	var before := hp
	hp = maxf(0,hp-(damage-blocked))
	if bool(stats.get("counter",false)):
		counter_charge += before-hp
		if hp>0 and counter_charge>=35 and counter_cooldown<=0:
			counter_charge -= 35; counter_cooldown = 5; counter_ready = true
	quiet = 0
	guard_quiet = 0
	hits += 1
	return effective

func grant_temporary(amount: float, duration: float) -> void:
	temporary_shield = maxf(temporary_shield,amount)
	temporary_ttl = maxf(temporary_ttl,duration)

func total_shield() -> float: return shield+temporary_shield
