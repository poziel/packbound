extends RefCounted

# Tests own these scene instances. Stop the mixer before freeing the scene;
# queue_free alone can leave decoded MP3/Ogg playback handles at process exit.
static func release(tree: SceneTree, scene: Node, owner: Variant = null) -> void:
	if is_instance_valid(scene):
		if scene.has_method("show_menu"):
			scene.show_menu()
		var audio: Node = scene.get_node_or_null("MenuFlow/Audio")
		if audio and audio.transition and audio.transition.is_valid():
			audio.transition.kill()
		for timer: Node in scene.find_children("*", "Timer", true, false):
			timer.stop()
		for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
			player.stream_paused = false
			player.stop()
		await tree.create_timer(0.12).timeout
		if is_instance_valid(owner):
			owner.queue_free()
		else:
			scene.queue_free()
		await tree.process_frame
		await tree.create_timer(0.12).timeout
