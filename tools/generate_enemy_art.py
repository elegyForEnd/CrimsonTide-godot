"""Compatibility adapter for image APIs returning URLs instead of base64."""
import os, json, base64, concurrent.futures
from pathlib import Path
import requests
from PIL import Image

def generate(job):
    out=Path('output/imagegen')/job['out']
    response=requests.post(os.environ['OPENAI_BASE_URL'].rstrip('/')+'/images/generations',headers={'Authorization':'Bearer '+os.environ['OPENAI_API_KEY']},json={'model':'gpt-image-2.5-sunburst','prompt':job['prompt'],'size':'1536x1024','quality':'high','n':1,'response_format':'b64_json'},timeout=240)
    response.raise_for_status()
    payload=response.json()
    for item in payload.get('data',[]):
        if item.get('b64_json'):
            content=base64.b64decode(item['b64_json'])
        elif item.get('url'):
            download=requests.get(item['url'],timeout=120)
            download.raise_for_status()
            content=download.content
        else:
            raise RuntimeError('No usable image; returned fields: '+str(list(item)))
        out.write_bytes(content)
        with Image.open(out) as im:
            im.verify()
        print('Verified',out,flush=True)
        return
    raise RuntimeError('No image data; returned fields: '+str(list(payload)))

if __name__=='__main__':
    jobs=[json.loads(line) for line in Path('assets/enemies/generation-prompts.jsonl').read_text().splitlines() if line]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(generate,jobs))
