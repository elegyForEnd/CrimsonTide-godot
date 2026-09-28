"""Fetch the selected CC0 KayKit assets, pinned to upstream commits.

Only data files are downloaded. No upstream plugins or scripts are installed.
Run with Python 3 and the authenticated GitHub CLI available on PATH.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import urllib.parse
import urllib.request

ROOT = Path(__file__).absolute().parents[1]
DEST = ROOT / "assets/vendor/kaykit"
PACKS = {
    "dungeon": ("KayKit-Dungeon-Remastered-1.0", "kaykit_dungeon_remastered", {
        name: "gltf/" + name + (".glb" if name in ["chest", "chest_gold"] else ".gltf.glb")
        for name in ["wall", "wall_broken", "wall_cracked", "wall_arched", "pillar_decorated",
                     "column", "barrier", "floor_wood_large", "banner_red", "banner_shield_red",
                     "chest", "chest_gold", "table_long_decorated_A", "shelf_small_candles",
                     "rubble_large", "torch_lit", "floor_tile_large", "chair"]
    }),
    "halloween": ("KayKit-Halloween-Bits-1.0", "kaykit_halloween_bits", {
        name: "gltf/" + name + ".gltf"
        for name in ["arch", "shrine_candles", "lantern_standing", "tree_dead_large",
                     "tree_dead_medium", "gravestone", "crypt", "bench_decorated"]
    }),
    "medieval": ("KayKit-Medieval-Hexagon-Pack-1.0", "kaykit_medieval_hexagon_pack", {
        **{name: "gltf/buildings/red/" + name + ".gltf" for name in [
            "building_castle_red", "building_church_red", "building_tower_A_red",
            "building_market_red", "building_tavern_red", "building_mine_red"]},
        **{name: "gltf/decoration/nature/" + name + ".gltf" for name in [
            "tree_single_A", "tree_single_B", "rock_single_A", "rock_single_B", "waterplant_A"]},
        "tent": "gltf/decoration/props/tent.gltf",
    }),
}


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], encoding="utf-8"))


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    lock_path = DEST / "sources.json"
    previous = json.loads(lock_path.read_text()) if lock_path.exists() else {}
    sources, assets = {}, {}
    for pack, (repo_name, addon, models) in PACKS.items():
        repo = "KayKit-Game-Assets/" + repo_name
        commit = previous.get(pack, {}).get("commit") or api(f"repos/{repo}/commits/main")["sha"]
        source = {"repository": "https://github.com/" + repo, "commit": commit,
                  "author": "Kay Lousberg", "license": "CC0-1.0", "files": []}
        folder = DEST / pack
        downloaded = set()

        def fetch(remote, local):
            local = local.absolute()
            if not local.is_relative_to(folder.absolute()):
                raise ValueError("Dependency escaped pack directory")
            if remote in downloaded:
                return local.read_bytes()
            url = f"https://raw.githubusercontent.com/{repo}/{commit}/" + urllib.parse.quote(remote)
            with urllib.request.urlopen(url, timeout=45) as response:
                data = response.read()
            local.parent.mkdir(parents=True, exist_ok=True)
            local.write_bytes(data)
            downloaded.add(remote)
            source["files"].append({"path": str(local.relative_to(DEST)).replace("\\", "/"),
                                    "url": url, "sha256": hashlib.sha256(data).hexdigest()})
            return data

        fetch("LICENSE.txt", folder / "LICENSE.txt")
        fetch("README.md", folder / "UPSTREAM.md")
        for name, relative in models.items():
            remote = f"addons/{addon}/Assets/{relative}"
            local = folder / "models" / Path(relative).name
            data = fetch(remote, local)
            if local.suffix == ".gltf":
                document = json.loads(data)
                for dependency in document.get("buffers", []) + document.get("images", []):
                    uri = dependency.get("uri", "")
                    if not uri or uri.startswith("data:"):
                        continue
                    # Resolve upstream relative paths and flatten dependencies locally.
                    from posixpath import normpath, dirname
                    dep_remote = normpath(dirname(remote) + "/" + urllib.parse.unquote(uri))
                    dep_local = folder / "models" / Path(uri).name
                    fetch(dep_remote, dep_local)
                    dependency["uri"] = dep_local.name
                local.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
            assets[pack + "/" + name] = "res://" + str(local.relative_to(ROOT)).replace("\\", "/")
            print(pack + "/" + name, flush=True)
        sources[pack] = source
        for entry in source["files"]:
            entry["local_sha256"] = hashlib.sha256((DEST / entry["path"]).read_bytes()).hexdigest()
        lock_path.write_text(json.dumps(sources, indent=2) + "\n", encoding="utf-8")
    (DEST / "models.json").write_text(json.dumps(assets, indent=2) + "\n", encoding="utf-8")
    print(f"Downloaded {len(assets)} models. Sources and original hashes in {lock_path}")


if __name__ == "__main__":
    main()
