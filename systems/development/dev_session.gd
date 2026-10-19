extends RefCounted
## Session-only switches. Run metadata is deliberately excluded by PackRunSaves.
const FLAGS: Array[String] = ["invulnerable", "restore_health", "infinite_mana", "infinite_stamina"]
const LABELS: Dictionary = {"invulnerable": "Invulnerable", "restore_health": "Heal each round", "infinite_mana": "Infinite mana", "infinite_stamina": "Infinite stamina"}
var flags: Dictionary = {}
var _run_ref: WeakRef

static func enabled() -> bool:
	return OS.is_debug_build() or OS.get_cmdline_user_args().has("--packbound-dev")

func attach(run: PackRun) -> void:
	detach()
	_run_ref = weakref(run)
	run.set_meta("pack_dev_policy", flags)

func detach() -> void:
	if _run_ref != null and _run_ref.get_ref() != null:
		_run_ref.get_ref().remove_meta("pack_dev_policy")
	_run_ref = null
	clear_cheats()

func set_cheat(key: String, value: bool) -> bool:
	if not FLAGS.has(key): return false
	flags[key] = value
	return true

func clear_cheats() -> void:
	flags.clear()

func active_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for key: String in FLAGS:
		if flags.get(key, false): labels.append(LABELS[key])
	return labels
