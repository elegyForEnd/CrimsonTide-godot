"""Run the shipped executable, isolated preferences, absolute logs and real GPU capture."""
from pathlib import Path
import argparse,os,shutil,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser();parser.add_argument("--renderer",choices=["forward_plus","gl_compatibility"],default="forward_plus");parser.add_argument("--gallery",action="store_true")
    args=parser.parse_args();name="vn-full-native-"+args.renderer+("-gallery" if args.gallery else "")
    log=ROOT/"output"/(name+".log");env=os.environ.copy();env["APPDATA"]=str(ROOT/".testappdata")
    flags=["--vn-full-gallery","--capture-vn-full"] if args.gallery else ["--preview-portraits","--capture-portraits-release"]
    started=time.time()
    with (ROOT/"output"/(name+".stdio.log")).open("w",encoding="utf-8") as stream:
        result=subprocess.run([str(ROOT/"dist/CrimsonTide-ForwardPlus-v14.exe"),"--rendering-method",args.renderer,"--log-file",str(log),"--"]+flags,cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=90)
    print(name,"exit",result.returncode)
    contents=log.read_text(encoding="utf-8") if log.exists() else ""
    print(contents[-2500:])
    marker="VN_FULL_GALLERY_CAPTURE 27 combinations" if args.gallery else "VN_FULL_RELEASE_CAPTURE hero=2 outfit=travel pose=crossed expression=joy error=0"
    if result.returncode==0:
        assert marker in contents, "Native capture success marker missing"
        assert "SCRIPT ERROR" not in contents, "Native script error"
        captures=list((ROOT/"build").glob("vn-full-gallery-?-?-?.png")) if args.gallery else [ROOT/"build/vn-full-native-v14.png"]
        assert len(captures)==(27 if args.gallery else 1), "Capture count incorrect"
        assert all(path.exists() and path.stat().st_mtime>=started-2 for path in captures), "Missing or stale capture"
        if not args.gallery:shutil.copy2(captures[0],ROOT/"build"/(name+".png"))
    raise SystemExit(result.returncode)
if __name__=="__main__":main()
