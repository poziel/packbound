extends RefCounted
## Persistent GPU-drawn trails avoid rebuilding thousands of halo primitives.
const SHADER = preload("res://themes/gameplay/crafting_trail.gdshader")
var nodes: Dictionary = {}

func draw(board: CanvasItem, flows: Dictionary, clock: float) -> void:
	var active: Dictionary = {}
	for key: String in flows:
		var flow: Dictionary = flows[key]
		var opacity: float = smoothstep(0.0, 1.0, clampf(float(flow["alpha"]), 0.0, 1.0))
		for reverse in range(2):
			var id: String = key + ":" + str(reverse)
			var start: Vector2 = flow["start"] if reverse == 0 else flow["finish"]
			var end: Vector2 = flow["finish"] if reverse == 0 else flow["start"]
			var distance: Vector2 = end - start
			if distance.length() < 2.0 or opacity <= 0.0: continue
			active[id] = true
			if not nodes.has(id):
				var fresh := Polygon2D.new()
				fresh.name = "CraftingTrail"
				fresh.material = ShaderMaterial.new()
				fresh.material.shader = SHADER
				board.add_child(fresh)
				nodes[id] = fresh
			var quad: Polygon2D = nodes[id]
			# Reward hints cross the chooser overlay, below interactive tooltips (100).
			quad.z_as_relative = not bool(flow.get("reward", false))
			quad.z_index = 90 if flow.get("reward", false) else 0
			var length: float = minf(BackpackBoard.CELL - 8.0, distance.length() * 0.5)
			quad.position = start
			quad.rotation = distance.angle()
			if not is_equal_approx(float(quad.get_meta("length", -1)), length):
				quad.polygon = PackedVector2Array([Vector2(-6, -20), Vector2(length + 6, -20), Vector2(length + 6, 20), Vector2(-6, 20)])
				quad.set_meta("length", length)
				quad.material.set_shader_parameter("trail_length", length)
			quad.material.set_shader_parameter("clock", clock)
			quad.material.set_shader_parameter("tint", flow["tint"])
			quad.material.set_shader_parameter("strength", flow["strength"])
			quad.material.set_shader_parameter("opacity", opacity)
	for id: String in nodes.keys():
		if not active.has(id):
			var node: Polygon2D = nodes[id]
			node.get_parent().remove_child(node)
			node.queue_free()
			nodes.erase(id)
