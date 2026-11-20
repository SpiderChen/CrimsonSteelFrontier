extends Node
## Local CC0 samples; presentation RNG never changes combat or loot rolls.
const MELEE = preload("res://scripts/melee.gd")
const CLIPS := {
	"click": preload("res://assets/free/audio/ui_click.ogg"),
	"laser": preload("res://assets/free/audio/laser.ogg"),
	"standard": preload("res://assets/free/audio/autocannon.ogg"),
	"burst": preload("res://assets/free/audio/autocannon.ogg"),
	"rail": preload("res://assets/free/audio/rail.ogg"),
	"plasma": preload("res://assets/free/audio/plasma.ogg"),
	"beam": preload("res://assets/free/audio/beam.ogg"),
	"missile": preload("res://assets/free/audio/missile.ogg"),
	"blade": preload("res://assets/free/audio/blade.ogg"),
	"gauntlet": preload("res://assets/free/audio/punch.ogg"),
	"hammer": preload("res://assets/free/audio/hammer.ogg"),
	"impact": preload("res://assets/free/audio/impact.ogg"),
	"ultimate": preload("res://assets/free/audio/ultimate.ogg"),
	"shield": preload("res://assets/free/audio/shield.ogg"),
	"explosion": preload("res://assets/free/audio/explosion.ogg"),
	"heavy_explosion": preload("res://assets/free/audio/heavy_explosion.ogg"),
	"upgrade": preload("res://assets/free/audio/resonance.ogg"),
	"recruit": preload("res://assets/free/audio/resonance.ogg"),
	"reward": preload("res://assets/free/audio/reward.ogg"),
	"pulse": preload("res://assets/free/audio/pulse.ogg"),
	"boost": preload("res://assets/free/audio/boost.ogg"),
	"vent": preload("res://assets/free/audio/vent.ogg"),
	"discover": preload("res://assets/free/audio/discover.ogg"),
	"repair": preload("res://assets/free/audio/repair.ogg"),
	"critical": preload("res://assets/free/audio/critical.ogg"),
	"energy_impact": preload("res://assets/free/audio/shield_alt.ogg"),
	"step": preload("res://assets/free/audio/impact_alt.ogg"),
	"brake": preload("res://assets/free/audio/impact_heavy.ogg")
}
const POOLS := {
	"standard":[CLIPS.standard,preload("res://assets/free/audio/autocannon_alt.ogg"),preload("res://assets/free/audio/autocannon_tail.ogg")],
	"burst":[CLIPS.burst,preload("res://assets/free/audio/autocannon_alt.ogg"),preload("res://assets/free/audio/autocannon_tail.ogg")],
	"rail":[CLIPS.rail,preload("res://assets/free/audio/rail_alt.ogg")],
	"plasma":[CLIPS.plasma,preload("res://assets/free/audio/plasma_alt.ogg")],
	"beam":[CLIPS.beam,preload("res://assets/free/audio/beam_alt.ogg")],
	"laser":[CLIPS.laser,preload("res://assets/free/audio/laser_alt.ogg")],
	"missile":[CLIPS.missile,preload("res://assets/free/audio/missile_alt.ogg")],
	"blade":[CLIPS.blade,preload("res://assets/free/audio/shield_alt.ogg")],
	"gauntlet":[CLIPS.gauntlet,CLIPS.step],
	"hammer":[CLIPS.hammer,CLIPS.brake],
	"impact":[CLIPS.impact,CLIPS.step,CLIPS.brake],
	"explosion":[CLIPS.explosion,preload("res://assets/free/audio/explosion_alt.ogg")],
	"heavy_explosion":[CLIPS.heavy_explosion,preload("res://assets/free/audio/heavy_explosion_alt.ogg")],
	"shield":[CLIPS.shield,preload("res://assets/free/audio/shield_alt.ogg")],
	"recruit":[preload("res://assets/free/audio/recruit.ogg")],
	"step":[CLIPS.step,CLIPS.gauntlet]
}
const INTERVALS := {"click":55,"standard":65,"burst":65,"rail":120,"plasma":130,"beam":300,"pulse":150,"missile":170,"blade":170,"gauntlet":85,"hammer":170,"impact":115,"energy_impact":180,"explosion":170,"heavy_explosion":200,"critical":200,"step":190,"brake":350,"boost":600,"vent":900,"discover":700,"repair":900}
const PRIORITIES := {"step":0,"brake":0,"laser":1,"impact":1,"energy_impact":1,"explosion":3,"heavy_explosion":3,"critical":3,"ultimate":4,"shield":4,"click":5,"upgrade":5,"recruit":5,"reward":5,"discover":4,"repair":4}
const VOICES = 12
# The source engine/computer recordings are five seconds long; keep event cues brief.
const DURATIONS := {"missile":0.65,"boost":0.7,"vent":0.85,"discover":0.75,"repair":1.0,"recruit":1.4,"reward":0.65}
var players: Array[AudioStreamPlayer] = []
var panners: Array[AudioEffectPanner] = []
var priorities: Array[int] = []
var tails: Array[float] = []
var levels: Array[float] = []
var cursor: int = 0
var activated: bool = false
var last_played: Dictionary = {}
var last_variant: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	# Runtime buses stay inside this process. Stream playback enables the same mixer on Web.
	AudioServer.add_bus()
	var mix_bus := AudioServer.bus_count-1
	AudioServer.set_bus_name(mix_bus,"CombatSfx")
	AudioServer.add_bus_effect(mix_bus,AudioEffectLimiter.new())
	for i in range(VOICES):
		AudioServer.add_bus()
		var bus := AudioServer.bus_count-1
		var bus_name := "SfxVoice%d"%i
		AudioServer.set_bus_name(bus,bus_name)
		AudioServer.set_bus_send(bus,"CombatSfx")
		var panner := AudioEffectPanner.new()
		AudioServer.add_bus_effect(bus,panner)
		panners.append(panner)
		var player := AudioStreamPlayer.new()
		player.bus = bus_name
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		players.append(player)
		priorities.append(0)
		tails.append(0.0)
		levels.append(0.0)
	State.shot.connect(on_shot)
	State.weapon_fired.connect(on_weapon_fired)
	State.attack_hit.connect(on_hit)
	State.victory.connect(func(): play("explosion",-21))
	State.feedback.connect(func(kind: String): play(kind,-21))
	State.field_effect.connect(on_field_effect)
	World.enemy_fired.connect(func(from: Vector2,_damage: int): play_at("laser",from,-33))

func activate() -> void:
	activated = true

func _process(delta: float) -> void:
	advance_tails(delta)

func advance_tails(delta: float) -> void:
	for i in range(players.size()):
		if tails[i]<=0: continue
		tails[i] = maxf(0,tails[i]-delta)
		if tails[i]<=0: players[i].stop()
		elif tails[i]<0.12:
			players[i].volume_db = levels[i]+linear_to_db(maxf(0.001,tails[i]/0.12))

func play(kind: String, volume: float = -24.0, pan: float = 0.0) -> void:
	if not activated or not State.sound_enabled or not CLIPS.has(kind): return
	var now := Time.get_ticks_msec()
	if now-int(last_played.get(kind,-10000))<int(INTERVALS.get(kind,100)): return
	var voice := -1
	for offset in range(players.size()):
		var index := (cursor+offset)%players.size()
		if not players[index].playing:
			voice = index
			break
	var priority := int(PRIORITIES.get(kind,2))
	# Important feedback can replace quieter ambience; footsteps cannot cut off weapons.
	if voice<0:
		var lowest := priority
		for offset in range(players.size()):
			var index := (cursor+offset)%players.size()
			if priorities[index]<lowest:
				lowest = priorities[index]; voice = index
		if voice<0: return
	var player := players[voice]
	player.stop()
	var pool: Array = POOLS.get(kind,[CLIPS[kind]])
	var variant := 0
	if pool.size()>1:
		# Pick any sample except the previous one, including across separated bursts.
		var previous := int(last_variant.get(kind,-1))
		variant = rng.randi_range(0,pool.size()-2) if previous>=0 else rng.randi_range(0,pool.size()-1)
		if previous>=0 and variant>=previous: variant += 1
	last_variant[kind] = variant
	player.stream = pool[variant]
	var precise := kind in ["click","reward","recruit","upgrade","discover","repair"]
	player.pitch_scale = rng.randf_range(0.68,0.80) if kind in ["step","brake"] else rng.randf_range(0.96,1.04) if precise else rng.randf_range(0.91,1.09)
	player.volume_db = volume+rng.randf_range(-1.2,0.6)
	levels[voice] = player.volume_db
	tails[voice] = float(DURATIONS.get(kind,0.0))
	panners[voice].pan = clampf(pan,-0.7,0.7)
	priorities[voice] = priority
	player.play()
	cursor = (voice+1)%players.size()
	last_played[kind] = now

func play_at(kind: String, point: Vector2, volume: float = -24.0) -> void:
	var relative := point-World.position
	play(kind,volume-minf(12.0,relative.length()/90.0),relative.x/520.0)

func on_weapon_fired(mode: String,from: Vector2,_target: Vector2,critical: bool) -> void:
	if mode in ["gauntlet","hammer","hand_shield"]: return
	var clip: String = "beam" if mode=="laser" else mode
	play_at(clip if CLIPS.has(clip) else "standard",from,-25 if mode in ["standard","burst"] else -22)
	if critical: play_at("critical",from,-31)

func on_hit(point: Vector2,_damage: int,mode: String) -> void:
	if MELEE.is_mode(mode): play_at(mode if mode in ["gauntlet","hammer"] else "impact",point,-24)
	elif mode in ["plasma","explosion","missile","carrier"]: play_at("heavy_explosion",point,-27)
	elif mode in ["laser","pulse"]: play_at("energy_impact",point,-35)
	else: play_at("impact",point,-33)

func on_field_effect(kind: String,point: Vector2,_target: Vector2) -> void:
	if kind=="loot": play_at("reward",point,-29)
	elif kind in ["discover","repair","vent","boost","brake","step"]:
		play_at(kind,point,-39 if kind=="step" else -34 if kind=="brake" else -30)

func on_shot(friendly: bool,_damage: int) -> void:
	if not friendly: play("impact",-28)

func stop_all() -> void:
	for player in players: player.stop()
	tails.fill(0.0)
	last_played.clear()
