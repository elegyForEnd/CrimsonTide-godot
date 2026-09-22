"""MiniMax speech-2.8-hd game voice bank; no credential is ever written to disk.

Run normally to read MINIMAX_API_KEY from the environment or a hidden prompt.
Only original dialogue is submitted. Successful requests are cached in build/.
Two independent requests at a time; source WAVs, JSON recipes and trace IDs are
retained for review. Final game WAVs are mono 48 kHz with safe transients/tails.
"""
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import getpass
import hashlib
import io
import json
import math
import os
import shutil
import time
import urllib.request
import argparse
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parents[1]
MODEL = "speech-2.8-hd"
CAST = [
    {"voice_id":"ttv-voice-2026092214390726-WEnHawap", "speed":1.12, "pitch":0},
    {"voice_id":"Japanese_GracefulMaiden", "speed":1.10, "pitch":0},
    {"voice_id":"Japanese_ColdQueen", "speed":1.10, "pitch":-1},
]
ULTIMATE_SPOKEN = [
    {"ultimate-charge":"紅き月よ！<#0.10#>我が刃に宿れ！",
     "ultimate-burst":"奥義！<#0.10#>グレンゲッカーー！！", "ultimate-short":"グレンゲッカーー！！"},
    {"ultimate-charge":"星の祝福よ！<#0.10#>この夜を照らせ！",
     "ultimate-burst":"聖域展開！<#0.10#>アカツキノイノリーー！！", "ultimate-short":"アカツキノイノリーー！！"},
    {"ultimate-charge":"終焉を告げる！<#0.10#>黒き翼よ！",
     "ultimate-burst":"禁式解放！<#0.10#>ヨガラスダンザイーー！！", "ultimate-short":"ヨガラスダンザイーー！！"},
]


def performance(hero, kind, text):
    cast = CAST[hero]
    emotion = "happy" if hero in [0,1] else "angry"
    if kind=="hurt": emotion="fearful"
    if kind=="down": emotion="sad"
    if kind=="heal": emotion="happy" if hero!=2 else "calm"
    if kind=="attack" and hero!=0: emotion="angry"
    # Specify invented attack names phonetically; display the original kanji in-game.
    spoken = text.replace("紅蓮月華", "グレンゲッカ").replace("夜鴉断罪", "ヨガラスダンザイ")
    speed = cast["speed"] + (.15 if kind=="attack" else -.03 if kind=="ultimate-charge" else 0)
    if kind.startswith("ultimate-"):
        spoken=ULTIMATE_SPOKEN[hero][kind]
        speed=1.12 if kind=="ultimate-charge" else 1.10
    payload = {"model":MODEL,"text":spoken,"stream":False,"language_boost":"Japanese",
            "voice_setting":{"voice_id":cast["voice_id"],"speed":speed,"vol":1,"pitch":cast["pitch"],"emotion":emotion},
            "audio_setting":{"sample_rate":44100,"format":"wav","channel":1},"output_format":"hex"}
    # Feiyue uses an original sweet anime voice designed by MiniMax, without cloning.
    if kind=="attack" and hero!=0:
        payload["voice_modify"]={"intensity":-30}
    overrides=ROOT/"tools/voice_performance.json"
    if overrides.exists():
        override=json.loads(overrides.read_text(encoding="utf-8")).get(str(hero),{}).get(kind,{})
        for key,value in override.items():
            if key in ["voice_setting","voice_modify"]:
                payload.setdefault(key,{}).update(value)
            else:
                payload[key]=value
    return payload


def build(request):
    script = json.loads((ROOT/"tools/voice_dialogue.json").read_text(encoding="utf-8"))
    cache = ROOT/"build/minimax/cache"
    stage = ROOT/"build/minimax/voice-bank"
    cache.mkdir(parents=True,exist_ok=True)
    stage.mkdir(parents=True,exist_ok=True)
    metadata = {"engine":"MiniMax "+MODEL,"provider":"MiniMax","language":"ja",
                "endpoint":"https://api.minimax.cn/v1/t2a_v2",
                "note":"AI-synthesized original game dialogue; system and text-designed Japanese voices, no voice cloning. Not CC0.",
                "terms":["https://platform.minimaxi.com/docs/api-reference/speech-t2a-http"],"heroes":[]}
    jobs = []
    for hero, source in enumerate(script):
        metadata["heroes"].append({"name":source["name"],"credit":"MiniMax "+MODEL+" / "+CAST[hero]["voice_id"],
                                   "voice_id":CAST[hero]["voice_id"],"lines":{k:[None]*len(v) for k,v in source["lines"].items()}})
        if hero==0:
            metadata["heroes"][hero]["voice_design"]=json.loads((ROOT/"tools/feiyue_voice_design.json").read_text(encoding="utf-8"))
        for kind, lines in source["lines"].items():
            for i,line in enumerate(lines): jobs.append((hero,kind,i,line))

    def render(job):
        hero,kind,i,line=job
        filename=f"hero-{hero}-{kind}-{i}.wav"
        payload=performance(hero,kind,line["ja"])
        key=hashlib.sha256(json.dumps(payload,ensure_ascii=False,sort_keys=True).encode()).hexdigest()
        raw_path=cache/(key+".wav")
        meta_path=cache/(key+".json")
        if not raw_path.exists() or not meta_path.exists():
            result=None
            for attempt in range(3):
                try:
                    result=request("t2a_v2",payload)
                    break
                except (TimeoutError,RuntimeError) as error:
                    if attempt==2 or not any(token in str(error) for token in ["1001","1002","1039","timeout","timed out"]):raise
                    time.sleep(30*(attempt+1))
            raw_path.write_bytes(bytes.fromhex(result["data"]["audio"]))
            info={"request":payload,"trace_id":result.get("trace_id"),"extra_info":result.get("extra_info",{})}
            meta_path.write_text(json.dumps(info,ensure_ascii=False,indent=2),encoding="utf-8")
        info=json.loads(meta_path.read_text(encoding="utf-8"))
        rate,pcm=wavfile.read(io.BytesIO(raw_path.read_bytes()))
        if pcm.dtype!=np.int16:raise ValueError(f"Unexpected PCM format: {filename}")
        x=pcm.astype(np.float64)/32768
        if x.ndim==2:x=x.mean(axis=1)
        divisor=math.gcd(rate,48000)
        x=resample_poly(x,48000//divisor,rate//divisor)
        active=np.flatnonzero(abs(x)>.006)
        if len(active)<100:raise ValueError(f"Silent generation: {filename}")
        x=x[max(0,active[0]-480):min(len(x),active[-1]+2400)]
        if len(x)/48000>9:raise ValueError(f"Unexpectedly long generation: {filename}")
        x=sosfilt(butter(2,[90,16000],btype="bandpass",fs=48000,output="sos"),x)
        # Keep MiniMax's performed pitch contour, at the original voice-bank loudness.
        emphasis_db=0.0
        x=np.tanh(x*1.10)
        target_rms=.19
        x*=min(4,target_rms/max(float(np.sqrt(np.mean(x*x))),1e-6))
        peak=float(np.max(abs(resample_poly(x,4,1))))
        x*=min(1,.82/max(peak,1e-6))
        x[:240]*=np.linspace(0,1,240)
        x[-1440:]*=np.linspace(1,0,1440)
        wavfile.write(stage/filename,48000,np.round(x*32767).astype(np.int16))
        result={"file":filename,"ja":line["ja"],"zh":line["zh"],"spoken_text":payload["text"],
                "length":round(len(x)/48000,4),"sha256":hashlib.sha256((stage/filename).read_bytes()).hexdigest(),
                "model":MODEL,"voice_id":CAST[hero]["voice_id"],"voice_setting":payload["voice_setting"],
                "voice_modify":payload.get("voice_modify",{}),
                "prosody":{"source":"MiniMax synthesis","local_pitch_edit":False},
                "mastering":{"target_rms":target_rms,"ending_emphasis_db":emphasis_db,"true_peak_limit":.82},
                "trace_id":info.get("trace_id"),"usage_characters":info.get("extra_info",{}).get("usage_characters",0)}
        print(filename,result["length"],"seconds",flush=True)
        return hero,kind,i,result

    with ThreadPoolExecutor(max_workers=2) as pool:
        for future in as_completed([pool.submit(render,job) for job in jobs]):
            hero,kind,i,result=future.result()
            metadata["heroes"][hero]["lines"][kind][i]=result
    for hero in metadata["heroes"]:
        hero["charge_time"]=round(hero["lines"]["ultimate-charge"][0]["length"]+.12,3)
        hero["burst_time"]=round(hero["lines"]["ultimate-burst"][0]["length"]+.22,3)
    (stage/"voice-manifest.json").write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding="utf-8")
    credits=["CRIMSON TIDE — JAPANESE CHARACTER VOICES", "",
             "Generated with MiniMax speech-2.8-hd using the project's authorized MiniMax account.",
             "Original fictional-character dialogue; system and text-designed voices, no cloning or impersonation.",
             "AI-generated speech, not recordings by hired voice actors. These voice assets are not CC0.",
             "Use and redistribution are subject to the applicable MiniMax account and service terms.", ""]
    credits += [h["name"]+": "+h["voice_id"] for h in metadata["heroes"]]
    credits += ["", "Original Japanese dialogue and Chinese subtitles: tools/voice_dialogue.json.",
                "Voice IDs, performance settings, trace IDs, durations and hashes: voice-manifest.json.",
                "https://platform.minimaxi.com/docs/api-reference/speech-t2a-http",
                "Only offline rendered audio ships. No API credential, model runtime or network access is needed to play."]
    (stage/"CREDITS.txt").write_text("\n".join(credits)+"\n",encoding="utf-8")
    target=ROOT/"assets/audio/voices"
    if not (ROOT/"build/minimax/previous-voice-bank").exists():
        shutil.copytree(target,ROOT/"build/minimax/previous-voice-bank")
    for p in stage.iterdir():
        if p.suffix in [".wav",".json",".txt"]:shutil.copy2(p,target/p.name)
    shutil.copy2(stage/"CREDITS.txt",ROOT/"VOICE-CREDITS.txt")
    print("MINIMAX BANK COMPLETE:",len(jobs),"clips",flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-only",action="store_true",help="Rebuild cached audio without credentials or API requests")
    args=parser.parse_args()
    if args.cache_only:
        def cache_miss(endpoint,payload):
            raise RuntimeError("Missing cached MiniMax response; rerun without --cache-only to synthesize")
        build(cache_miss)
        raise SystemExit(0)
    token=os.environ.get("MINIMAX_API_KEY") or getpass.getpass("MiniMax API key (hidden): ")
    def request(endpoint,payload):
        req=urllib.request.Request("https://api.minimax.cn/v1/"+endpoint,data=json.dumps(payload,ensure_ascii=False).encode(),
                                   headers={"Authorization":"Bearer "+token,"Content-Type":"application/json"})
        with urllib.request.urlopen(req,timeout=120) as response:result=json.load(response)
        if result.get("base_resp",{}).get("status_code",0)!=0:
            raise RuntimeError(str(result["base_resp"]).replace(token,"[redacted]"))
        return result
    build(request)
