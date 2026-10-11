"""Compile Godot scripts, whitelist three dialogue scripts, embed the release bootstrap."""
from pathlib import Path
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(args, log_name):
    env = os.environ.copy()
    env["APPDATA"] = str(ROOT / ".testappdata")
    with (ROOT / "output" / log_name).open("w", encoding="utf-8") as log:
        subprocess.run(args, cwd=ROOT, env=env, stdout=log,
                       stderr=subprocess.STDOUT, check=True, timeout=180)


def main():
    engine = ROOT / "Godot_v4.7.2-stable_win64_console.exe"
    template = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        Path(os.environ["APPDATA"]) / "Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe")
    if not template.is_file():
        raise FileNotFoundError(template)
    presets = ROOT / "export_presets.cfg"
    original = presets.read_bytes()
    index = max(map(int, re.findall(rb"\[preset\.(\d+)\]", original)), default=-1) + 1
    extra = f'''
[preset.{index}]
name="Dialogue patch staging"
platform="Windows Desktop"
runnable=false
export_filter="selected_resources"
export_files=PackedStringArray("res://scripts/story_screen.gd", "res://scripts/story_dialogue_ui.gd", "res://scripts/story_dialogue_data.gd")
include_filter=""
exclude_filter="assets/*,art/*,resources/*,pv/*,dist/*,build/*,output/*,tests/*,tools/*"
script_export_mode=2
[preset.{index}.options]
binary_format/embed_pck=false
texture_format/s3tc=true
binary_format/architecture="x86_64"
'''
    try:
        presets.write_bytes(original + extra.encode("utf-8"))
        run([str(engine), "--headless", "--path", str(ROOT), "--export-pack",
             "Dialogue patch staging", str(ROOT / "build/dialogue-compiled.pck")],
            "galgame-compile-export.log")
    finally:
        presets.write_bytes(original)
    run([str(engine), "--headless", "--path", str(ROOT), "--script",
         "tools/pack_story_dialogue.gd"], "galgame-pack-final.log")
    subprocess.run([sys.executable, str(ROOT / "tools/build_story_patch_runtime.py"),
                    str(template), "--pack", "CrimsonTide-Dialogue-Launcher.pck",
                    "--output", "CrimsonTide-ForwardPlus-v12.exe"], check=True)
    # The intermediate export may contain transitive dependencies; only the three
    # remaps and three compiled scripts enter the distributed dialogue patch.
    (ROOT / "build/dialogue-compiled.pck").unlink()


if __name__ == "__main__":
    main()
