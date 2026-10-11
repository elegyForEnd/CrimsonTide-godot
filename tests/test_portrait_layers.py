"""Asset acceptance checks against generated source geometry, without API calls."""
from pathlib import Path
import json
import unittest
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art/story-portraits"

class PortraitLayers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest=json.loads((ROOT/"assets/story/portraits/manifest.json").read_text(encoding="utf-8"))

    def test_all_120_combinations_have_native_sources(self):
        self.assertEqual(len(self.manifest["heroes"]),3)
        self.assertEqual(len(self.manifest["expressions"]),10)
        self.assertEqual(len(self.manifest["costumes"]),4)
        for hero,entry in self.manifest["heroes"].items():
            with self.subTest(hero=hero):
                self.assertTrue(entry["ready"])
                self.assertEqual(len(entry["bodies"]),4);self.assertEqual(len(entry["faces"]),9)
                for path in entry["bodies"].values():
                    with Image.open(ROOT/path.removeprefix("res://")) as im: self.assertEqual(im.size,(2160,3840));self.assertEqual(im.mode,"RGBA")
                for path in entry["faces"].values():
                    with Image.open(ROOT/path.removeprefix("res://")) as im: self.assertEqual(im.size,tuple(entry["face_rect"][2:]))

    def test_expression_does_not_change_body_or_ground_anchor(self):
        for hero,entry in self.manifest["heroes"].items():
            base=np.asarray(Image.open(ART/"exports"/hero/"regular-neutral.png"))
            x,y,w,h=entry["face_rect"]
            mask=np.ones(base.shape[:2],dtype=bool);mask[y:y+h,x:x+w]=False
            signatures=[]
            for expression in self.manifest["expressions"]:
                with self.subTest(hero=hero,expression=expression):
                    image=np.asarray(Image.open(ART/"exports"/hero/f"regular-{expression}.png"))
                    self.assertTrue(np.array_equal(base[mask],image[mask]))
                    signatures.append(image[y:y+h,x:x+w,:3].tobytes())
            self.assertEqual(len(set(signatures)),10)

    def test_clothing_keeps_head_and_feet(self):
        for hero,entry in self.manifest["heroes"].items():
            base=np.asarray(Image.open(ROOT/entry["bodies"]["regular"].removeprefix("res://")))
            bottom=np.where(base[:,:,3]>200)[0].max();head_end=entry["face_rect"][1]+entry["face_rect"][3]+12
            for costume,path in entry["bodies"].items():
                with self.subTest(hero=hero,costume=costume):
                    im=np.asarray(Image.open(ROOT/path.removeprefix("res://")))
                    self.assertEqual(np.where(im[:,:,3]>200)[0].max(),bottom)
                    self.assertTrue(np.array_equal(im[:head_end],base[:head_end]))

    def test_provenance_uses_max_and_original_4k(self):
        for hero,entry in self.manifest["heroes"].items():
            names=[f"{hero}-{c}-neutral" for c in self.manifest["costumes"]]+[f"{hero}-regular-{e}" for e in entry["faces"]]
            for name in names:
                with self.subTest(source=name):
                    data=json.loads((ART/"masters"/(name+".generation.json")).read_text(encoding="utf-8"))
                    self.assertEqual(data["request"]["quality"],"max")
                    self.assertEqual(data["request"]["model"],"gpt-image-2.5-sunburst")
                    self.assertEqual(data["actual_size"],[2160,3840])
                    self.assertNotIn("n",data["request"]);self.assertNotIn("response_format",data["request"])

    def test_registered_eyes_match_neutral_face(self):
        report=json.loads((ART/"layer-build-report.json").read_text(encoding="utf-8"))
        count=0
        for entry in report["items"]:
            if "registration" not in entry:continue
            registration=entry["registration"]
            source=np.column_stack([registration["source_eyes"],np.ones(2)])
            mapped=source@np.asarray(registration["matrix"]).T
            self.assertLess(np.abs(mapped-np.asarray(registration["target_eyes"])).max(),.1)
            count+=1
        self.assertEqual(count,27)

if __name__=="__main__":unittest.main()
