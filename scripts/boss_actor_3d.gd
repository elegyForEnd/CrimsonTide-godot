extends Node3D
## Presentation only. The existing authoritative enemy dictionary settles hits.
const MODEL := preload("res://assets/bosses/3d/oath-knight/oath-knight.glb")
const Design := preload("res://scripts/boss_attack_design.gd")
var model: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var clips: Dictionary={}
var meshes: Array[MeshInstance3D]=[]
var soul_materials: Array[StandardMaterial3D]=[]
var weapon_trail: MeshInstance3D
var trail_material: StandardMaterial3D
var trail_samples: Array=[]
var phase_light: OmniLight3D
var state_name := ""
var sample_time := 0.0
var previous_at := Vector2.INF
var previous_phase := 1
var age := 0.0
var phase_age := 100.0
var death_age := -1.0
var obsidian := false
var previous_flash := 0.0
var hit_age := 100.0
var last_slash := false
var target_scale := .68
var weapon_bone := -1
var model_ok := false

static func supports(e: Dictionary, mode: String = "expedition") -> bool:
	# Work in progress: keep the procedural comparison sample out of released play.
	if OS.get_environment("CRIMSON_BOSS3D_PREVIEW")!="1": return false
	if e.get("boss_construct",false) or e.get("rogue_mirror",false): return false
	if str(e.get("model_3d",""))=="oath-knight": return true
	if mode=="rogue": return e.get("rogue_guardian",false) and int(e.get("boss_art",-1))==4
	if mode=="story": return not e.get("boss",false) and int(e.get("type",-1))==4
	return int(e.get("type",-1))==4 and not e.get("raid_boss",false) and not e.get("mini_boss",false)

func _ready() -> void:
	model=MODEL.instantiate(); add_child(model)
	_find_nodes(model)
	if skeleton==null or player==null: push_error("Oath knight missing skeleton/animations"); return
	for key in player.get_animation_list(): clips[str(key).get_file().to_lower()]=key
	# Exported animations may have Armature| prefix rather than NLA track names.
	for key in player.get_animation_list():
		for wanted in ["idle","walk","charge","slash","sweep","thrust","slam","guard","hit","break","phase","cast","entrance","death","corpse"]:
			if str(key).to_lower().ends_with(wanted): clips[wanted]=key
	weapon_bone=skeleton.find_bone("hand.R")
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var material: StandardMaterial3D=original.duplicate()
				material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				mesh.set_surface_override_material(surface,material)
				if original.resource_name.to_lower().contains("soul"): soul_materials.append(material)
	trail_material=StandardMaterial3D.new(); trail_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	trail_material.cull_mode=BaseMaterial3D.CULL_DISABLED; trail_material.vertex_color_use_as_albedo=true
	trail_material.albedo_color=Color(.3,.68,.9,.72)
	weapon_trail=MeshInstance3D.new(); weapon_trail.material_override=trail_material
	weapon_trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(weapon_trail)
	phase_light=OmniLight3D.new(); phase_light.position=Vector3(0,1.4,0)
	phase_light.omni_range=2.6; phase_light.shadow_enabled=false
	phase_light.light_bake_mode=Light3D.BAKE_DISABLED; phase_light.light_color=Color("76cced"); add_child(phase_light)
	model_ok=clips.has("idle") and clips.has("death") and weapon_bone>=0
	if not model_ok: push_error("Oath knight invalid clip names/bone: "+str(clips.keys())+" hand="+str(weapon_bone))
	model.scale=Vector3.ONE*target_scale

func _find_nodes(node: Node) -> void:
	if node is Skeleton3D: skeleton=node
	if node is AnimationPlayer: player=node
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): _find_nodes(child)

func set_variant(black_knight: bool) -> void:
	obsidian=black_knight
	if not model_ok: return
	trail_material.albedo_color=Color(.65,.30,.92,.7) if obsidian else Color(.3,.68,.9,.72)
	phase_light.light_color=Color("b889e9") if obsidian else Color("76cced")
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			if material is StandardMaterial3D and material.resource_name.to_lower().contains("steel"):
				material.albedo_color=Color("63536e") if obsidian else Color.WHITE

static func attack_sample(e: Dictionary, story: bool) -> Dictionary:
	var move := str(e.get("move_id",e.get("move_name",""))).to_lower()
	var clip := "thrust" if "thrust" in move or "刺" in move or "dash" in move else "sweep" if "storm" in move or "圈" in move else "slash"
	if e.get("rogue_guardian",false):
		clip=["slash","thrust","cast","cast","sweep","thrust","cast"][clampi(int(e.get("boss_skill",0)),0,6)]
	if story:
		clip={"circle":"slam","ring":"sweep","cross":"cast"}.get(str(e.get("shape","circle")),"slam")
		var remaining := float(e.get("windup",0))
		var total := maxf(.01,float(e.get("visual_attack_total",1.15)))
		return {"clip":clip,"before":remaining>0,"until":remaining,"charge":clampf(1-remaining/total,0,1),"after":.48-float(e.get("visual_release_time",.48))}
	var beat := Design.beat(e)
	var until := float(beat.impact)-float(beat.elapsed)
	return {"clip":clip,"before":until>0,"until":maxf(0,until),"charge":clampf((float(beat.elapsed)-float(beat.start))/maxf(.01,float(beat.impact)-float(beat.start)),0,1),"after":maxf(0,-until)}

func sync(e: Dictionary, dt: float, clock: float, story: bool = false) -> void:
	if not model_ok: return
	age+=dt; phase_age+=dt; hit_age+=dt
	model.scale=Vector3.ONE*target_scale
	var at: Vector2=e.p
	var moving := previous_at!=Vector2.INF and at.distance_to(previous_at)>dt*4.0
	var travel := Vector2.ZERO if previous_at==Vector2.INF else at-previous_at
	previous_at=at
	var current_phase := int(e.get("phase",1))
	if current_phase>previous_phase and age>.1: phase_age=0
	previous_phase=current_phase
	var flash := float(e.get("flash",0))
	if flash>previous_flash+.02: hit_age=0
	previous_flash=flash
	var aim: Vector2=e.get("attack_aim",e.get("guard_aim",Vector2.ZERO))
	if story and float(e.get("windup",0))>0: aim=Vector2(e.get("target",at))-at
	if aim.length_squared()<.001: aim=travel if moving else Vector2(float(e.get("facing",1)),.35)
	var turn := atan2(-aim.x,-aim.y)
	rotation.y=lerp_angle(rotation.y,turn,1-exp(-dt*16)) if dt>0 else turn
	var clip := "idle"; var t := fmod(clock,2.0); var active_slash := false
	if float(e.get("hp",1))<=0:
		if death_age<0: death_age=0
		death_age+=dt; clip="death"; t=minf(2,death_age)
	elif float(e.get("stagger",0))>0:
		clip="break"; t=minf(1.4,age-hit_age) if hit_age<1.4 else .45
	elif float(e.get("guard_time",0))>0:
		clip="guard"; t=clampf(1.12-float(e.guard_time),0,.95)
	elif ((float(e.get("windup",0))>0 or float(e.get("visual_release_time",0))>0) if story else float(e.get("attack_time",0))>0):
		var sample := attack_sample(e,story)
		if sample.before and float(sample.until)>.14:
			clip="charge"; t=float(sample.charge)
		else:
			clip=sample.clip
			var contact: float={"slash":8.0/30,"sweep":8.0/30,"thrust":7.0/30,"slam":10.0/30,"cast":13.0/30}.get(clip,8.0/30)
			t=maxf(0,float(contact)*(1-float(sample.until)/.14)) if sample.before else float(contact)+float(sample.after)*1.4
			active_slash=clip in ["slash","sweep","thrust","slam"] and (not sample.before or float(sample.until)<.10) and float(sample.after)<.28
	elif phase_age<1.25: clip="phase"; t=phase_age*1.25
	elif hit_age<.44: clip="hit"; t=hit_age
	elif age<1.0: clip="entrance"; t=age*2
	elif moving or e.get("moving",false): clip="walk"; t=fmod(clock,32.0/30)
	if clips.has(clip):
		state_name=clip; sample_time=t
		player.play(clips[clip]); player.seek(minf(t,player.get_animation(clips[clip]).length),true); player.advance(0)
	for material in soul_materials:
		material.emission=Color("b080ee") if obsidian else Color("71c9ed")
		material.emission_energy_multiplier=1.6 if current_phase>=2 else .65
	phase_light.light_energy=(.7 if current_phase>=2 else .12)+maxf(0,1-phase_age/1.0)*1.2
	_update_trail(dt,active_slash)
	last_slash=active_slash

func blade_points() -> Array[Vector3]:
	if weapon_bone<0: return []
	var pose := skeleton.global_transform*skeleton.get_bone_global_pose(weapon_bone)
	# Bone rest-local positions derived from the authored Blender wrist and blade.
	var rest := skeleton.get_bone_global_rest(weapon_bone)
	var tip := Vector3(.97,-.20,.19) # glTF converts (x,y,z) -> (x,z,-y).
	var base := Vector3(.97,1.12,.19)
	return [to_local(pose*(rest.affine_inverse()*tip)),to_local(pose*(rest.affine_inverse()*base))]

func _update_trail(dt: float, active: bool) -> void:
	for sample in trail_samples: sample.age+=dt
	trail_samples=trail_samples.filter(func(sample): return sample.age<.13)
	if active:
		var pts := blade_points()
		if pts.size()==2: trail_samples.append({"tip":global_transform*pts[0],"base":global_transform*pts[1],"age":0.0})
	if trail_samples.size()>9: trail_samples.pop_front()
	weapon_trail.visible=trail_samples.size()>1
	if not weapon_trail.visible: return
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,trail_samples.size()):
		var a: Dictionary=trail_samples[i-1]; var b: Dictionary=trail_samples[i]
		for point in [a.tip,a.base,b.tip,b.tip,a.base,b.base]:
			var local := to_local(point)
			st.set_color(Color(1,1,1,clampf(1-float(a.age)/.13,0,1)*.55)); st.add_vertex(local)
	weapon_trail.mesh=st.commit()

func clear_trail() -> void:
	trail_samples.clear()
	if weapon_trail: weapon_trail.visible=false; weapon_trail.mesh=null
