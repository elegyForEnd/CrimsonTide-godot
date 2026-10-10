"""Check exported GLB winding on CLOSED connected components, after UV splitting.

The regression this catches: a mirrored coordinate conversion silently exports
inside-out rock blocks. Checking a render test's exit code alone cannot catch it.
"""
import collections
import json
import pathlib
import struct

ROOT=pathlib.Path(__file__).resolve().parents[1]


def read_glb(path):
    data=path.read_bytes()
    assert data[:4]==b'glTF'
    length=struct.unpack_from('<I',data,12)[0]
    doc=json.loads(data[20:20+length])
    binary=data[28+length:]
    def accessor(index):
        item=doc['accessors'][index]; view=doc['bufferViews'][item['bufferView']]
        fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[item['componentType']]
        count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[item['type']]
        unpack=struct.Struct('<'+fmt*count)
        stride=view.get('byteStride',unpack.size)
        offset=view.get('byteOffset',0)+item.get('byteOffset',0)
        return [unpack.unpack_from(binary,offset+i*stride) for i in range(item['count'])]
    return doc,accessor


def main():
    checks=0
    for path in sorted((ROOT/'assets/story/environment/models').glob('*.glb')):
        if path.stem in ['woodland_tree','woodland_fern']:
            print(path.stem+': licensed open foliage; validated separately in render tests')
            continue
        doc,accessor=read_glb(path)
        verts=[]; faces=[]; welded={}
        for m in doc['meshes']:
            for p in m['primitives']:
                assert p.get('mode',4)==4
                positions=accessor(p['attributes']['POSITION'])
                normals=accessor(p['attributes']['NORMAL'])
                assert all(.98<sum(c*c for c in n)<1.02 for n in normals)
                remap=[]
                for v in positions:
                    key=tuple(round(c,5) for c in v)
                    if key not in welded: welded[key]=len(verts); verts.append(v)
                    remap.append(welded[key])
                indices=[x[0] for x in accessor(p['indices'])]
                faces.extend(tuple(remap[k] for k in indices[i:i+3]) for i in range(0,len(indices),3))
        edges=collections.defaultdict(list)
        for i,f in enumerate(faces):
            for a,b in zip(f,f[1:]+f[:1]): edges[tuple(sorted((a,b)))].append(i)
        neighbours=collections.defaultdict(set)
        for group in edges.values():
            for i in group: neighbours[i].update(group)
        unseen=set(range(len(faces))); closed=0; opened=0
        while unseen:
            start=unseen.pop(); component={start}; queue=[start]
            while queue:
                for n in neighbours[queue.pop()]:
                    if n in unseen: unseen.remove(n); component.add(n); queue.append(n)
            is_closed=all(len(edges[tuple(sorted((a,b)))])==2 for i in component
                          for a,b in zip(faces[i],faces[i][1:]+faces[i][:1]))
            if not is_closed: opened+=1; continue
            closed+=1
            volume=0
            for i in component:
                a,b,c=(verts[j] for j in faces[i])
                volume+=(a[0]*(b[1]*c[2]-b[2]*c[1])+a[1]*(b[2]*c[0]-b[0]*c[2])+a[2]*(b[0]*c[1]-b[1]*c[0]))/6
            assert volume>1e-9,(path.name,'inside-out component',volume)
            checks+=1
        if path.stem not in ['grass_tuft']: assert closed>0,(path.name,'no closed solids')
        print(f'{path.stem}: {closed} closed outward components, {opened} open panels')
    print(f'story mesh winding: {checks} checks, 0 failures')


if __name__=='__main__': main()
