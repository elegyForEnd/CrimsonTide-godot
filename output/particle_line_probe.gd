extends SceneTree
const Batch=preload("res://scripts/particle_geometry_batch.gd")
func _initialize(): call_deferred("run")
func run():
 var views=[]
 for index in 2:
  var v=SubViewport.new(); v.size=Vector2i(100,100); v.transparent_bg=true; v.disable_3d=true; v.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(v); views.append(v)
  var n=Node2D.new(); v.add_child(n)
  if index==0: n.draw.connect(func(): n.draw_line(Vector2(30,50),Vector2(70,50),Color(1,1,1,.7),1,true))
  else: n.draw.connect(func(): var b=Batch.new(); b.line(Vector2(30,50),Vector2(70,50),Color(1,1,1,.7),1); b.flush(n))
 await process_frame
 await RenderingServer.frame_post_draw
 for i in 2: views[i].get_texture().get_image().save_png("res://output/line-%d.png"%i)
 quit()
