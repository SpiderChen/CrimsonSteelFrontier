extends RefCounted
const ENGINE = preload("res://scripts/attack_system.gd")
const VISUAL = preload("res://scripts/attack_visuals.gd")
const MECH = preload("res://scripts/mech_art.gd")
const MODES = ["burst","rail","plasma","missile","laser","pulse","blade","hammer"]
const LABELS = ["连射 · 炽热曳光","轨道炮 · 电磁余迹","等离子 · 聚能爆破","导弹 · 尾焰追踪","激光 · 持续灼切","脉冲 · 高能束流","能量剑 · 剑尖光带","重锤 · 冲击碎屑"]

class Arena extends Node:
	var target := Vector2(240,0)
	var blocked: bool = false
	func attack_targets() -> Array: return [{"id":"target","p":target,"hp":100000.0}]
	func player_position() -> Vector2: return Vector2.ZERO
	func player_alive() -> bool: return true
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return not blocked
	func cell_at(p: Vector2) -> Vector2i: return Vector2i(p/128)
	func is_obstacle(_cell: Vector2i) -> bool: return false
	func apply_attack_event(event: Dictionary) -> float: return float(event.damage)

class Gallery extends Control:
	var engines: Array = []
	var draws: int = 0
	func _draw() -> void:
		draws += 1
		draw_rect(Rect2(Vector2.ZERO,size),Color("0b121d"))
		var font = preload("res://assets/fonts/NotoSansSC.otf")
		draw_string(font,Vector2(28,48),"绯红战线 / 武器特效",HORIZONTAL_ALIGNMENT_LEFT,-1,29,Color("edf4ff"))
		draw_string(font,Vector2(28,78),"真实弹道 · 枪口挂点 · 命中反馈",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("8195ac"))
		for i in range(engines.size()):
			var cell := Vector2(18+(i%2)*352,102+int(i/2)*286)
			draw_style_box(card_style(),Rect2(cell,Vector2(334,270)))
			var color: Color = VISUAL.VFX.tint(MODES[i])
			draw_line(cell+Vector2(16,48),cell+Vector2(318,48),Color(color,0.25),1,true)
			draw_string(font,cell+Vector2(16,32),LABELS[i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,color)
			for x in range(24,320,32): draw_line(cell+Vector2(x,64),cell+Vector2(x,248),Color(0.5,0.7,0.9,0.035),1)
			var center := cell+Vector2(65,155)
			var engine = engines[i]
			var target := Vector2(240,0) if i<6 else Vector2(90,0)
			var loadout := {"drive":"walk","weapons":[{"slot":0,"mode":MODES[i],"blueprint":MECH.CONTENT.WEAPONS[MODES[i]]}]}
			var pose := {"ready_slots":{0:1.0},"aim_point":(target*0.85+Vector2(0,20))/0.43}
			MECH.render(self,center-Vector2(0,20),0.43,MECH.COLORS[0],false,engine.visual_time,pose,loadout,engine,Vector2.RIGHT,null,"vfx-gallery-%d"%i)
			var enemy := center+target*0.85
			draw_arc(enemy,20,0,TAU,24,Color("34495e"),1,true)
			MECH.CONTENT.enemy(self,enemy,"guard",false,0.5,true,"vfx-gallery-%d"%i,Vector2.LEFT)
			var muzzle := func(slot): return center-Vector2(0,20)+MECH.muzzle_offset(0,pose,loadout,engine,Vector2.RIGHT,slot,0.43,self)
			VISUAL.render(self,engine,func(p): return center+p*0.85,0.85,Vector2.ZERO,muzzle,true)
	static func card_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("101d2c"); style.border_color = Color("233247")
		style.set_border_width_all(1); style.set_corner_radius_all(8)
		return style

func run(check: Callable, main: Node) -> void:
	var arena := Arena.new(); main.add_child(arena)
	var engine = ENGINE.new()
	engine.launch(Vector2.ZERO,arena.target,100,"rail","",0)
	engine.advance(arena,0.1)
	check.call(engine.stats.hits==0 and engine.flashes.all(func(f): return f.kind!="impact"),"rail flight cannot paint an unconfirmed hit")
	check.call(engine.projectiles[0].trail.size()>2 and engine.projectiles[0].trail.size()<=12,"rail light follows a bounded actual flight path")
	engine.advance(arena,0.04)
	check.call(engine.projectiles.is_empty() and engine.wakes.size()==1 and engine.stats.hits==1,"rail contact leaves one short-lived wake after the projectile ends")
	engine.advance(arena,0.3)
	check.call(engine.wakes.is_empty() and engine.flashes.is_empty(),"rail wake and hit flash expire without leaving persistent geometry")
	engine.reset(); arena.blocked = true
	engine.launch(Vector2.ZERO,arena.target,100,"plasma","",0); engine.advance(arena,0.4)
	check.call(engine.stats.hits==0 and engine.effects.is_empty(),"blocked plasma cannot show a target explosion")
	arena.blocked = false
	engine.launch(Vector2.ZERO,arena.target,100,"plasma","",0); engine.advance(arena,0.32)
	check.call(engine.effects.size()==1 and engine.effects[0].radius==150 and engine.stats.damage==100,"confirmed plasma contact adds visual blast without applying extra damage")
	for i in range(180):
		engine.launch(Vector2.ZERO,arena.target,100,"rail","",0); engine.advance(arena,0.001)
	check.call(engine.wakes.size()<=32 and engine.projectiles.size()<=128,"dense firing keeps wakes and projectile pools bounded")
	engine.reset()
	check.call(engine.visual_time==0 and engine.wakes.is_empty(),"reset clears presentation clock and residual trails")
	var gallery := Gallery.new(); gallery.size = Vector2(720,1280); gallery.z_index = 100; main.add_child(gallery)
	for mode in MODES:
		var item = ENGINE.new()
		arena.target = Vector2(240,0) if not ENGINE.MELEE.is_mode(mode) else Vector2(90,0)
		item.launch(Vector2.ZERO,arena.target,100,mode,"",1,{"slot":0,"range":300,"target_id":"target"})
		item.advance(arena,0.17 if mode=="blade" else 0.35 if mode=="hammer" else 0.04 if mode=="rail" else 0.02 if mode=="burst" else 0.25)
		gallery.engines.append(item)
	for frame in range(5):
		for i in range(gallery.engines.size()):
			arena.target = Vector2(240,0) if i<6 else Vector2(90,0)
			gallery.engines[i].advance(arena,0.016)
		gallery.queue_redraw()
		await main.get_tree().process_frame; await main.get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png("res://tests/weapon-vfx-gallery.png")
	var time_before: float = gallery.engines[0].visual_time
	gallery.queue_redraw(); await main.get_tree().process_frame; await main.get_tree().process_frame
	check.call(gallery.draws>0 and gallery.engines[0].visual_time==time_before,"real canvas rendering does not advance simulation or paused VFX time")
	check.call(VISUAL.VFX.glow_texture!=null,"all weapon glows share one cached texture")
	gallery.queue_free(); arena.queue_free()
