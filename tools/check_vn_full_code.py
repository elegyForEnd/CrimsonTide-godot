"""Parse the six current portrait presentation scripts in an isolated staging path."""
from pathlib import Path
import os,subprocess
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/"build/vn-full-codecheck"
NAMES=["story_portrait_art","story_portrait_view","story_dialogue_ui","story_portrait_preview","vn_full_gallery","vn_full_patch_boot"]
def main():
    STAGE.mkdir(parents=True,exist_ok=True)
    for name in NAMES:
        text=(ROOT/"scripts"/(name+".gd")).read_text(encoding="utf-8")
        for target in NAMES:text=text.replace("res://scripts/"+target+".gd","res://build/vn-full-codecheck/"+target+".gd")
        (STAGE/(name+".gd")).write_text(text,encoding="utf-8")
    runner='extends SceneTree\nfunc _initialize() -> void:\n\tvar failures := 0\n'
    for name in NAMES:
        runner+='\tvar '+name+'=load("res://build/vn-full-codecheck/'+name+'.gd")\n'
        runner+='\tif '+name+'==null or not '+name+'.can_instantiate(): failures+=1\n'
    runner+='\tprint("VN_FULL_CODE_CHECK scripts=6 failures=",failures)\n\tquit(failures)\n'
    (STAGE/"check.gd").write_text(runner,encoding="utf-8")
    env=os.environ.copy();env["APPDATA"]=str(ROOT/".testappdata")
    with (ROOT/"output/vn-full-codecheck.log").open("w",encoding="utf-8") as log:
        result=subprocess.run([str(ROOT/"Godot_v4.7.2-stable_win64_console.exe"),"--headless","--path",str(ROOT),"--script","build/vn-full-codecheck/check.gd"],env=env,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=60)
    print("current presentation scripts parse",result.returncode)
    raise SystemExit(result.returncode)
if __name__=="__main__":main()
