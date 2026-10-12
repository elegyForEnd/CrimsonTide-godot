"""Compile just whole-portrait presentation scripts and whitelist all 216 textures."""
from pathlib import Path
import os,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
SCRIPTS=["story_dialogue_ui","story_portrait_art","story_portrait_view","story_portrait_preview","vn_full_gallery"]
def run(args,log_name):
    env=os.environ.copy();env["APPDATA"]=str(ROOT/".testappdata")
    with (ROOT/"output"/log_name).open("w",encoding="utf-8") as log:
        subprocess.run(args,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=300)
def main():
    engine=ROOT/"Godot_v4.7.2-stable_win64_console.exe"
    template=Path(os.environ["APPDATA"])/"Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe"
    if not template.exists():raise FileNotFoundError(template)
    presets=ROOT/"export_presets.cfg";original=presets.read_bytes()
    index=max(map(int,re.findall(rb"\[preset\.(\d+)\]",original)),default=-1)+1
    files=", ".join('"res://scripts/'+name+'.gd"' for name in SCRIPTS)
    extra=f'''\n[preset.{index}]
name="Whole VN staging"
platform="Windows Desktop"
runnable=false
export_filter="selected_resources"
export_files=PackedStringArray({files})
include_filter=""
exclude_filter="assets/*,art/*,resources/*,pv/*,dist/*,build/*,output/*,tests/*,tools/*"
script_export_mode=2
[preset.{index}.options]
binary_format/embed_pck=false
texture_format/s3tc=true
binary_format/architecture="x86_64"
'''
    try:
        presets.write_bytes(original+extra.encode())
        run([str(engine),"--headless","--path",str(ROOT),"--export-pack","Whole VN staging",str(ROOT/"build/vn-full-compiled.pck")],"vn-full-compile.log")
    finally:presets.write_bytes(original)
    run([str(engine),"--headless","--path",str(ROOT),"--script","tools/pack_vn_full.gd"],"vn-full-pack.log")
    staging=(ROOT/"build").resolve()
    for temporary in staging.glob("vn-full-pack-*.bin"):
        if temporary.is_file() and temporary.resolve().parent==staging:temporary.unlink()
    subprocess.run([sys.executable,str(ROOT/"tools/build_story_patch_runtime.py"),str(template),"--pack","CrimsonTide-VN-Full-Launcher.pck","--output","CrimsonTide-ForwardPlus-v14.exe"],check=True)
    (ROOT/"build/vn-full-compiled.pck").unlink()
if __name__=="__main__":main()
