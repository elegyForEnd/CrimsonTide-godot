"""Read-only local .idx / BLTE / TVFS inspection, including installations missing ENCODING.

Only metadata is committed. Raw scene JSON stays under ignored output/casc-research.
Format cross-check: upstream CascLib/src/CascRootFile_TVFS.cpp and CascIndexFiles.cpp.
"""
from pathlib import Path
import collections, hashlib, json, struct, zlib
ROOT=Path(__file__).resolve().parents[1]
GAME=Path('F:/game/D2R')

def blte(data):
    at=data.find(b'BLTE',0,64)
    if at<0: raise ValueError('BLTE header missing')
    data=data[at:]; head=int.from_bytes(data[4:8],'big')
    def chunk(part):
        if part[:1]==b'Z': return zlib.decompress(part[1:])
        if part[:1]==b'N': return part[1:]
        raise ValueError('unsupported BLTE mode '+repr(part[:1]))
    if head==0: return chunk(data[8:])
    count=int.from_bytes(data[9:12],'big'); parts=[]; pos=head
    for i in range(count):
        size,plain=struct.unpack_from('>II',data,12+i*24)
        part=data[pos:pos+size]
        assert hashlib.md5(part).digest()==data[20+i*24:36+i*24], 'BLTE checksum'
        decoded=chunk(part); assert len(decoded)==plain
        parts.append(decoded); pos+=size
    return b''.join(parts)

class Storage:
    def __init__(self):
        self.index={}; self.files={}
        latest={p.name[:2]:p for p in sorted((GAME/'data/data').glob('*.idx'))}
        for p in latest.values():
            data=p.read_bytes(); total=int.from_bytes(data[32:36],'little')
            assert data[12:16]==bytes([4,5,9,30]), 'unexpected index format'
            for i in range(40,40+total,18):
                key=data[i:i+9]
                off=int.from_bytes(data[i+9:i+14],'big'); size=int.from_bytes(data[i+14:i+18],'little')
                self.index[key]=(off>>30,off&((1<<30)-1),size)
    def read_key(self,key):
        archive,off,size=self.index[key[:9]]
        with (GAME/f'data/data/data.{archive:03d}').open('rb') as f:
            f.seek(off); return blte(f.read(size))
    def tree(self,data,prefix=''):
        assert data[:4]==b'TVFS'
        po,ps,vo,vs,co,cs=struct.unpack_from('>6I',data,12)
        offsize=max(1,((cs-1).bit_length()+7)//8)
        def nodes(start,end,base):
            p=start; path=base
            while p<end:
                pre=data[p]==0
                if pre:p+=1; path+='/'
                if data[p]!=255:
                    length=data[p];p+=1;path+=data[p:p+length].decode();p+=length
                if p<end and data[p]==0:path+='/';p+=1
                if p<end and data[p]==255:
                    value=int.from_bytes(data[p+1:p+5],'big');p+=5
                    if value&0x80000000:
                        stop=p+(value&0x7fffffff)-4;nodes(p,stop,path);p=stop
                    else:
                        entry=vo+value;count=data[entry];entry+=1; spans=[]
                        for _ in range(count):
                            offset,length=struct.unpack_from('>II',data,entry)
                            cft=int.from_bytes(data[entry+8:entry+8+offsize],'big')
                            key=data[co+cft:co+cft+data[6]]
                            spans.append((key,offset,length));entry+=8+offsize
                        name=path.strip('/')
                        self.files[name]=spans
                        if len(spans)==1 and spans[0][0].hex().startswith('26214c7b302e6cb1ca'):
                            self.tree(self.read_key(spans[0][0]),name+'/')
                    path=base
                elif p<end: path+='/'
        nodes(po,po+ps,prefix)
    def read(self,name):
        return b''.join(self.read_key(key)[offset:offset+length] for key,offset,length in self.files[name])

def main():
    storage=Storage(); storage.tree(storage.read_key(bytes.fromhex('db906148ec59f5d1f89ac240dd6bd12f')))
    names=list(storage.files); scenes=[n for n in names if 'hd/env/preset/' in n.lower() and n.lower().endswith('.json')]
    report={'root':str(GAME),'build':'69270','index_entries':len(storage.index),'file_count':len(names),'scene_count':len(scenes),
            'extensions':dict(collections.Counter(Path(n).suffix.lower() for n in names)),'scenes':{},'errors':[]}
    out=ROOT/'output/casc-research'; out.mkdir(exist_ok=True)
    (out/'scene-names.txt').write_text('\n'.join(scenes),encoding='utf8')
    chosen=[]
    for act in range(1,6):
        for category in [('town','docktown'),('bridge',),('grave',),('down','up')]:
            matches=[n for n in scenes if f'/act{act}/' in n.lower() and any(t in n.lower() for t in category)]
            chosen.extend(matches[:3])
    chosen=list(dict.fromkeys(chosen))
    for name in chosen:
        try:
            data=storage.read(name); scene=json.loads(data); types=collections.Counter(); assets=set(); transforms=[]; component_samples={}; heights=[]
            def walk(node):
                if isinstance(node,dict):
                    for k,v in node.items():
                        if k.lower() in ('type','componenttype','class') and isinstance(v,str): types[v]+=1
                        if isinstance(v,str) and any(x in v.lower() for x in ('.model','.texture','.gr2','.material')):assets.add(v)
                        if k.lower() in ('transform','position','translation') and len(transforms)<5:transforms.append({k:v})
                        walk(v)
                    kind=node.get('type')
                    if kind in ('WallTransparencyComponent','ModelDefinitionComponent','TerrainStampDefinitionComponent','PhysicsBoxDefinition') and kind not in component_samples:component_samples[kind]=node
                    if kind=='TransformDefinitionComponent':heights.append(node.get('position',{}).get('y',0))
                elif isinstance(node,list):
                    for v in node:walk(v)
            walk(scene)
            report['scenes'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'top_keys':list(scene) if isinstance(scene,dict) else [],'entity_count':len(scene.get('entities',[])),'types':dict(types),'asset_count':len(assets),'assets':sorted(assets)[:25],'transform_samples':transforms,'component_samples':component_samples,'local_height_range':[min(heights),max(heights)] if heights else [],'nonzero_local_height_count':sum(y!=0 for y in heights)}
            (out/f'scene-{len(report["scenes"])}.json').write_bytes(data)
        except Exception as e:report['errors'].append(f'{name}: {e}')
    (ROOT/'docs/rpg/d2r-scene-inspection.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'files':len(names),'scenes':len(scenes),'samples':len(report['scenes']),'errors':report['errors']},ensure_ascii=False))

if __name__=='__main__':main()
