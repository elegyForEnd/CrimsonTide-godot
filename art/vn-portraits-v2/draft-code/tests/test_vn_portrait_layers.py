"""Contract checks for actual blank bases and isolated facial components, no API calls."""
import hashlib,json,sys,unittest
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from build_vn_portraits import ASSETS,ART,HEROES,COSTUMES,POSES,EXPRESSIONS,compose

class Layers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.manifest=json.loads((ASSETS/"manifest.json").read_text())
    def test_complete_and_resolution_truthful(self):
        self.assertFalse(self.manifest["native_4k"])
        self.assertEqual(self.manifest["generator"],"built-in imagegen")
        count=0
        for hero in HEROES:
            entry=self.manifest["heroes"][hero];self.assertTrue(entry["ready"])
            self.assertEqual(len(entry["features"]),10)
            for costume in COSTUMES:
                self.assertEqual(set(entry["bases"][costume]),set(POSES))
                for pose in POSES:
                    base=entry["bases"][costume][pose]
                    with Image.open(ROOT/base["path"].removeprefix("res://")) as image:
                        self.assertEqual(image.size,(2160,3840));self.assertEqual(image.mode,"RGBA")
                        self.assertEqual(image.getchannel("A").getextrema()[0],0)
                    self.assertLess(max(base["source_size"]),3840);count+=1
        self.assertEqual(count,27)
    def test_independent_ink_layers(self):
        for hero in HEROES:
            for expression,features in self.manifest["heroes"][hero]["features"].items():
                self.assertEqual(set(features),{"eyes","mouth"})
                for kind,feature in features.items():
                    with self.subTest(hero=hero,expression=expression,kind=kind):
                        with Image.open(ROOT/feature["path"].removeprefix("res://")) as image:
                            alpha=np.asarray(image)[:,:,3]
                            self.assertEqual(int(alpha.min()),0)
                            self.assertGreater(int(alpha.max()),32)
                            if kind=="eyes":self.assertLess(float((alpha>100).mean()),.6)
                box=features["mouth"]["atlas_crop"]
                self.assertLess(box[2]-box[0],90)
    def test_body_and_head_never_change_with_expression(self):
        for hero in HEROES:
            for costume in COSTUMES:
                for pose in POSES:
                    base=self.manifest["heroes"][hero]["bases"][costume][pose]
                    with Image.open(ROOT/base["path"].removeprefix("res://")) as source:
                        body=np.asarray(source.convert("RGBA"))
                    image=compose(self.manifest,hero,costume,pose,"shy")
                    output=np.asarray(image)
                    excluded=np.zeros(body.shape[:2],dtype=bool)
                    for rect in base["rects"].values():
                        x,y,w,h=rect;excluded[y:y+h,x:x+w]=True
                    self.assertTrue(np.array_equal(body[~excluded],output[~excluded]),hero+costume+pose)
                    blank=compose(self.manifest,hero,costume,pose,"angry",blank=True)
                    self.assertTrue(np.array_equal(body,np.asarray(blank)))
    def test_subtle_and_shy_blush_are_independent(self):
        hero="feiyue";entry=self.manifest["heroes"][hero]
        with_blush=np.asarray(compose(self.manifest,hero,"regular","relaxed","neutral"))
        no_blush=np.asarray(compose(self.manifest,hero,"regular","relaxed","neutral",natural_blush=False))
        changed=np.any(with_blush!=no_blush,axis=2)
        self.assertGreater(int(changed.sum()),0)
        x,y,w,h=entry["bases"]["regular"]["relaxed"]["rects"]["blush"]
        outside=changed.copy();outside[y:y+h,x:x+w]=False;self.assertFalse(outside.any())
        for name in ["natural","shy"]:
            with Image.open(ASSETS/f"blush-{name}.png") as image:self.assertEqual(image.getchannel("A").getextrema()[0],0)
    def test_sources_retained_and_provenance(self):
        report=json.loads((ART/"build-report.json").read_text())
        self.assertEqual(report["missing"],[]);self.assertFalse(report["head_replacement"])
        for source in report["sources"]:
            path=ROOT/source["source"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),source["sha256"])

if __name__=="__main__":unittest.main()
