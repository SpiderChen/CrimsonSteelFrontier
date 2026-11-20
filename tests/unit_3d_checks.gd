extends RefCounted
const VIEW = preload("res://scripts/rig/unit_viewport.gd")
const ART = preload("res://scripts/rig/unit_art.gd")
class Gallery extends Control:
	func _draw() -> void:
		draw_rect(Rect2(0,0,720,1280),Color("101b2b"))
		draw_string(ThemeDB.fallback_font,Vector2(30,48),"LIVE 3D / FLEET & HOSTILES",HORIZONTAL_ALIGNMENT_LEFT,-1,27,Color("c9dfef"))
		ART.render(self,Vector2(360,190),Vector2.ONE*620,"carrier","carrier")
		for i in range(4):
			var role: String = ["guard","rusher","cannon","drone"][i]
			var x: float = 94+i*177
			ART.render(self,Vector2(x,450),Vector2.ONE*180,role,role,0,false,Vector2(0.6,1))
			draw_string(ThemeDB.fallback_font,Vector2(x-42,565),role,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("c9dfef"))
		for i in range(4):
			var center := Vector2(190+(i%2)*340,740+(i/2)*330)
			ART.render(self,center,Vector2.ONE*300,"boss","boss"+str(i),i,false,Vector2(0.6,1))
			draw_string(ThemeDB.fallback_font,center+Vector2(-70,140),"REGION "+str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("d6aa7d"))

func run(check: Callable, main: Node) -> void:
	var view = VIEW.new(); main.add_child(view)
	for kind in ["carrier","guard","rusher","cannon","drone","boss"]:
		for variant in range(4 if kind=="boss" else 1):
			view.update_model(kind,variant,false,Vector2(0.6,1),true,0.3,{})
			var mesh: MeshInstance3D = view.model.get_node("BatchedGeometry")
			check.call(mesh.mesh.get_surface_count()>=3 and mesh.mesh.get_surface_count()<=4,"%s %d uses material-batched real 3D geometry"%[kind,variant])
			if kind=="boss":
				view.update_model(kind,variant,false,Vector2.LEFT,false,0.5,{"tracks":0,"cannon":0,"phase":3})
				check.call(not view.model.tracks.visible and not view.model.cannon.visible and view.model.core.scale.x>1,"boss %d damage hides destroyed modeled assemblies and animates overdrive core"%variant)
			if DisplayServer.get_name()!="headless":
				await main.get_tree().process_frame
				await RenderingServer.frame_post_draw
				var image: Image = view.get_texture().get_image()
				var opaque := 0
				for y in range(0,image.get_height(),8):
					for x in range(0,image.get_width(),8):
						if image.get_pixel(x,y).a>0.5: opaque+=1
				check.call(image.get_pixel(0,0).a<0.01 and opaque>20,"%s %d renders opaque model pixels over transparent background"%[kind,variant])
	var reference: WeakRef = weakref(view.model); view.queue_free(); await main.get_tree().process_frame
	check.call(reference.get_ref()==null,"unit viewport deletion releases its model and assemblies")
	var gallery := Gallery.new(); gallery.size = Vector2(720,1280); gallery.z_index = 100
	main.add_child(gallery)
	await main.get_tree().process_frame; await main.get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png("res://.local/unit-model-gallery.png")
	check.call(gallery.get_meta("unit_3d_views",{}).size()==9,"gallery draws carrier, four hostile classes and four distinct regional bosses")
	gallery.queue_free(); await main.get_tree().process_frame
