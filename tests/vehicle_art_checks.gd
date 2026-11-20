extends RefCounted
const MECH_ART = preload("res://scripts/mech_art.gd")
const CARRIER_ART = preload("res://scripts/carrier.gd")
var draws: int = 0

func run(check: Callable, main: Node) -> void:
	for model in range(3):
		var image: Image = MECH_ART.TEXTURES[model].get_image()
		check.call(image.get_width()>=1024 and image.detect_alpha()!=Image.ALPHA_NONE and image.get_pixel(0,0).a==0,"mech %d loads full-resolution original art with genuine transparent margins"%model)
		check.call(MECH_ART.model_for(State.MECHS.MODELS[model].color,false)==model,"chassis %d selects its own complete artwork"%model)
	var ship_view = preload("res://scripts/rig/unit_viewport.gd").new(); main.add_child(ship_view)
	ship_view.update_model("carrier",0,false,Vector2.RIGHT,false,0,{})
	check.call(ship_view.model.get_node("BatchedGeometry") is MeshInstance3D,"carrier uses actual batched 3D hull geometry")
	ship_view.queue_free()
	var original: Dictionary = State.save_payload().duplicate(true)
	var enabled: bool = World.enabled
	World.enabled = false
	State.parts = State.PARTS.new(); State.parts.starter()
	State.recovery = 0; State.hp = 100; State.selected_mech = 0
	State.expedition = State.EXPEDITION.new(); State.expedition.clears = [1,1,1,1]
	World.import_save({"docked":true})
	for region in range(4):
		check.call(State.expedition.begin(World,region),"carrier visual fixture launches map %d"%region)
		main.show_page(0)
		var map = main.refs.map
		check.call(map.carrier_position()==State.expedition.DATA.LANDING and map.carrier_button.visible,"map %d exposes the carrier and dock action at landing"%region)
		var before := draws
		map.draw.connect(func(): draws+=1)
		map.queue_redraw()
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		check.call(draws>before,"map %d executes carrier, terrain and mecha drawing"%region)
		var saved: Dictionary = State.save_payload().duplicate(true)
		State.import_game(saved); main.show_page(0)
		map = main.refs.map
		check.call(map.carrier_position()==State.expedition.DATA.LANDING and map.carrier_button.visible,"map %d reload preserves its visible landing carrier"%region)
		map.camera = State.expedition.DATA.ARENA; map.following = false; map.update_carrier_marker()
		check.call(not map.carrier_button.visible,"offscreen carrier UI does not cover unexplored terrain in map %d"%region)
		map.recenter(); map.update_carrier_marker()
		map.carrier_button.pressed.emit()
		check.call(not World.docked and main.overlay.get_child_count()>0,"map %d carrier click opens a confirmation before leaving"%region)
		main.close_modal()
		State.expedition.run.bounty = 123
		var credits: int = State.credits
		main.request_base()
		var actions: Array = main.overlay.find_children("*","Button",true,false)
		for action in actions:
			if action.text=="回航并停泊": action.get_signal_connection_list("pressed")[0].callable.call(); break
		check.call(World.docked and State.credits==credits+123 and main.page==4,"map %d docking settles bounty once and opens the carrier"%region)
		main.request_base()
		check.call(State.credits==credits+123,"reopening the carrier cannot duplicate map %d bounty"%region)
	State.import_game(original); World.enabled = enabled
