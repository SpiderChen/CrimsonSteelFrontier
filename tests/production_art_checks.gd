extends RefCounted
const ART = preload("res://scripts/production_art.gd")
const VISUALS = preload("res://scripts/attack_visuals.gd")
const ENGINE = preload("res://scripts/attack_system.gd")
class Arena extends Node:
	var units: Array = [{"id":"target","p":Vector2(55,0),"hp":100000.0}]
	func attack_targets() -> Array: return units
	func line_clear(_a: Vector2,_b: Vector2) -> bool: return true
	func cell_at(p: Vector2) -> Vector2i: return Vector2i(p/128)
	func is_obstacle(_cell: Vector2i) -> bool: return false
	func apply_attack_event(event: Dictionary) -> float:
		units[0].hp -= event.damage
		return float(event.damage)
class Gallery extends Control:
	var engines: Array = []
	var draws: int = 0
	func _draw() -> void:
		draws += 1
		var cell := 0
		for key in ART.SHEETS:
			var grid: Vector2i = ART.GRIDS[key]
			for index in range(grid.x*grid.y):
				ART.draw(self,key,index,Rect2((cell%10)*64,int(cell/10)*64,60,60))
				cell += 1
		for engine in engines: VISUALS.render(self,engine,func(point): return point+Vector2(300,800),0.7)

func run(check: Callable,main: Node) -> void:
	var count := 0
	for key in ART.SHEETS:
		var grid: Vector2i = ART.GRIDS[key]
		var image: Image = ART.SHEETS[key].get_image()
		check.call(not image.is_empty(),"production sheet %s decodes"%key)
		if key not in ["terrain","hangar"]:
			check.call(image.detect_alpha()!=Image.ALPHA_NONE,"production sprite sheet %s has an alpha channel"%key)
			check.call(image.get_pixel(0,0).a<0.01,"production sprite %s has no opaque matte background"%key)
		for index in range(grid.x*grid.y):
			var rect := ART.source(key,index)
			check.call(rect.has_area() and Rect2(Vector2.ZERO,image.get_size()).encloses(rect),"%s cell %d contains an in-bounds sprite"%[key,index])
			count += 1
	check.call(count>=98,"production sheets cover all enemies, bosses, scenery, 25 equipment items and combat effects")
	check.call(ART.texture("equipment",0)!=ART.texture("equipment",1) and ART.texture("equipment",0)==ART.texture("equipment",0),"equipment atlas entries are distinct and cached")
	check.call(main.icon_texture(ART.texture("equipment",0))!=main.icon_texture(ART.texture("equipment",1)),"UI icon caching cannot replace every equipment icon with the first image")
	check.call(ART.frame(0)==0 and ART.frame(0.26)==1 and ART.frame(0.51)==2 and ART.frame(0.99)==3,"VFX animation advances across its four frames")
	var gallery := Gallery.new(); gallery.size=Vector2(720,1280); main.add_child(gallery)
	var arena := Arena.new(); main.add_child(arena)
	for mode in ["standard","burst","rail","plasma","laser","pulse","missile","blade","gauntlet","hammer"]:
		var engine=ENGINE.new()
		engine.launch(Vector2.ZERO,Vector2(55,0),100,mode,"",0,{"range":300,"target_id":"target"})
		check.call(not engine.flashes.any(func(f):return f.kind=="impact"),"%s never paints a hit before the simulator confirms contact"%mode)
		var before: float=arena.units[0].hp
		engine.advance(arena,0.20 if mode=="blade" else 0.12 if mode=="gauntlet" else 0.38 if mode=="hammer" else 0.05)
		if mode in ["blade","gauntlet","hammer"]: check.call(not engine.swings.is_empty() and engine.swings[0].active,"%s draws its effect during the actual active strike window"%mode)
		gallery.engines.append(engine)
		gallery.queue_redraw(); await main.get_tree().process_frame; await main.get_tree().process_frame
		engine.advance(arena,1.5)
		check.call(arena.units[0].hp<before and engine.stats.hits>0,"%s uses real damage while its artwork renders"%mode)
		check.call(engine.flashes.size()<=96,"%s keeps its visual event pool bounded"%mode)
	gallery.queue_redraw(); await main.get_tree().process_frame; await main.get_tree().process_frame
	check.call(gallery.draws>0 and ART.drawn.size()>=ART.SHEETS.size(),"all production textures execute real CanvasItem draw calls")
	gallery.queue_free();arena.queue_free()
	var original: Dictionary=State.save_payload().duplicate(true)
	var enabled: bool=World.enabled
	State.parts=State.PARTS.new();State.parts.starter();State.recovery=0;State.hp=100;State.selected_mech=0
	State.expedition=State.EXPEDITION.new();State.expedition.clears=[1,1,1,1]
	World.enabled=false;World.import_save({"docked":true})
	for region in range(4):
		check.call(State.expedition.begin(World,region),"production fixtures enter map %d"%region)
		main.show_page(0)
		var map=main.refs.map
		if region==0:
			map.floats.clear()
			map.damage_number(Vector2.ZERO,10,true);map.damage_number(Vector2(1,0),20,true)
			check.call(map.floats.size()==1 and map.floats[0].v=="30","nearby burst damage merges without losing its total")
			map.damage_number(Vector2.ZERO,5,false)
			check.call(map.floats.size()==2,"incoming damage remains separate from outgoing damage")
			map.floats[0].t=0.8;map.damage_number(Vector2.ZERO,7,true)
			check.call(map.floats.size()==3,"later hits start a new number instead of extending old damage forever")
			for i in range(40): map.damage_number(Vector2(i*100,0),1,true)
			check.call(map.floats.size()==32,"dense combat keeps damage text bounded")
			map.floats.clear()
		map.trails=[{"p":World.position,"mode":"hover","boost":false,"t":0.5},{"p":World.position,"mode":"dash","boost":true,"t":0.5,"angle":0.0},{"p":World.position,"mode":"walk","boost":false,"t":0.5}]
		for kind in ["enemy","supply","cache","cooling","boss_site"]:
			var sites: Array=State.expedition.locations.filter(func(site):return site.kind==kind)
			var point: Vector2=sites[0].p
			World.position=point+Vector2(0,80);State.expedition.reveal(World.position)
			map.camera=point;map.following=false;map.queue_redraw()
			await main.get_tree().process_frame;await main.get_tree().process_frame
		var boss: Dictionary=State.expedition.boss_site()
		World.position=boss.p-Vector2(150,0);State.expedition.reveal(World.position)
		check.call(State.expedition.start_boss(World,boss.id),"region %d boss retains its actual challenge rules with new art"%region)
		map.camera=boss.p
		map.queue_redraw();await main.get_tree().process_frame;await main.get_tree().process_frame
		check.call(map.get_meta("unit_3d_views",{}).has("boss") and int(ART.drawn.get("terrain",0))>0,"map %d draws terrain and a live 3D boss"%region)
		State.expedition.withdraw(World)
		await main.get_tree().process_frame
		await main.get_tree().process_frame
	main.show_page(1)
	check.call(main.body.find_children("PartArt_*","TextureRect",true,false).size()==6,"all six hangar equipment slots have real item images")
	main.show_manufacturing()
	check.call(main.overlay.find_children("PartArt_*","TextureRect",true,false).size()==25,"all 25 manufacturing blueprints show their own item art")
	main.close_modal();main.show_training()
	var training=main.refs.training_view
	training.set_process(false);training.queue_redraw()
	await main.get_tree().process_frame;await main.get_tree().process_frame
	check.call(is_instance_valid(training) and int(ART.drawn.get("hangar",0))>0,"training uses the actual hangar, chassis, equipment and hostile sprites")
	for blueprint in range(25):
		var part: Dictionary=State.parts.roll(blueprint,0)
		main.show_part_detail(part.id)
		check.call(not main.overlay.find_children("PartArt_*","TextureRect",true,false).is_empty(),"equipment detail %d consumes the generated item sprite"%blueprint)
	main.close_modal();State.import_game(original);World.enabled=enabled
