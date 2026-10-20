extends RefCounted
## Presentation descriptors only. Spread is an internal fill factor, never hit reach.
## Flow is texture travel per effect life; shear is signed and UV-local.
const CAMPAIGN_MAP := [624,600,612,636,637,638,639,640,641,642,643,644,601,602,613,614,625,17,18,19,20]
const DENSITIES := ["density_sweep_v1","density_flame_v1","density_dust_v1","density_wisp_v1"]
# name, material, motion, density, smoke, flow, shear, spread,
# attack style, impact style, lead, peak, tail, layers, edge, compression, fragments, decay.
# Rows are explicit: similar weapons differ in timing and material response, not hue.
const ROWS := {
	600:["绯红单手剑","blood","sweep",0,.18,.58,.22,.72,"viscous_cut","blood_tear",.045,.16,.42,2,.82,.38,3,.19],
	601:["鸦喙刺剑","metal","thrust",0,.05,.94,.04,.24,"beak_pierce","needle_puncture",.025,.10,.23,1,.95,.20,2,.12],
	602:["回环弯刀","cloth","spin",0,.16,.71,-.31,.64,"folded_silk","silk_split",.05,.18,.40,2,.72,.30,3,.22],
	603:["血棘双刃","blood","sweep",0,.12,.76,-.24,.55,"paired_thorn","thorn_snap",.03,.12,.31,2,.90,.42,4,.16],
	604:["银月细剑","metal","sweep",0,.03,1.08,.12,.28,"silver_reflection","silver_chip",.025,.09,.25,2,.96,.18,2,.13],
	605:["烛影短刀","cloth","thrust",1,.24,.64,.33,.36,"wick_membrane","wax_shear",.035,.12,.38,1,.70,.24,2,.18],
	606:["星霜佩剑","frost","sweep",0,.10,.53,-.18,.52,"thin_ice_plane","flake_cleave",.045,.14,.29,2,.91,.44,4,.17],
	607:["鸣电军刀","storm","sweep",0,.02,1.32,.27,.40,"late_arc_cut","arc_disconnect",.025,.07,.15,2,.98,.26,2,.08],
	608:["断誓直剑","cloth","sweep",2,.14,.42,-.12,.49,"broken_seal","wax_fracture",.055,.17,.37,2,.78,.48,3,.23],
	609:["镜花曲剑","mirror","sweep",0,.06,.61,-.46,.58,"offset_mirrors","mirror_flip",.04,.11,.34,3,.94,.31,4,.18],
	610:["葬铃仪剑","bell","sweep",3,.19,.36,.16,.44,"bronze_vibration","chime_chip",.06,.12,.46,2,.75,.29,2,.26],
	611:["黑曜戒律剑","void","sweep",2,.08,.31,-.28,.62,"obsidian_wedge","hard_shell_break",.065,.18,.27,1,.93,.74,4,.15],
	612:["破晓双手剑","sun","chop",2,.32,.48,.20,.84,"sunsteel_drop","slab_uplift",.09,.20,.53,2,.86,.86,5,.30],
	613:["断潮巨刃","tide","wave",0,.28,.82,.47,.88,"heavy_water_sheet","water_slab_break",.10,.24,.57,2,.76,.81,4,.34],
	614:["裂地重剑","stone","spin",2,.39,.39,-.37,.85,"broken_earth_ridge","layered_fault",.11,.25,.62,3,.65,.92,5,.38],
	615:["熔炉巨锤","stone","chop",1,.44,.33,.09,.78,"molten_hammer","slag_squeeze",.13,.22,.64,2,.73,.96,4,.41],
	616:["霜骨战斧","frost","chop",2,.25,.44,-.33,.80,"thick_bone_ice","bone_ice_crush",.115,.20,.45,2,.89,.90,5,.25],
	617:["雷骸重剑","storm","chop",2,.17,.92,.38,.76,"weighted_late_thunder","thunder_fault",.105,.16,.33,2,.97,.88,3,.17],
	618:["血狱斩首刃","blood","chop",0,.21,.46,.51,.82,"falling_blood_membrane","execution_tear",.12,.23,.49,2,.85,.94,4,.28],
	619:["星陨石槌","stone","chop",2,.36,.27,-.08,.79,"starrock_drop","crystal_slab_crush",.14,.21,.61,3,.81,.99,5,.37],
	620:["余烬壁刃","stone","chop",2,.43,.35,.29,.86,"charcoal_wall_shear","char_shell_peel",.11,.25,.59,2,.68,.89,4,.35],
	621:["风暴战戟","cloth","sweep",3,.15,1.14,-.43,.47,"folded_wind_banner","banner_rip",.075,.15,.36,2,.80,.52,3,.20],
	622:["冥潮仪镰","soul","hook",3,.31,.52,-.58,.71,"soul_inner_hook","soul_peel",.085,.19,.60,3,.71,.47,3,.32],
	623:["无名王剑","metal","chop",2,.24,.29,.14,.81,"old_crown_steel","crown_plate_break",.125,.22,.47,2,.88,.95,4,.29],
	624:["守夜步枪","metal","recoil",2,.19,1.45,.02,.26,"rifle_gas_kick","bullet_hard_point",.01,.05,.20,1,.94,.61,2,.10],
	625:["暮羽长弓","feather","recoil",3,.07,1.03,-.11,.31,"long_feather_release","feather_puncture",.035,.08,.28,2,.86,.34,2,.16],
	626:["血棘连弩","blood","recoil",0,.06,1.19,.18,.23,"barbed_bolt_release","barb_catch",.02,.065,.24,1,.93,.45,3,.14],
	627:["烬鸦火铳","cloth","recoil",1,.38,.81,.32,.43,"blunt_hot_pellet","burning_shell_split",.015,.075,.39,2,.75,.62,3,.25],
	628:["霜月猎弓","frost","recoil",0,.08,1.06,-.21,.29,"frost_shaft_release","ice_shaft_split",.04,.09,.26,2,.92,.40,3,.15],
	629:["雷翼卡宾枪","storm","recoil",0,.04,1.52,.23,.25,"charged_short_core","side_arc_snap",.012,.045,.16,2,.99,.48,2,.09],
	630:["黑曜长枪","void","recoil",2,.11,1.28,-.05,.20,"heavy_obsidian_core","dark_core_crack",.025,.065,.22,1,.97,.79,3,.13],
	631:["镜轨双铳","mirror","recoil",0,.05,1.16,-.34,.34,"offset_twin_muzzles","reflector_shatter",.018,.06,.27,2,.95,.43,4,.17],
	632:["逐风短弓","feather","recoil",3,.09,1.38,.35,.30,"light_feather_flick","light_air_slice",.022,.07,.21,2,.82,.27,2,.12],
	633:["断誓穿甲枪","metal","recoil",2,.13,1.57,-.13,.19,"sabot_core_release","armor_shell_shear",.016,.055,.23,2,.98,.83,4,.14],
	634:["葬铃灵弩","bell","recoil",3,.16,.89,.08,.27,"bronze_vane_release","vane_vibration",.032,.085,.37,2,.84,.36,2,.22],
	635:["晨曦信号枪","sun","recoil",1,.35,.73,-.19,.38,"warm_signal_puff","signal_core_break",.014,.08,.43,2,.78,.51,3,.27],
	636:["星辉法杖","star","cast",2,.13,.68,.17,.46,"star_grit_compress","star_core_split",.055,.13,.36,3,.88,.41,4,.21],
	637:["赤陨法杖","stone","cast",1,.46,.47,.41,.83,"molten_rock_birth","meteor_shell_crush",.11,.24,.63,3,.77,.93,5,.40],
	638:["霜针短杖","frost","cast",0,.04,1.22,-.09,.22,"ice_needle_freeze","axial_needle_split",.025,.075,.20,2,.97,.32,3,.12],
	639:["鸣雷之杖","storm","cast",0,.03,1.61,.49,.53,"intermittent_charge","branch_disconnect",.06,.06,.14,3,.99,.55,3,.08],
	640:["月弧法杖","metal","cast",0,.06,.77,-.41,.57,"moon_plane_flip","moon_edge_flake",.07,.12,.31,2,.96,.28,3,.17],
	641:["曦光棱镜杖","sun","beam",0,.02,.97,.05,.35,"prism_alignment","prism_facet_crack",.08,.09,.24,3,.99,.46,4,.14],
	642:["烬羽散华杖","feather","cast",1,.29,.88,-.27,.60,"charred_feather_birth","feather_branch_break",.05,.14,.45,3,.79,.37,4,.28],
	643:["虚涡法杖","void","cast",3,.42,-.69,-.63,.82,"asymmetric_space_fold","inward_fold_collapse",.10,.19,.58,3,.64,.71,3,.34],
	644:["蚀月长枪杖","void","thrust",3,.22,1.11,.26,.32,"dark_shell_compress","eclipse_shell_peel",.12,.17,.39,2,.91,.77,3,.22],
	645:["血契仪杖","blood","cast",0,.20,.41,-.36,.65,"ink_page_fold","ink_fiber_tear",.075,.18,.51,3,.74,.49,4,.30],
	646:["冥庭唤魂杖","soul","cast",3,.37,.57,-.52,.69,"layered_soul_cloth","soul_cloth_pin",.09,.16,.63,3,.69,.33,3,.36],
	647:["晨钟祈愿杖","bell","cast",3,.27,.38,.31,.73,"warm_prayer_fold","prayer_cloth_press",.085,.15,.55,3,.72,.39,3,.32],
	17:["黑铁短剑","metal","sweep",0,.04,.84,-.07,.32,"short_iron_cut","iron_tip_chip",.035,.12,.26,1,.87,.35,2,.15],
	18:["祭祀短杖","star","cast",3,.18,.45,.13,.41,"small_prayer_star","prayer_star_flake",.07,.15,.43,2,.76,.25,2,.26],
	19:["破碎大剑","metal","chop",2,.29,.32,-.23,.70,"broken_steel_drop","broken_tip_crush",.12,.24,.50,2,.79,.85,4,.31],
	20:["湮魂之镰","soul","hook",3,.33,.49,-.55,.63,"small_soul_hook","hooked_soul_tear",.08,.17,.56,2,.73,.37,3,.31]
}

# Authored silhouette vocabulary: motif, repetition, opening, longitudinal bias.
# Each row is paired with the weapon's existing material, timing and attack style.
const SIGNATURES := {
 600:["blood_fang",3,.38,.12],601:["beak",1,.16,.88],602:["silk",3,.72,.28],603:["thorn",4,.42,.35],
 604:["moon",1,.64,.50],605:["wick",2,.26,.16],606:["ice",5,.48,.32],607:["lightning",3,.32,.72],
 608:["seal",3,.54,.22],609:["mirror",3,.62,.46],610:["chime",4,.38,.24],611:["obsidian",2,.74,.58],
 612:["sunray",5,.66,.52],613:["water",3,.88,.34],614:["fault",5,.78,.42],615:["slag",4,.72,.18],
 616:["ice",3,.76,.62],617:["lightning",5,.68,.42],618:["blood_fang",2,.84,.72],619:["meteor",6,.64,.30],
 620:["slag",3,.88,.62],621:["silk",4,.82,.72],622:["soul",3,.78,.48],623:["crown",5,.58,.68],
 624:["sabot",2,.18,.82],625:["feather",3,.44,.62],626:["thorn",3,.22,.80],627:["wick",4,.58,.36],
 628:["ice",2,.32,.84],629:["lightning",2,.24,.94],630:["obsidian",1,.34,.96],631:["mirror",2,.58,.74],
 632:["feather",2,.62,.88],633:["sabot",3,.26,.96],634:["chime",3,.42,.82],635:["sunray",4,.68,.24],
 636:["star",5,.58,.38],637:["meteor",4,.86,.46],638:["ice",4,.18,.98],639:["lightning",6,.82,.58],
 640:["moon",3,.86,.48],641:["prism",3,.42,.94],642:["feather",6,.76,.32],643:["void",4,.94,.22],
 644:["obsidian",3,.28,.92],645:["seal",4,.78,.36],646:["soul",5,.84,.32],647:["chime",6,.74,.18],
 17:["sabot",1,.24,.48],18:["star",3,.36,.22],19:["seal",2,.62,.64],20:["soul",2,.68,.52]
}

static func role_motion(role: String, fallback: String) -> String:
	if role in ["motion_thrust","projectile_arrow","projectile_bullet","projectile_needle","projectile_eclipse"]: return "thrust"
	if role in ["motion_spin","motion_heavy_spin"]: return "spin"
	if role=="motion_heavy_slash" and fallback=="wave": return "wave"
	if role in ["motion_quake","motion_heavy_overhead","motion_heavy_slash","motion_hammer_spin"]: return "chop"
	if role=="motion_scythe" or role=="projectile_moon": return "hook"
	if role in ["motion_slash","motion_double_slash","motion_narrow_sweep"]: return "sweep"
	if role in ["muzzle_fire","release_bow"]: return "recoil"
	if role.begins_with("beam_"): return "beam"
	if role.begins_with("burst_"): return "wave"
	if role.begins_with("cast_"): return "cast"
	return fallback

static func profile(index: int, role: String="") -> Dictionary:
	var identity: int=index if ROWS.has(index) else CAMPAIGN_MAP[clampi(index,0,20)]
	var row: Array=ROWS[identity]
	var result := {"index":index,"canonical":identity,"name":row[0],"material":row[1],"motion":row[2],
		"density_source":DENSITIES[int(row[3])],"smoke_gain":row[4],"flow":row[5],"shear":row[6],"spread":row[7],"role":role,
		"attack":{"style":row[8],"lead":row[10],"peak":row[11],"tail":row[12],"layers":row[13],"edge":row[14]},
		"impact":{"style":row[9],"compression":row[15],"fragments":row[16],"decay":row[17]}}
	var signature: Array=SIGNATURES[identity]
	result["signature"]={"motif":signature[0],"count":signature[1],"opening":signature[2],"bias":signature[3]}
	result["family"]="blade" if identity==17 or identity in range(600,612) else "great" if identity in [19,20] or identity in range(612,624) else "ranged" if identity in range(624,636) else "magic"
	result["ground_break"]=identity in [614,615,619,620]
	var motif := str(result.signature.motif)
	var smoke_type: String= "dust" if bool(result.ground_break) else {"frost":"cold","blood":"blood","soul":"soul","void":"void","feather":"wind","cloth":"wind","storm":"ion","bell":"incense","sun":"heat","stone":"heat","star":"ion"}.get(str(result.material),"wind")
	if motif=="wick": smoke_type="heat"
	result["smoke_type"]=smoke_type
	result["smoke_source"]="density_"+smoke_type+"_v3"
	# Continuous flow maps are authored separately from isolated smoke silhouettes.
	result["ribbon_source"]=DENSITIES[int(row[3])]
	result["ribbon_vertical"]=int(row[3])==1
	result["ribbon_repeat"]=1.05 if result.family in ["blade","great"] else 1.65
	result["blade_source"]="weapon_%d_surface_v5" % identity
	result["smoke_vertical"]=smoke_type in ["heat","soul","incense"]
	result.density_source={"dust":"density_dust_v1","cold":"density_sweep_v1","blood":"density_flame_v1","soul":"density_wisp_v1","void":"density_wisp_v1","wind":"density_sweep_v1","ion":"density_wisp_v1","incense":"density_wisp_v1","heat":"density_flame_v1"}[smoke_type]
	result.motion=role_motion(role,str(result.motion))
	if role=="motion_quake":
		result.smoke_source="density_dust_v3"
		result.smoke_type="dust"
		result.density_source="density_dust_v1"
		result.ribbon_source="density_dust_v1"
		result.ribbon_vertical=false
		result.smoke_vertical=false
		result.smoke_gain=maxf(.34,float(result.smoke_gain))
		result.flow=.36
		result.shear=.12
		result.attack.style="ground_fault_slam"
		result.impact.style="sunlit_fault" if identity==612 else "earth_slab_fault"
		result.impact.compression=.94
		result.spread=minf(.88,float(result.spread))
	return result.duplicate(true)

static func action_of(data: Dictionary) -> String:
	var context: Dictionary=data.get("build_context",{})
	if bool(data.get("charged",context.get("charged",false))): return "heavy"
	var explicit := str(data.get("vfx_action",context.get("vfx_action","")))
	if explicit in ["normal","heavy","art"]: return explicit
	if data.has("attack_kind") or data.has("art") or str(context.get("kind",""))=="art": return "art"
	return "normal"

static func action_profile(index: int,role: String,action: String) -> Dictionary:
	var result := profile(index,role)
	result["action"]=action
	# The event still owns reach/kind. These are only local release silhouettes.
	result["design"]="contact_cut" if action=="normal" else "stored_impact" if action=="heavy" else "signature_release"
	if role not in ["motion_quake","motion_spin","motion_heavy_spin"] and not role.begins_with("beam_") and not role.begins_with("burst_"):
		if result.family=="great" and result.motion not in ["hook","wave"]:
			result.motion="sweep" if action=="normal" else "chop" if action=="heavy" else "crosscut"
		elif result.family=="blade" and action=="art" and result.motion!="thrust": result.motion="crosscut"
		elif result.family=="magic" and result.motion=="cast":
			result.motion="thrust" if action=="heavy" else "weave" if action=="art" else "cast"
	if action=="normal":
		result.attack.peak*=.70; result.attack.tail*=.66
		result.attack.layers=2 if int(result.canonical) in [603,609,626,631] else 1; result.smoke_gain*=.60
		result.impact.fragments=maxi(2,int(result.impact.fragments)-1)
	elif action=="heavy":
		result.attack.peak*=1.22; result.attack.tail*=1.10
		result.attack.layers=2; result.flow*=.72
		result.spread=minf(1,float(result.spread)*1.15)
		result.smoke_gain=minf(.58,float(result.smoke_gain)*1.35)
		result.impact.fragments=mini(7,int(result.impact.fragments)+2)
		result.impact.compression=minf(1,float(result.impact.compression)+.15)
	else:
		result.attack.layers=3; result.attack.tail*=1.18
		result.flow*=1.18; result.shear*=1.35
		result.impact.fragments=mini(7,int(result.impact.fragments)+1)
	return result

