"""Pinned Poly Haven CC0 vegetation sources; no executable downloads."""
import pathlib,json,hashlib,concurrent.futures
from fetch_story_pbr import request
ROOT=pathlib.Path(__file__).resolve().parents[1]
base=ROOT/'art/story-environment/vendor'; base.mkdir(exist_ok=True)
assets=[]
for slug in ['tree_small_02','fern_02']:
    data=json.loads(request('https://api.polyhaven.com/files/'+slug)); info=json.loads(request('https://api.polyhaven.com/info/'+slug))
    entry=data['gltf']['2k']['gltf']; target=base/slug; target.mkdir(exist_ok=True)
    files={slug+'.gltf':entry,**entry['include']}
    def download(item):
        name,source=item; dest=target/name; dest.parent.mkdir(parents=True,exist_ok=True)
        if not dest.exists() or hashlib.md5(dest.read_bytes()).hexdigest()!=source['md5']:
            content=request(source['url']); assert hashlib.md5(content).hexdigest()==source['md5']; dest.write_bytes(content)
        return {'file':str(dest.relative_to(ROOT)).replace('\\','/'),'url':source['url'],'md5':source['md5'],'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'bytes':dest.stat().st_size}
    with concurrent.futures.ThreadPoolExecutor(4) as pool: records=list(pool.map(download,files.items()))
    assets.append({'slug':slug,'page':'https://polyhaven.com/a/'+slug,'license':'CC0-1.0','authors':info.get('authors',{}),'files':records})
    print('DOWNLOADED',slug,flush=True)
(ROOT/'assets/story/environment/vegetation-sources.json').write_text(json.dumps({'license_page':'https://polyhaven.com/license','assets':assets},indent=2,ensure_ascii=False),encoding='utf-8')
