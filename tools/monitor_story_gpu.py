"""Sample whole-device VRAM once per second while our benchmark runs."""
import pathlib,subprocess,time,json,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
rows=[]; start=time.time(); duration=int(sys.argv[1]) if len(sys.argv)>1 else 4000
while time.time()-start<duration:
    payload=subprocess.check_output(['nvidia-smi','--query-gpu=memory.used,utilization.gpu','--format=csv,noheader,nounits'],text=True).strip().split(',')
    rows.append({'seconds':round(time.time()-start,2),'used_mib':int(payload[0]),'utilization':int(payload[1])})
    if len(rows)%30==0:
        (ROOT/'build/story-gpu-samples.json').write_text(json.dumps({'device_total_mib':12288,'whole_device_not_process_only':True,'peak_mib':max(r['used_mib'] for r in rows),'samples':rows}),encoding='utf-8')
    time.sleep(1)
(ROOT/'build/story-gpu-samples.json').write_text(json.dumps({'device_total_mib':12288,'whole_device_not_process_only':True,'peak_mib':max(r['used_mib'] for r in rows),'samples':rows}),encoding='utf-8')
