import json, time, copy, hashlib
from pathlib import Path
import urllib.request, urllib.parse, uuid
from PIL import Image

ROOT = Path('D:/develop/school/CrimsonTide-godot')
OUT = ROOT / 'output/comfyui-3x'
OUT.mkdir(parents=True, exist_ok=True)
API = 'http://127.0.0.1:8188'
def request(path, data=None, params=None, content_type='application/json', raw=False):
    url = API + path + ('?' + urllib.parse.urlencode(params) if params else '')
    body = json.dumps(data).encode() if isinstance(data, dict) else data
    req = urllib.request.Request(url, data=body, headers={'Content-Type':content_type})
    with urllib.request.urlopen(req, timeout=60) as resp:
        result = resp.read()
    return result if raw else json.loads(result)

def upload(src):
    boundary = uuid.uuid4().hex
    body = b''
    for key,value in {'subfolder':'CrimsonTide-final','overwrite':'false'}.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode()
    body += f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{src.name}"\r\nContent-Type: image/png\r\n\r\n'.encode() + src.read_bytes() + f'\r\n--{boundary}--\r\n'.encode()
    return request('/upload/image',data=body,content_type='multipart/form-data; boundary='+boundary)
workflow = json.loads(Path('C:/Users/wangk/Downloads/CrimsonTide-3x-api.json').read_text(encoding='utf-8'))
assets = json.loads((ROOT / 'output/rogue-final-night/artwork-audit.json').read_text(encoding='utf-8'))['assets']
workflow.pop('18', None)
(OUT / 'workflow-api.json').write_text(json.dumps(workflow, ensure_ascii=False, indent=2), encoding='utf-8')
records_path = OUT / 'results.json'
records = json.loads(records_path.read_text(encoding='utf-8')) if records_path.exists() else []
done = {r['texture'] for r in records}
for asset in assets:
    name = asset['texture']
    if name in done:
        continue
    src = ROOT / 'assets/rogue/regions' / name
    uploaded = upload(src)
    prompt = copy.deepcopy(workflow)
    prompt['2']['inputs']['image'] = uploaded['subfolder'] + '/' + uploaded['name']
    prompt['1']['inputs']['filename_prefix'] = 'CrimsonTide-3x/' + src.stem + '-3x'
    pid = request('/prompt', data={'prompt': prompt, 'client_id':'codex-crimsontide-3x'})['prompt_id']
    print(f'START {name} {pid}', flush=True)
    (OUT / 'current.json').write_text(json.dumps({'texture':name, 'prompt_id':pid}), encoding='utf-8')
    while True:
        history = request('/history/' + pid).get(pid)
        if history:
            if history.get('status',{}).get('status_str') == 'error':
                (OUT / 'error.json').write_text(json.dumps(history,ensure_ascii=False,indent=2),encoding='utf-8')
                raise RuntimeError(str(history['status']['messages'])[-6000:])
            images = history.get('outputs',{}).get('1',{}).get('images',[])
            if images:
                break
        time.sleep(4)
    data = request('/view', params=images[0],raw=True)
    target = OUT / (src.stem + '-3x.png')
    target.write_bytes(data)
    with Image.open(src) as im:
        source_size = im.size
    with Image.open(target) as im:
        size = im.size
    if any(abs(b-a*3)>16 for a,b in zip(source_size,size)):
        raise RuntimeError(f'Wrong output size: {source_size} -> {size}')
    record = {'texture':name,'source_size':source_size,'output':str(target),'size':size,'prompt_id':pid,'sha256':hashlib.sha256(data).hexdigest()}
    records.append(record)
    records_path.write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'DONE {len(records)}/50 {name} {size}',flush=True)
