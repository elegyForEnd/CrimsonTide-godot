"""Verify independently generated portraits, provenance and whole-image exports."""
from pathlib import Path
import hashlib,json,sys,unittest
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tools"))
from build_vn_full_portraits import ART,ASSETS,HEROES,COSTUMES,POSES,EXPRESSIONS,fit_whole
class FullPortraits(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.jobs=json.loads((ART/"jobs.json").read_text(encoding="utf-8"))["jobs"]
        cls.manifest=json.loads((ASSETS/"manifest.json").read_text(encoding="utf-8"))
    def test_216_independent_full_sources(self):
        self.assertEqual(len(self.jobs),216);hashes=set();pixel_hashes=set()
        for job in self.jobs:
            path=ROOT/job["output"]
            with self.subTest(job=job["id"]):
                self.assertTrue(path.exists());meta=json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
                self.assertTrue(meta["whole_portrait"]);self.assertFalse(meta["facial_compositing"])
                digest=hashlib.sha256(path.read_bytes()).hexdigest();self.assertEqual(digest,meta["sha256"]);hashes.add(digest)
                with Image.open(path) as image:
                    self.assertEqual(list(image.size),meta["resolution"])
                    self.assertEqual(image.mode,"RGBA");self.assertEqual(image.getchannel("A").getextrema()[0],0)
                    self.assertEqual(meta["native_4k"],image.size==(2160,3840))
                    pixels=np.asarray(image).copy();pixels[pixels[:,:,3]==0,:3]=0
                    pixel_hashes.add(hashlib.sha256(pixels.tobytes()).hexdigest())
        self.assertEqual(len(hashes),216,"Every combination must originate from its own generation")
        self.assertEqual(len(pixel_hashes),216,"PNG provenance differences alone cannot stand in for distinct pictures")
    def test_exact_three_by_three_by_eight_manifest(self):
        self.assertTrue(self.manifest["complete"]);self.assertTrue(self.manifest["whole_portraits"]);self.assertFalse(self.manifest["facial_compositing"])
        paths=set()
        for hero in HEROES:
            entry=self.manifest["heroes"][hero];self.assertTrue(entry["ready"])
            self.assertEqual(set(entry["portraits"]),set(COSTUMES))
            for costume in COSTUMES:
                self.assertEqual(set(entry["portraits"][costume]),set(POSES))
                for pose in POSES:
                    pictures=entry["portraits"][costume][pose];self.assertEqual(set(pictures),set(EXPRESSIONS))
                    paths.update(pictures.values())
        self.assertEqual(len(paths),216)
    def test_canvas_and_transparency(self):
        for job in self.jobs:
            path=ASSETS/job["hero"]/(job["id"]+".png")
            with Image.open(path) as image:
                self.assertEqual(image.size,(2160,3840));self.assertEqual(image.getchannel("A").getextrema()[0],0)
    def test_export_is_only_whole_image_resize_and_padding(self):
        # One representative of every hero/costume/pose combination, pixel exact.
        for job in self.jobs:
            if job["expression"]!="neutral":continue
            with Image.open(ROOT/job["output"]) as source:
                expected,_=fit_whole(source.convert("RGBA"))
            with Image.open(ASSETS/job["hero"]/(job["id"]+".png")) as output:
                self.assertTrue(np.array_equal(np.asarray(expected),np.asarray(output)),job["id"])
    def test_all_prompts_recorded_and_match(self):
        for job in self.jobs:
            text=(ART/"prompts"/(job["id"]+".txt")).read_text(encoding="utf-8")
            self.assertEqual(text,job["prompt"])
            meta=json.loads((ROOT/job["output"]).with_suffix(".json").read_text(encoding="utf-8"))
            self.assertEqual(meta["prompt_sha256"],hashlib.sha256(text.encode()).hexdigest())
if __name__=="__main__":unittest.main()
