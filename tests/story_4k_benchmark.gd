extends SceneTree
## Real rendered, uncapped 4K walk and sustained combat. Isolated unsaved campaign.
const Screen=preload("res://scripts/story_screen.gd")
var screen
var samples: Array[float]=[]
var cpu: Array[float]=[]
var gpu: Array[float]=[]
var results: Array=[]
var seconds := 600.0
var repeats := 3
var run_index := 0
var run_clock := 0.0
var warmup := 12.0
var previous_usec := 0
var target_index := 0
var targets: Array[Vector2]=[]
var log_clock := 0.0
var combat := false
var boot_usec := 0
var camp_load_ms := 0.0
var cave_load_ms := 0.0
var spawn_counter := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="): seconds=float(arg.get_slice("=",1))
		if arg.begins_with("--runs="): repeats=int(arg.get_slice("=",1))
	root.size=Vector2i(3840,2160); DisplayServer.window_set_size(root.size)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED); Engine.max_fps=0
	var graphics=root.get_node("GraphicsQuality"); graphics.quality=0; graphics.upscale=0; graphics.apply(); Engine.max_fps=0
	if "--standard" in OS.get_cmdline_user_args(): graphics.quality=1; graphics.apply(); Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	boot_usec=Time.get_ticks_usec()
	screen=Screen.new(); root.add_child(screen); screen.campaign.save_enabled=false
	screen.start("user://benchmark-unused.json"); screen.campaign.state=screen.campaign.new_state()
	screen.set_physics_process(false); screen.set_process(false)
	screen.campaign.enter(1,0)
	await process_frame; await RenderingServer.frame_post_draw
	camp_load_ms=float(Time.get_ticks_usec()-boot_usec)/1000
	var cave_start := Time.get_ticks_usec()
	for door in screen.campaign.map.entrances():
		if door.stage==7:
			screen.campaign.hero_at=door.p; screen.campaign.use_entrance(door); break
	await process_frame; await RenderingServer.frame_post_draw
	cave_load_ms=float(Time.get_ticks_usec()-cave_start)/1000
	print("BENCH_LOAD camp_ms=",camp_load_ms," cave_ms=",cave_load_ms)
	begin_run(); previous_usec=Time.get_ticks_usec()
	process_frame.connect(tick)
func begin_run() -> void:
	combat=run_index>=repeats; run_clock=0; warmup=12; target_index=0; log_clock=0
	samples.clear(); cpu.clear(); gpu.clear()
	var c=screen.campaign
	if screen.modal: screen.close_panel()
	c.state.hp=c.max_hp()
	c.enter(1,1 if combat else 0)
	c.state.hp=c.max_hp()
	if combat:
		c.hero_at=c.map.anchors[0]; c.enemies.clear()
	else:
		var r=c.map.regions[1]
		targets=[Vector2(1100,850),Vector2(1100,1950),r.origin+r.spawn,r.origin+r.anchors[0],r.origin+r.side_anchors[0],r.origin+Vector2(900,2350),r.origin+Vector2(3380,1880),r.origin+Vector2(3380,1000),r.origin+Vector2(3380,1880),r.origin+r.anchors[1],r.origin+r.anchors[2]]
	print("BENCH_START ",run_index," ","combat" if combat else "walk"," output=3840x2160 internal_scale=",root.scaling_3d_scale)
func tick() -> void:
	var now := Time.get_ticks_usec(); var dt := float(now-previous_usec)/1000000; previous_usec=now
	if dt<=0: return
	var c=screen.campaign
	if screen.modal: screen.close_panel()
	c.state.hp=c.max_hp()
	if warmup>0: warmup-=dt
	else:
		run_clock+=dt; samples.append(dt*1000)
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	var movement := Vector2.ZERO
	if combat:
		c.state.hp=c.max_hp()
		c.state.xp=0
		if c.state.defeated.size()>2000: c.state.defeated.clear()
		var living := 0
		for e in c.enemies:
			if e.hp>0: living+=1
		if living<24:
			var point: Vector2=c.hero_at+Vector2(cos(c.clock*2.4),sin(c.clock*2.4))*300
			if c.map.walkable(point):
				spawn_counter+=1; c.spawn_enemy(point,int(c.clock)%4,"benchmark-%d" % spawn_counter)
		if c.enemies.size()>80:
			c.enemies=c.enemies.filter(func(e): return e.hp>0)
		c.attack(Vector2(cos(c.clock),sin(c.clock)),1 if int(c.clock)%8==0 else 0)
	else:
		var target: Vector2=targets[target_index]
		if c.hero_at.distance_to(target)<60:
			target_index+=1
			if target_index>=targets.size(): target_index=0
		movement=c.steer("benchmark",c.hero_at,targets[target_index])
	c.update(minf(dt,.05),movement); screen._process(minf(dt,.05))
	log_clock+=dt
	if log_clock>60: log_clock=0; print("BENCH_PROGRESS ",run_index," seconds=",int(run_clock)," stage=",c.state.stage)
	if run_clock>=seconds:
		finish_run()
		run_index+=1
		if run_index>=repeats*2:
			process_frame.disconnect(tick); screen.queue_free(); call_deferred("finish_all")
		else: begin_run(); previous_usec=Time.get_ticks_usec()
func percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty(): return 0
	var copy := values.duplicate(); copy.sort(); return copy[mini(copy.size()-1,int(copy.size()*fraction))]
func finish_run() -> void:
	var sum := 0.0; var stalls := 0
	for value in samples:
		sum+=value
		if value>50: stalls+=1
	var row := {"run":run_index,"mode":"combat" if combat else "walk","seconds":run_clock,"frames":samples.size(),"mean_ms":sum/maxi(1,samples.size()),"p95_ms":percentile(samples,.95),"p99_ms":percentile(samples,.99),"max_ms":percentile(samples,1),"stalls_over_50ms":stalls,"cpu_p95_ms":percentile(cpu,.95),"gpu_p95_ms":percentile(gpu,.95)}
	results.append(row); print("BENCH_RESULT ",JSON.stringify(row)); write_report()
func write_report() -> void:
	var file := FileAccess.open("res://build/story-4k-benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"output":[3840,2160],"internal_scale":root.scaling_3d_scale,"renderer":RenderingServer.get_current_rendering_method(),"device":RenderingServer.get_video_adapter_name(),"camp_first_load_ms":camp_load_ms,"cave_first_load_ms":cave_load_ms,"runs":results},"\t")); file.close()
func finish_all() -> void:
	write_report(); print("BENCH_DONE"); quit()
