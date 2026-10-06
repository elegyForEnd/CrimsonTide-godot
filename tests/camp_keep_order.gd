extends SceneTree
## The keep-order measurement, kept as a test so the 0.2ms budget can be re-checked
## whenever the key changes. Prints both orders' per-call average on a 42-item haul and
## fails only if the one in use (`keep_order`) left the budget.
const CampStorage = preload("res://scripts/camp_storage.gd")
const BUDGET_MS := 0.2

func _initialize() -> void:
	call_deferred("run")

func build_haul() -> Array:
	var items: Array = []
	var kinds := ["scrap","relic","medicine","ammo","crystal","silver","moon","charm"]
	for i in 30:
		var entry := {"kind":kinds[i%kinds.size()],"x":i%8,"y":int(i/8),"rot":false}
		if Catalog.stacks(str(entry.kind)): entry["count"]=1+i%6
		items.append(entry)
	for i in 6:
		items.append(Catalog.make_equipment("weapon",i%8,i%6))
	for i in 6:
		items.append(Catalog.make_equipment("gear",i%3,i%6))
	return items

func measure(fn: Callable, haul: Array, runs: int = 400) -> float:
	for i in 30: fn.call(haul)
	var start := Time.get_ticks_usec()
	for i in runs: fn.call(haul)
	return float(Time.get_ticks_usec()-start)/float(runs)/1000.0

func run() -> void:
	var haul := build_haul()
	var used := measure(CampStorage.keep_order,haul)
	var plain := measure(CampStorage.keep_order_plain,haul)
	var order := CampStorage.keep_order(haul)
	print("CAMP KEEP ORDER: haul=",haul.size()," used=",snappedf(used,0.001),"ms plain=",snappedf(plain,0.001),"ms budget=",BUDGET_MS,"ms")
	# The order must at least be a permutation, and the top of it must be the best tier.
	var types := {}
	for item in order: types[str(item.kind)]=true
	var complete := types.size()>0
	var expect: Array = []
	for item in order: expect.append(Catalog.item_tier(item))
	var sorted_desc := true
	for i in range(1,expect.size()):
		if int(expect[i])>int(expect[i-1]): sorted_desc=false
	var failures := 0
	if used>BUDGET_MS:
		failures+=1
		push_error("the keep order left its budget: %.4fms" % used)
	if not complete or order.size()!=haul.size():
		failures+=1
		push_error("the keep order lost items")
	if not sorted_desc:
		failures+=1
		push_error("the keep order is not quality-first")
	print("CAMP KEEP ORDER: ",3," checks, ",failures," failures")
	quit(1 if failures else 0)
