extends RefCounted
## AudioServer releases decoding handles on its mixer thread after stop().

static func stop_players(owner: Node) -> Array[WeakRef]:
	var handles: Array[WeakRef] = []
	for kind: String in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player: Node in owner.find_children("*", kind, true, false):
			if player.has_stream_playback():
				handles.append(weakref(player.get_stream_playback()))
			player.stop()
			player.stream = null
	return handles

static func wait_for_release(tree: SceneTree, handles: Array[WeakRef]) -> bool:
	var deadline: int = Time.get_ticks_msec() + 1000
	while handles.any(func(handle: WeakRef) -> bool: return handle.get_ref() != null):
		if Time.get_ticks_msec() >= deadline:
			push_error("Audio mixer did not release stopped playback within 1000ms")
			return false
		await tree.process_frame
	return true
