"""Build a local PCK and verify its resources/startup without player data.

Run after one serial editor import. Artifacts remain under workspace; no publish.
The Godot AI export plugin strips its editor autoload before addons are excluded.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
ERROR = re.compile(r"(?:SCRIPT )?ERROR:|Parse Error:", re.I)
PROBE = r'''extends SceneTree
func _initialize() -> void:
	var user_path := OS.get_user_data_dir().replace("\\", "/")
	var expected := OS.get_environment("PACKBOUND_PACKAGE_SANDBOX").replace("\\", "/")
	if not user_path.begins_with(expected + "/"):
		push_error("Package user data escaped sandbox: " + user_path)
		quit(1)
		return
	var content = load("res://assets/game_content.tres")
	if content == null:
		push_error("Packaged content is missing")
		quit(1)
		return
	var errors = content.refresh_from_folders()
	if not errors.is_empty():
		push_error("Packaged content validation: " + str(errors))
		quit(1)
		return
	var counts := {}
	for field in ["characters", "character_classes", "monsters", "recipes", "status_effects", "loot_pools", "loot_progressions"]:
		var values = content.get(field)
		if values == null or values.is_empty():
			push_error("Packaged content collection empty: " + field)
			quit(1)
			return
		counts[field] = values.size()
	counts["collectibles"] = content.collectibles.collectibles.size()
	counts["categories"] = content.collectibles.categories.size()
	var expected_counts = JSON.parse_string(OS.get_environment("PACKBOUND_PACKAGE_EXPECTED_COUNTS"))
	if not expected_counts is Dictionary or counts.size() != expected_counts.size():
		push_error("Packaged content differs from source: " + str(counts) + " expected " + str(expected_counts))
		quit(1)
		return
	for field in counts:
		if int(counts[field]) != int(expected_counts.get(field, -1)):
			push_error("Packaged content count differs for " + field + ": " + str(counts[field]) + " expected " + str(expected_counts.get(field)))
			quit(1)
			return
	var forbidden := []
	for path in ["res://workspace", "res://tests", "res://docs", "res://addons"]:
		if DirAccess.dir_exists_absolute(path): forbidden.append(path)
	if not forbidden.is_empty() or ProjectSettings.has_setting("autoload/_mcp_game_helper"):
		push_error("Development content leaked into package: " + str(forbidden))
		quit(1)
		return
	print("PACKBOUND_PACKAGE_CONTENT " + JSON.stringify({"counts": counts, "user_data": user_path}))
	quit()
'''


STARTUP_PROBE = r'''extends SceneTree
func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var expected := OS.get_environment("PACKBOUND_PACKAGE_SANDBOX").replace("\\", "/")
	if not OS.get_user_data_dir().replace("\\", "/").begins_with(expected + "/"):
		push_error("Package startup escaped user-data sandbox")
		quit(1)
		return
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		push_error("Packaged main scene could not start")
		quit(1)
		return
	for frame in range(120):
		await process_frame
	if current_scene == null or not current_scene.has_method("request_quit"):
		push_error("Packaged main scene has no graceful quit entry point")
		quit(1)
		return
	await current_scene.request_quit()
	print("PACKBOUND_PACKAGE_STARTUP graceful_quit_completed")
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", default="workspace/tasks/local-export")
    args = parser.parse_args()
    output = (ROOT / args.output).resolve()
    if not output.is_relative_to(ROOT / "workspace"):
        parser.error("Output must remain inside the project workspace")
    output.mkdir(parents=True, exist_ok=True)
    engine = str(Path(args.godot).resolve())
    pack = output / "Packbound.pck"
    report = {}

    def run(name, arguments, env=None):
        start = time.perf_counter()
        result = subprocess.run([engine, *arguments], cwd=output, env=env,
                                capture_output=True, text=True, timeout=180)
        text = result.stdout + result.stderr
        (output / (name + ".log")).write_text(text, encoding="utf-8")
        report[name] = {"exit_code": result.returncode,
                        "seconds": round(time.perf_counter() - start, 3),
                        "errors": bool(ERROR.search(text)),
                        "warnings": [line for line in text.splitlines() if "WARNING:" in line]}
        if result.returncode or ERROR.search(text):
            raise RuntimeError(f"{name} failed; see {output / (name + '.log')}")
        return text

    try:
        run("export", ["--headless", "--path", str(ROOT), "--log-file",
                       str(output / "export-engine.log"), "--export-pack",
                       "Windows Desktop", str(pack)])
        report["pack_bytes"] = pack.stat().st_size
        sandbox = output / "sandbox"
        env = os.environ.copy()
        for key, directory in {"APPDATA": "appdata", "LOCALAPPDATA": "localappdata",
                               "HOME": "home", "USERPROFILE": "home", "XDG_DATA_HOME": "data",
                               "XDG_CONFIG_HOME": "config", "XDG_CACHE_HOME": "cache",
                               "TEMP": "temp", "TMP": "temp"}.items():
            path = sandbox / directory
            path.mkdir(parents=True, exist_ok=True)
            env[key] = str(path)
        expected = {}
        for field, folder, pattern in [
            ("characters", "characters", "character.tres"),
            ("character_classes", "characters", "character_class.tres"),
            ("monsters", "enemies", "monster.tres"),
            ("recipes", "recipes", "*.tres"),
            ("status_effects", "status_effects", "status_effect.tres"),
            ("loot_pools", "loot/pools", "*.tres"),
            ("loot_progressions", "loot/progressions", "*.tres"),
            ("categories", "categories", "*.tres"),
        ]:
            expected[field] = sum(1 for _ in (ROOT / "assets" / folder).rglob(pattern))
        expected["collectibles"] = sum(1 for folder, pattern in [("items", "item.tres"), ("relics", "relic.tres")]
                                       for _ in (ROOT / "assets" / folder).rglob(pattern))
        env["PACKBOUND_PACKAGE_EXPECTED_COUNTS"] = json.dumps(expected)
        env["PACKBOUND_PACKAGE_SANDBOX"] = str(sandbox)
        probe = output / "package_probe.gd"
        probe.write_text(PROBE, encoding="utf-8")
        result = run("content", ["--headless", "--main-pack", str(pack), "--log-file",
                                str(output / "content-engine.log"), "--script", str(probe)], env)
        if "PACKBOUND_PACKAGE_CONTENT " not in result:
            raise RuntimeError("Content probe did not complete")
        report["content_result"] = json.loads(result.split("PACKBOUND_PACKAGE_CONTENT ", 1)[1].splitlines()[0])
        startup_probe = output / "package_startup_probe.gd"
        startup_probe.write_text(STARTUP_PROBE, encoding="utf-8")
        startup = run("startup", ["--headless", "--main-pack", str(pack), "--log-file",
                                  str(output / "startup-engine.log"), "--script", str(startup_probe)], env)
        if "PACKBOUND_PACKAGE_STARTUP graceful_quit_completed" not in startup:
            raise RuntimeError("Packaged startup did not complete graceful quit")
    finally:
        (output / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
