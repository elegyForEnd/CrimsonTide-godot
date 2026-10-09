extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,reason:String):
 checks+=1
 if not ok: failures+=1;push_error(reason)
func _initialize(): call_deferred('run')
func run():
 for f in 5:
  for a in range(1,6):
   for long_room in [false,true]:
    var map=preload('res://scripts/rogue_map.gd').new()
    map.generate(1729)
    map.configure(f,a,long_room)
    for index in 2:
     var at:=Vector2(map.width*.70,map.lane_center(map.width*.70))
     var route:Array=[]
     if index==0:
      for x in [.75,.80,.85,.90,.95]:
       if x<map.region.exits[index][0]: route.append(Vector2(map.width*x,map.lane_center(map.width*x)-map.extent.y*.012))
     else:
      var b:Array=map.region.branch
      route.append(map.uv_point([b[0][0],(b[0][1]+b[-1][1])/2]))
      if f==0 and a==3: route.append(Vector2(map.width*.80,map.lane_center(map.width*.80)))
      for i in range(1,b.size()/2-1):
       if b[i][0]<map.region.exits[index][0]: route.append(map.uv_point([b[i][0],(b[i][1]+b[b.size()-1-i][1])/2]))
     route.append(map.exit_position(index))
     for waypoint in route:
      at=map.move(at,waypoint-at,20)
      check(at.distance_to(waypoint)<1,'Road centerline f%d-a%d long=%s exit=%d waypoint=%s'%[f+1,a,long_room,index,waypoint])
     check(not map.blocked(map.exit_position(index),25),'Exit clearance')
 var s=TideSession.new()
 root.add_child(s)
 s.set_physics_process(false)
 s.solo({'hero':0,'mode':'roguelike'})
 check(s.launch(false,1729),'Run starts')
 var p:Dictionary=s.players[1]
 while not p.rogue_selection.is_empty():
  s.perform(1,'rogue_selection_take',{'id':p.rogue_selection.id,'version':p.rogue_selection.version,'index':0})
 s.roguelike.tick(s,.016)
 # R5: the room rows come from the node graph, so the sanctuary row and the branching
 # guardian gate are located through the graph instead of the retired slot template.
 var graph=preload('res://scripts/rogue_graph.gd')
 var depth_total:int=s.roguelike.depth_count(s)
 var sanctuary_depth:=2
 for d in range(2,depth_total+1):
  var node_id:String=s.roguelike.node_at_depth(s.rogue_graph,d)
  if node_id!='' and str(graph.node(s.rogue_graph,node_id).kind)=='talent': sanctuary_depth=d; break
 s.raid.area=sanctuary_depth
 s.roguelike.enter(s)
 while not p.rogue_selection.is_empty():
  s.perform(1,'rogue_selection_take',{'id':p.rogue_selection.id,'version':p.rogue_selection.version,'index':0})
 check(s.raid.phase=='rogue_exit','Sanctuary rewards open the exits')
 s.raid.area=depth_total-1
 s.roguelike.enter(s)
 s.enemies.clear()
 s.raid.phase='rogue_exit'
 check(s.raid.exits.size()==2,'Two destinations in branching encounter')
 p.p=s.ruins.exit_position(1)
 var expected:String=s.raid.exits[1].room
 s.interact(p,true,.016)
 check(s.raid.area==depth_total and s.raid.room==expected,'E follows the diagonal route')
 s.queue_free()
 await process_frame
 print('EXIT ALIGNMENT ',checks,' checks / ',failures,' failures')
 quit(1 if failures else 0)
