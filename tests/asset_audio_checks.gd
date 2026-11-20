extends RefCounted
## Verify real signal routing and bounded playback, independently of combat damage.
func run(check: Callable, screen: Node) -> void:
	var active: bool = Sfx.activated
	var enabled: bool = State.sound_enabled
	Sfx.stop_all(); Sfx.activate(); State.sound_enabled = true
	for mode in ["standard","burst","rail","plasma","laser","pulse","missile","blade"]:
		Sfx.stop_all()
		var voice: int = Sfx.cursor
		State.weapon_fired.emit(mode,Vector2.ZERO,Vector2.RIGHT,false)
		var clip: String = "beam" if mode=="laser" else mode
		check.call(Sfx.POOLS.get(clip,[Sfx.CLIPS[clip]]).has(Sfx.players[voice].stream),"%s fires its own CC0 sound through the live signal"%mode)
	for mode in ["gauntlet","hammer"]:
		Sfx.stop_all()
		var voice: int = Sfx.cursor
		State.weapon_fired.emit(mode,Vector2.ZERO,Vector2.RIGHT,false)
		check.call(Sfx.cursor==voice,"%s waits for actual contact before sounding"%mode)
		State.attack_hit.emit(Vector2.ZERO,30,mode)
		check.call(Sfx.POOLS[mode].has(Sfx.players[voice].stream),"%s contact selects its distinct metal impact"%mode)
	Sfx.stop_all()
	State.weapon_fired.emit("standard",Vector2.ZERO,Vector2.RIGHT,false)
	var cursor: int = Sfx.cursor
	State.shot.emit(true,10)
	check.call(Sfx.cursor==cursor,"friendly shot reporting cannot double-play an already routed weapon")
	State.weapon_fired.emit("standard",Vector2.ZERO,Vector2.RIGHT,false)
	check.call(Sfx.cursor==cursor,"rapid consecutive fire is rate limited")
	Sfx.stop_all()
	for i in range(Sfx.players.size()):
		Sfx.last_played.clear()
		Sfx.play("rail")
	var original: Array = []
	for player in Sfx.players: original.append(player.stream)
	Sfx.play("step")
	var unchanged := true
	for i in range(Sfx.players.size()): unchanged = unchanged and Sfx.players[i].stream==original[i]
	check.call(unchanged,"a full combat voice pool drops footsteps without cutting off playing weapons")
	var important_voice: int = Sfx.cursor
	Sfx.play("reward")
	check.call(Sfx.players[important_voice].stream==Sfx.CLIPS.reward,"important reward feedback remains audible during saturated combat")
	Sfx.stop_all()
	check.call(Sfx.players.size()==Sfx.VOICES and Sfx.players.all(func(p): return not p.playing),"mute stops every bounded voice")
	# Consecutive samples must differ without a statistical or timing-dependent assertion.
	for kind in Sfx.POOLS:
		var previous = null
		for i in range(5):
			Sfx.stop_all()
			var voice: int = Sfx.cursor
			Sfx.play(kind)
			var stream = Sfx.players[voice].stream
			check.call(Sfx.POOLS[kind].has(stream),"%s variant stays within its licensed sample pool"%kind)
			if previous!=null and Sfx.POOLS[kind].size()>1:
				check.call(previous!=stream,"%s never repeats a consecutive sample"%kind)
			previous = stream
	Sfx.stop_all()
	var spatial_voice: int = Sfx.cursor
	Sfx.play_at("impact",World.position+Vector2(-400,0))
	var near_volume: float = Sfx.players[spatial_voice].volume_db
	check.call(Sfx.panners[spatial_voice].pan<0,"left-side contact is panned left")
	Sfx.stop_all()
	spatial_voice = Sfx.cursor
	Sfx.play_at("impact",World.position+Vector2(1000,0))
	check.call(Sfx.panners[spatial_voice].pan>0 and Sfx.players[spatial_voice].volume_db<near_volume,"distant right-side contact is quieter and panned right")
	Sfx.stop_all()
	spatial_voice = Sfx.cursor
	Sfx.play("click")
	check.call(Sfx.panners[spatial_voice].pan==0 and Sfx.players[spatial_voice].pitch_scale>=0.96 and Sfx.players[spatial_voice].pitch_scale<=1.04,"reused voices reset panning and preserve clear interface pitch")
	for kind in ["discover","repair","vent","loot","step","brake","boost"]:
		Sfx.stop_all()
		var voice: int = Sfx.cursor
		State.field_effect.emit(kind,World.position,Vector2.ZERO)
		check.call(Sfx.cursor!=voice,"%s field event has live audio feedback"%kind)
	Sfx.stop_all()
	State.weapon_fired.emit("rail",World.position,World.position+Vector2.RIGHT,true)
	check.call(Sfx.last_played.has("rail") and Sfx.last_played.has("critical"),"critical fire layers a restrained energy accent over the weapon")
	Sfx.stop_all()
	State.attack_hit.emit(World.position,10,"laser")
	check.call(Sfx.last_played.has("energy_impact") and not Sfx.last_played.has("shield"),"beam contact does not throttle the pilot shield skill")
	Sfx.stop_all()
	State.attack_hit.emit(World.position,10,"missile")
	check.call(Sfx.last_played.has("heavy_explosion"),"missile contact has its own explosive weight")
	Sfx.stop_all()
	var tail_voice: int = Sfx.cursor
	Sfx.play("boost")
	var initial_level: float = Sfx.players[tail_voice].volume_db
	Sfx.advance_tails(0.68)
	check.call(Sfx.players[tail_voice].volume_db<initial_level,"long engine samples fade out after their short event cue")
	Sfx.advance_tails(0.1)
	check.call(not Sfx.players[tail_voice].playing,"boost cannot occupy a voice for the full five-second source recording")
	Sfx.stop_all(); State.sound_enabled = false
	cursor = Sfx.cursor
	State.weapon_fired.emit("rail",Vector2.ZERO,Vector2.RIGHT,false)
	State.attack_hit.emit(Vector2.ZERO,30,"hammer")
	State.feedback.emit("shield")
	World.enemy_fired.emit(Vector2.ZERO,10)
	State.field_effect.emit("boost",World.position,Vector2.ZERO)
	check.call(Sfx.cursor==cursor,"global mute suppresses weapon, contact, skill and enemy sounds")
	Sfx.stop_all(); State.sound_enabled = true; Sfx.activated = false
	State.weapon_fired.emit("missile",Vector2.ZERO,Vector2.RIGHT,false)
	check.call(Sfx.cursor==cursor,"combat cannot unlock browser audio before user interaction")
	check.call(screen.refs.base_caption_salvage is Label,"facility texture ornaments preserve the live caption reference")
	check.call(screen.refs.base_facility_hangar.get_theme_stylebox("normal") is StyleBoxTexture,"carrier facilities use imported nine-slice textures")
	Sfx.activated = active; State.sound_enabled = enabled
