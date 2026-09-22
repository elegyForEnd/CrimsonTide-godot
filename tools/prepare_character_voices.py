"""Offline Japanese character performance, using licensed VOICEVOX voices.

Requires the official VOICEVOX Core 0.17 wheel in build/voicevox/python,
CPU runtime, Open JTalk dictionary and VVM 0, 2, 3 (0.16.4) under runtime/.
Only rendered WAVs and credits ship. No model, server or network at play time.
"""
from pathlib import Path
import hashlib
from dataclasses import asdict
import io
import json
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, resample_poly

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "build/voicevox"
sys.path.insert(0, str(LOCAL / "python"))
from voicevox_core.blocking import Onnxruntime, OpenJtalk, Synthesizer, VoiceModelFile

# Original dialogue: short breath-driven calls, then a two-part ultimate invocation.
HEROES = [
    dict(name="绯月", credit="VOICEVOX:四国めたん", model="0.vvm", style=6,
         pitch=.025, intonation=1.35, speed=1.22,
         lines={
             "attack": [("はっ！", "喝！"), ("やっ！", "呀！"), ("せいっ！", "斩！"), ("そこっ！", "就是那里！")],
             "heavy": [("叩き斬る！", "一刀斩断！"), ("砕け散れ！", "粉碎吧！")],
             "magic": [("紅蓮よ！", "红莲啊！"), ("貫け！", "贯穿吧！")],
             "dash": [("遅い！", "太慢了！"), ("見切った！", "看穿了！")],
             "hurt": [("くっ！", "唔！"), ("まだよ！", "还没完！")],
             "heal": [("まだ、戦える！", "我还能战斗！")],
             "down": [("こんな、ところで……", "怎能倒在……这里……")],
             "ultimate-charge": [("紅き月よ、我が刃に宿れ！", "绯红之月，寄宿于我刃！")],
             "ultimate-burst": [("奥義、紅蓮月華！", "奥义——红莲月华！")],
             "ultimate-short": [("紅蓮月華！", "红莲月华！")],
         }),
    dict(name="雪璃", credit="VOICEVOX:九州そら", model="2.vvm", style=16,
         pitch=.035, intonation=1.4, speed=1.20,
         lines={
             "attack": [("えいっ！", "嘿！"), ("はっ！", "喝！"), ("やあっ！", "呀！"), ("光よ！", "光芒啊！")],
             "heavy": [("退いて！", "退下！"), ("打ち砕け！", "击碎吧！")],
             "magic": [("星よ、穿て！", "星辰啊，贯穿吧！"), ("きらめけ！", "闪耀吧！")],
             "dash": [("こっちです！", "在这边！"), ("当たりません！", "打不中哦！")],
             "hurt": [("あっ！", "啊！"), ("大丈夫！", "没关系！")],
             "heal": [("癒やしの光よ！", "治愈之光啊！")],
             "down": [("みんな、ごめんね……", "大家，对不起……")],
             "ultimate-charge": [("星の祝福よ、この夜を照らせ！", "群星的祝福，照亮此夜！")],
             "ultimate-burst": [("聖域展開、暁の祈り！", "圣域展开——拂晓之祈！")],
             "ultimate-short": [("暁の祈り！", "拂晓之祈！")],
         }),
    dict(name="鸦羽", credit="VOICEVOX:波音リツ", model="3.vvm", style=65,
         pitch=-.025, intonation=1.25, speed=1.16,
         lines={
             "attack": [("ふっ！", "哼！"), ("はっ！", "喝！"), ("せいっ！", "斩！"), ("散れ！", "消散吧！")],
             "heavy": [("跪け！", "跪下！"), ("断ち切る！", "斩断！")],
             "magic": [("闇に沈め！", "沉入黑暗！"), ("消え失せろ！", "消失吧！")],
             "dash": [("残像だ！", "只是残影！"), ("甘い！", "太天真！")],
             "hurt": [("くっ！", "唔！"), ("その程度か！", "就这点本事？")],
             "heal": [("終わりは、まだだ！", "还未到终结之时！")],
             "down": [("翼は、まだ……", "我的羽翼……还……")],
             "ultimate-charge": [("終焉を告げる、黒き翼よ！", "宣告终焉的漆黑羽翼！")],
             "ultimate-burst": [("禁式解放、夜鴉断罪！", "禁式解放——夜鸦断罪！")],
             "ultimate-short": [("夜鴉断罪！", "夜鸦断罪！")],
         }),
]


def main():
    out = ROOT / "assets/audio/voices"
    out.mkdir(parents=True, exist_ok=True)
    raw_dir = LOCAL / "renders"
    raw_dir.mkdir(exist_ok=True)
    runtime = LOCAL / "runtime"
    onnx = Onnxruntime.load_once(filename=str(runtime / "onnxruntime/lib/voicevox_onnxruntime.dll"))
    dictionary = next(runtime.rglob("open_jtalk_dic_utf_8-1.11"))
    synth = Synthesizer(onnx, OpenJtalk(dictionary), acceleration_mode="CPU", cpu_num_threads=4)
    manifest = {"engine": "VOICEVOX Core 0.17.0", "models_version": "0.16.4", "language": "ja",
                "note": "Synthesized original game dialogue; credited voice libraries, not human performances or CC0.",
                "terms": ["https://zunko.jp/con_ongen_kiyaku.html", "https://www.canon-voice.com/terms",
                          "https://github.com/VOICEVOX/voicevox_vvm/blob/0.16.4/TERMS.txt"], "heroes": []}
    for hero, spec in enumerate(HEROES):
        model_path = next(runtime.rglob(spec["model"]))
        with VoiceModelFile.open(model_path) as model:
            synth.load_voice_model(model)
            model_id = model.id
        entry = {"name": spec["name"], "credit": spec["credit"], "style": spec["style"],
                 "model_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(), "lines": {}}
        for kind, lines in spec["lines"].items():
            entry["lines"][kind] = []
            for index, (text, translation) in enumerate(lines):
                filename = f"hero-{hero}-{kind}-{index}.wav"
                query = synth.create_audio_query(text, spec["style"])
                query.speed_scale = spec["speed"] + (.14 if kind == "attack" else -.09 if kind == "ultimate-charge" else 0)
                query.pitch_scale = spec["pitch"]
                query.intonation_scale = spec["intonation"] + (.12 if kind.startswith("ultimate") else 0)
                query.pre_phoneme_length = .01
                query.post_phoneme_length = .055
                query.output_sampling_rate = 48000
                query.output_stereo = False
                key = hashlib.sha256((str(spec["style"])+json.dumps(asdict(query), ensure_ascii=False)).encode()).hexdigest()[:16]
                raw_file = raw_dir / (key + ".wav")
                if not raw_file.exists():
                    raw_file.write_bytes(synth.synthesis(query, spec["style"], enable_interrogative_upspeak=False))
                rate, pcm = wavfile.read(io.BytesIO(raw_file.read_bytes()))
                x = pcm.astype(np.float64) / 32768
                active = np.flatnonzero(abs(x) > .006)
                x = x[max(0, active[0]-480):min(len(x), active[-1]+2400)]
                x = sosfilt(butter(2, [100, 14500], btype="bandpass", fs=rate, output="sos"), x)
                # Mild saturation and presence, retaining one intelligible central voice.
                x = np.tanh(x * 1.15)
                level = np.sqrt(np.mean(x*x))
                x *= min(4, .19 / max(level, 1e-6))
                peak = np.max(abs(resample_poly(x, 4, 1)))
                x *= min(1, .82 / max(peak, 1e-6))
                x[:240] *= np.linspace(0, 1, 240)
                x[-1440:] *= np.linspace(1, 0, 1440)
                wavfile.write(out / filename, rate, np.round(x*32767).astype(np.int16))
                entry["lines"][kind].append({"file": filename, "ja": text, "zh": translation,
                                              "length": round(len(x)/rate, 4),
                                              "sha256": hashlib.sha256((out/filename).read_bytes()).hexdigest()})
                print(filename, round(len(x)/rate, 2), flush=True)
        # The camera reaches its impact only after the spoken invocation finishes.
        entry["charge_time"] = round(entry["lines"]["ultimate-charge"][0]["length"] + .12, 3)
        entry["burst_time"] = round(entry["lines"]["ultimate-burst"][0]["length"] + .22, 3)
        manifest["heroes"].append(entry)
        synth.unload_voice_model(model_id)
    (out/"voice-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    credits = "Crimson Tide — 日语合成角色语音 / Japanese synthesized character voices\n\n"
    credits += "\n".join(f"{h['name']}: {h['credit']}" for h in HEROES)
    credits += "\n\nOriginal Japanese game dialogue and Chinese subtitles by this project.\n"
    credits += "These voices are synthesized with VOICEVOX, not recordings of hired actors.\n"
    credits += "Generated voice files are NOT CC0. Keep the above credits and comply with the voice library terms when reusing them.\n"
    credits += "\n".join(manifest["terms"]) + "\n\nOnly rendered game audio is distributed. Voice models and inference software are excluded.\n"
    (out/"CREDITS.txt").write_text(credits, encoding="utf-8")
    (ROOT/"VOICE-CREDITS.txt").write_text(credits, encoding="utf-8")
    print("VOICES:", sum(len(v) for h in manifest["heroes"] for v in h["lines"].values()))


if __name__ == "__main__":
    main()
