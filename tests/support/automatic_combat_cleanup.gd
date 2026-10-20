extends RefCounted

# Tests own these scene instances. AudioServer releases playback on its mixer
# thread, so observe that release before allowing the test process to quit.
static func release(tree: SceneTree, scene: Node, owner: Variant = null) -> void:
	var playback_handles: Array[WeakRef] = []
	if is_instance_valid(scene):
		if scene.has_method("show_menu"):
			scene.show_menu()
		var audio: Node = scene.get_node_or_null("MenuFlow/Audio")
		if audio and audio.transition and audio.transition.is_valid():
			audio.transition.kill()
		for timer: Node in scene.find_children("*", "Timer", true, false):
			timer.stop()
		for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
			if player.has_stream_playback():
				playback_handles.append(weakref(player.get_stream_playback()))
			player.stop()
			player.stream = null
		if is_instance_valid(owner):
			owner.queue_free()
		else:
			scene.queue_free()
		await tree.process_frame
		var deadline: int = Time.get_ticks_msec() + 1000
		while playback_handles.any(func(handle: WeakRef) -> bool: return handle.get_ref() != null) and Time.get_ticks_msec() < deadline:
			await tree.process_frame
		if playback_handles.any(func(handle: WeakRef) -> bool: return handle.get_ref() != null):
			push_error("Audio mixer did not release stopped test playback within 1000ms")
