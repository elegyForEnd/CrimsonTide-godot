extends SceneTree
const Art=preload("res://scripts/scarlet/art.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app=load("res://scenes/main.tscn").instantiate(); root.add_child(app)
	app.show_title()
	var title_entry:=false
	for n in app.page.get_children():
		if n is Button and n.text.contains("赤月遗书"): title_entry=true
	check(title_entry,"normal title exposes the rebuilt campaign")
	app.go_story("user://scarlet-integration-%d.scarlet.json" % OS.get_process_id())
	var s=app.story_screen; var c=s.campaign
	c.save_enabled=false
	check(s.active and app.page_name=="story","normal main entry uses Scarlet")
	check(s.world.original.get_script()==load("res://scripts/story_world.gd"),"the unchanged original StoryWorld renders the new story")
	check(s.world.view_camera==s.world.original.view_camera and s.world.zoom==15.0,"original camera and default zoom are restored")
	check(s.world.view_camera.environment!=null,"original camera environment is retained")
	check(s.world.original.hero_frames.get_script()==load("res://scripts/character_frames.gd"),"original hero animation frames are retained")
	check(s.world.combat_fx.get_script()==load("res://scripts/story_combat_vfx.gd"),"original combat VFX are retained")
	check(not app.session.running and not app.field.visible and not app.rogue_field.visible,"other simulations stay outside story mode")
	for i in 3: await process_frame
	check(s.modal and is_instance_valid(s.dialogue) and c.state.pending.id=="CIN-00","opening cinematic starts before action HUD")
	var attempts:=0
	while c.current_main().id=="R-P01" and attempts<12:
		attempts+=1
		for frame in 2: await process_frame
		if not is_instance_valid(s.dialogue): continue
		if not c.state.pending.get("choices",[]).is_empty():
			s.dialogue.skip_scene()
			check(s.dialogue.choosing,"skip stops at opening choice")
			s.dialogue.actions.get_child(0).pressed.emit()
		else: s.dialogue.skip_scene()
	check(c.current_main().id=="R-P02","actual ADV buttons advance into playable prologue")
	check(c.state.facts.has("royal_letter") and c.state.facts.has("pursuit_order"),"opening evidence is in the real clue bag")
	check("cg-01a" in c.state.gallery and "cg-01b" in c.state.gallery,"both letter CG states unlock")
	check(c.state.choices.opening_reply=="carry","choice button stores the selected response")
	var before: Array=c.state.completed.duplicate()
	s.show_journal(); check(s.modal,"new journal pauses action")
	s.close_panel(); s.show_items()
	var original_items: Control=s.overlay.get_child(s.overlay.get_child_count()-1)
	check(original_items.get_script()==load("res://scripts/story_items_ui.gd") and original_items.atlas!=null,"original inventory grid and art are restored")
	s.close_panel(); s.show_items("character"); check(s.modal,"original character and specialty UI opens")
	s.close_panel(); s.show_items("stash"); check(s.modal,"original stash UI opens")
	s.close_panel(); s.show_items("shop"); check(s.modal,"original shop UI opens")
	s.close_panel(); s.show_items("forge"); check(s.modal,"original forge UI opens")
	s.close_panel(); s.show_evidence(); check(s.modal,"new evidence bag is accessible")
	s.close_panel(); s.show_party(); check(s.modal,"party interface supports the new campaign")
	s.close_panel()
	var e: Dictionary=c.content.scenes.conditions.duplicate(true); e.kind="scene"; e.page=0
	s.play_replay(e)
	check(s.dialogue.backdrop.texture!=null,"ADV has dedicated illustrated backgrounds")
	s.dialogue.index=2; s.dialogue.show_page()
	check(s.dialogue.expressions.yayu=="neutral","authored actor expression is used")
	s.dialogue.skip_scene()
	check(c.state.completed==before,"gallery replay cannot submit a task")
	check(Art.portrait("feiyue","angry")!=Art.portrait("feiyue","sad"),"emotion changes select different whole portraits")
	for key in ["inquisitor","judge","vein","surgeon","admiral","physician","captain","messenger","craftsman","stablemaster","village-doctor"]:
		check(Art.portrait(key)!=null,"generated NPC is integrated: "+key)
	app.show_title(); check(not s.active and not s.world.visible,"leaving story hides its own world")
	app.go_camp(); check(app.page_name=="ground" and not s.active,"other modes remain accessible")
	app.queue_free(); await process_frame
	print("SCARLET_INTEGRATION %d checks, %d failures" % [checks,failures]); quit(1 if failures else 0)
