"""Snapshot a complete Delver folder; verify contents without deleting originals."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import uuid
import zipfile


def digest(data):
    return hashlib.sha256(data).hexdigest()


def archive(root, delver_id):
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", delver_id):
        raise ValueError("ID must be lowercase kebab-case")
    if delver_id in {"archive", "portraits", "sources"}:
        raise ValueError("Reserved character directory")
    characters = root.resolve() / "assets" / "characters"
    source = characters / delver_id
    destination = root.resolve() / "workspace" / "archives" / "characters"
    if not source.is_dir() or not (source / "character.json").is_file():
        raise ValueError("Expected a Delver folder containing character.json")
    # Reject links/reparse points instead of archiving files outside the snapshot.
    paths = [source, destination, *source.rglob("*")]
    for path in paths:
        if path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction()):
            raise ValueError(f"Links/junctions are unsupported: {path}")
        if not path.resolve().is_relative_to(root.resolve()):
            raise ValueError(f"Path escapes project directory: {path}")
    files = sorted(p for p in paths[2:] if p.is_file())
    destination.mkdir(parents=True, exist_ok=True)
    (root.resolve() / "workspace" / ".gdignore").touch(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = destination / f"{delver_id}-{stamp}-{uuid.uuid4().hex[:8]}.zip"
    manifest = {}
    try:
        with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for path in paths[2:]:
                if path.is_dir():
                    z.writestr(f"{delver_id}/{path.relative_to(source).as_posix()}/", b"")
            for path in files:
                data = path.read_bytes()
                name = f"{delver_id}/{path.relative_to(source).as_posix()}"
                manifest[name] = {"bytes": len(data), "sha256": digest(data)}
                z.writestr(name, data)
            z.writestr("archive-manifest.json", json.dumps(manifest, indent=2))
        with zipfile.ZipFile(output) as z:
            if z.testzip() is not None:
                raise ValueError("ZIP integrity failure")
            for name, record in manifest.items():
                if digest(z.read(name)) != record["sha256"]:
                    raise ValueError(f"Archived hash mismatch: {name}")
                original = characters / name
                if digest(original.read_bytes()) != record["sha256"]:
                    raise ValueError(f"Source changed during snapshot: {name}")
        if {p.relative_to(source) for p in source.rglob("*") if p.is_file()} != {p.relative_to(source) for p in files}:
            raise ValueError("Source file list changed during snapshot")
    except Exception:
        # A partial archive remains visibly marked; never present it as verified.
        if output.exists():
            output.rename(output.with_suffix(".zip.failed"))
        raise
    return {"archive": str(output), "files": len(files), "verified": True,
            "sourceBytes": sum(r["bytes"] for r in manifest.values()), "zipBytes": output.stat().st_size}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Packbound project root")
    parser.add_argument("--id", required=True, help="Stable Delver folder ID")
    args = parser.parse_args()
    print(json.dumps(archive(args.root, args.id), indent=2))
