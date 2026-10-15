"""Safely inspect/synchronize the four Chest RPG UI scripts with an open Studio Edit place.

Run from the project root with ``python3 tools/sync_dark_ui_studio.py`` for an
inspection. Pass ``--sync`` only after inspecting the reported Studio revisions.
Studio copies are backed up to /private/tmp before any changes. Does not publish.
"""
from __future__ import annotations

import argparse
import difflib
import json
import sys
import time
import zlib
from pathlib import Path

sys.path.insert(0, "/private/tmp")
from chest_rng_studio_sync_20261014 import Client, PLACE_ID, REPO, studio_info  # type: ignore

MODULES = {
    "UIController": "src/client/Controllers/UIController.luau",
    "Theme": "src/client/UI/Theme.luau",
    "Components": "src/client/UI/Components.luau",
    "Icons": "src/client/UI/Icons.luau",
}

# Confirm Studio still contains the revision inspected on October 15.
# A later edit must be inspected and reconciled before this script can replace it.
REVIEWED_STUDIO_DIGESTS = {
    "UIController": (67411, 2803939222),
    "Theme": (2103, 2946588762),
    "Components": (5210, 936436677),
    "Icons": (3073, 2084920674),
}


def digest(source: str) -> tuple[int, int]:
    raw = source.encode("utf-8")
    return len(raw), zlib.adler32(raw)


def paths_luau() -> str:
    return '''local client=game.StarterPlayer.StarterPlayerScripts:FindFirstChild("Client")
assert(client and client:FindFirstChild("Controllers") and client:FindFirstChild("UI"), "Missing Client tree")
local mods={UIController=client.Controllers:FindFirstChild("UIController"),
 Theme=client.UI:FindFirstChild("Theme"), Components=client.UI:FindFirstChild("Components"),
 Icons=client.UI:FindFirstChild("Icons")}
for key,mod in mods do assert(mod and mod:IsA("LuaSourceContainer"), "Missing script "..key) end
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sync", action="store_true", help="Update UI scripts in Studio Edit mode")
    args = parser.parse_args()

    c = Client()
    try:
        sid = studio_info(c)
        studio_state = c.tool("get_studio_state", {"studio_id": sid})
        print("STUDIO_STATE", studio_state, flush=True)
        if "Current Studio Mode: Edit" not in studio_state or "Focused DataModel in the viewport: Edit" not in studio_state:
            raise RuntimeError("Studio must be in Edit mode before changing module sources")
        code = paths_luau() + '''
local out={place=game.PlaceId,sources={}}
for key,mod in mods do out.sources[key]=mod.Source end
return out'''
        read = json.loads(c.tool("execute_luau", {
            "studio_id": sid, "datamodel_type": "Edit", "code": code}, timeout=85))
        if str(read.get("place")) != PLACE_ID:
            raise RuntimeError(f"Unexpected place id: {read.get('place')}")
        before = read["sources"]
        if args.sync:
            unexpected = {key: (digest(before[key]), REVIEWED_STUDIO_DIGESTS[key])
                          for key in MODULES if digest(before[key]) != REVIEWED_STUDIO_DIGESTS[key]}
            if unexpected:
                raise RuntimeError(f"Studio sources changed since reviewed inspection: {unexpected}")
        desired = {key: (REPO / filename).read_text() for key, filename in MODULES.items()}
        stamp = time.strftime("%Y%m%d_%H%M%S")
        backup_dir = Path("/private/tmp") / f"chest_ui_studio_before_{stamp}"
        backup_dir.mkdir(parents=True, exist_ok=False)
        changes = []
        for key in MODULES:
            old, new = before[key], desired[key]
            (backup_dir / f"{key}.luau").write_text(old)
            old_digest, new_digest = digest(old), digest(new)
            line_diff = list(difflib.unified_diff(old.splitlines(), new.splitlines(), n=0))
            changed_lines = sum(line.startswith(("+", "-")) and not line.startswith(("+++", "---")) for line in line_diff)
            print("MODULE", key, "Studio", old_digest, "repo", new_digest,
                  "different", old != new, "changed_lines", changed_lines, flush=True)
            if old != new:
                (backup_dir / f"{key}.diff").write_text("\n".join(
                    difflib.unified_diff(old.splitlines(), new.splitlines(),
                                         fromfile="Studio", tofile="Repository", lineterm="")))
                changes.append(key)
        print("STUDIO_BACKUP", backup_dir, flush=True)
        if not args.sync:
            print("INSPECTION_ONLY; invoke --sync to install updated UI scripts", flush=True)
            return
        if not changes:
            print("ALREADY_MATCHED", flush=True)
            return
        # Validate every source before assigning any, so unexpected concurrent
        # edits stop the operation before it can overwrite any Studio scripts.
        guard = [paths_luau(), f'assert(game.PlaceId=={PLACE_ID}, "Place changed")',
                 '''local function checksum(s)
local a,b=1,0
for i=1,#s do a=(a+string.byte(s,i))%65521; b=(b+a)%65521 end
return b*65536+a
end''']
        for key in MODULES:
            size, adler = digest(before[key])
            guard.append(f'assert(#mods.{key}.Source=={size} and checksum(mods.{key}.Source)=={adler}, "{key} changed since backup")')
        for key in changes:
            # json string quoting is compatible with Luau for these UTF-8 sources.
            guard.append(f'mods.{key}.Source = {json.dumps(desired[key], ensure_ascii=False)}')
        guard.append('local out={}')
        for key in MODULES:
            guard.append(f'out.{key}={{length=#mods.{key}.Source,adler=checksum(mods.{key}.Source)}}')
        guard.append('return out')
        installed = json.loads(c.tool("execute_luau", {
            "studio_id": sid, "datamodel_type": "Edit", "code": "\n".join(guard)}, timeout=120))
        for key in MODULES:
            assert (installed[key]["length"], installed[key]["adler"]) == digest(desired[key]), (
                "Verification failed for", key, installed[key])
        # Verify in a fresh query as well, independent of the assignment command.
        verify = json.loads(c.tool("execute_luau", {
            "studio_id": sid, "datamodel_type": "Edit", "code": code}, timeout=85))
        for key, source in desired.items():
            assert verify["sources"][key] == source, f"Readback mismatch: {key}"
        print("SYNC_VERIFIED", changes, "place", read["place"], flush=True)
    finally:
        c.close()


if __name__ == "__main__":
    main()
