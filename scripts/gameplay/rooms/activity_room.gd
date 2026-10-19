extends "res://scripts/gameplay/room_definition.gd"
## Physical activities share the existing room travel and camera ownership.

var elapsed: float = 0.0
var retired: bool = false
var retiring: bool = false
var offered: Array[String] = []
var glow_tween: Tween

func configure_activity(run: PackRun) -> void:
	if has_node("Pedestals"):
		if run.phase == PackRun.Phase.ROOM_COMPLETE:
			if not retiring:
				$Pedestals.hide()
			retired = true
			return
		$Pedestals.visible = run.room_reward_pending
		offered.assign(run.room_relic_offers)
		for index in range(3):
			var pedestal: Node3D = $Pedestals.get_child(index)
			pedestal.visible = index < offered.size()
			if pedestal.visible:
				pedestal.get_node("Relic").texture = PackArt.relic(offered[index])

func activity_position(id: String) -> Vector3:
	if id.begins_with("relic:"):
		var index: int = offered.find(id.trim_prefix("relic:"))
		return $Pedestals.get_child(maxi(0, index)).to_global(Vector3(0, 1.5, 0))
	if has_node("FireBowl"):
		return $FireBowl.global_position + Vector3(0, 0.65, 0)
	return $Table.global_position + Vector3(0, 0.5, 0)

func highlight_activity(id: String) -> void:
	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
	glow_tween = create_tween().set_parallel(true)
	if has_node("Pedestals"):
		for index in range(3):
			var selected: bool = index < offered.size() and id == "relic:" + offered[index]
			glow_tween.tween_property($Pedestals.get_child(index).get_node("Glow"), "light_energy", 3.0 if selected else 0.15, 0.2)
	if has_node("ActivityGlow"):
		glow_tween.tween_property($ActivityGlow, "light_energy", 3.0 if not id.is_empty() else 0.6, 0.2)

func retire_activity() -> void:
	if not has_node("Pedestals") or retiring or retired:
		return
	if not $Pedestals.visible:
		return
	retiring = true
	# All offered relics vanish; their stone supports retract before travel unlocks.
	for pedestal: Node3D in $Pedestals.get_children():
		pedestal.get_node("Relic").hide()
	highlight_activity("")
	var tween: Tween = create_tween().set_parallel(true)
	for pedestal: Node3D in $Pedestals.get_children():
		tween.tween_property(pedestal, "position:y", -2.0, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	$Pedestals.hide()
	retired = true
	retiring = false

func _process(delta: float) -> void:
	elapsed += delta
	if has_node("Pedestals") and not retired:
		for index in range(3):
			$Pedestals.get_child(index).get_node("Relic").position.y = 2.35 + sin(elapsed * 1.8 + index * 0.9) * 0.09
	if has_node("Flame"):
		$Flame.scale = Vector3.ONE * (1.0 + sin(elapsed * 7.0) * 0.06)
