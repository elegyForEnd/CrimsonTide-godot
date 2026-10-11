"""Offline contract checks; these tests never contact the paid API."""
import base64
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("portrait_edit",ROOT/"tools/rolldek_portrait_edit.py")
edit=importlib.util.module_from_spec(spec); spec.loader.exec_module(edit)


class Response:
    status_code=200
    def __init__(self, data): self.data=data
    def json(self): return self.data


class PortraitContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        im=Image.new("RGBA",(2160,3840),(0,0,0,0))
        ImageDraw.Draw(im).rectangle((500,200,1600,3600),fill=(220,200,190,255))
        buf=io.BytesIO(); im.save(buf,format="PNG"); cls.raw=buf.getvalue()

    def fixture(self, folder):
        source=Path(folder)/"reference.png"; source.write_bytes(self.raw)
        prompt=Path(folder)/"prompt.txt"; prompt.write_text("Keep identity; edit face only",encoding="utf-8")
        out=Path(folder)/"result.png"
        argv=["edit","--image",str(source),"--prompt-file",str(prompt),"--out",str(out)]
        return argv,out

    def reply(self, **extra):
        return Response({"data":[{"b64_json":base64.b64encode(self.raw).decode()}],"quality":"max",**extra})

    def test_json_max_contract(self):
        with tempfile.TemporaryDirectory() as folder:
            argv,out=self.fixture(folder)
            with patch.dict(os.environ,{"ROLLDEK_API_KEY":"fake-test-key"}),patch("sys.argv",argv),patch.object(edit.requests,"post",return_value=self.reply()) as post:
                edit.main()
            request=post.call_args.kwargs
            self.assertEqual(request["json"]["quality"],"max")
            self.assertEqual(request["json"]["size"],"2160x3840")
            self.assertEqual(request["json"]["background"],"transparent")
            self.assertEqual(request["json"]["model"],"gpt-image-2.5-sunburst")
            self.assertNotIn("n",request["json"]); self.assertNotIn("response_format",request["json"])
            self.assertTrue(request["json"]["images"][0]["image_url"].startswith("data:image/png;base64,"))
            record=json.loads(out.with_suffix(".generation.json").read_text(encoding="utf-8"))
            self.assertTrue(record["quality_verified"])
            for artifact in Path(folder).glob("*.json"):
                self.assertNotIn("fake-test-key",artifact.read_text(encoding="utf-8"))

    def test_standard_is_rejected_and_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            argv,out=self.fixture(folder)
            with patch.dict(os.environ,{"ROLLDEK_API_KEY":"fake-test-key"}),patch("sys.argv",argv),patch.object(edit.requests,"post",return_value=self.reply(quality="standard")):
                with self.assertRaisesRegex(RuntimeError,"instead of max"): edit.main()
            self.assertTrue(out.exists())
            self.assertFalse(json.loads(out.with_suffix(".generation.json").read_text(encoding="utf-8"))["quality_verified"])

    def test_multipart_also_sends_max(self):
        with tempfile.TemporaryDirectory() as folder:
            argv,out=self.fixture(folder); argv += ["--transport","multipart"]
            with patch.dict(os.environ,{"ROLLDEK_API_KEY":"fake-test-key"}),patch("sys.argv",argv),patch.object(edit.requests,"post",return_value=self.reply()) as post:
                edit.main()
            self.assertEqual(post.call_args.kwargs["data"]["quality"],"max")
            self.assertNotIn("n",post.call_args.kwargs["data"])
            self.assertNotIn("response_format",post.call_args.kwargs["data"])

    def test_high_trial_changes_only_quality(self):
        with tempfile.TemporaryDirectory() as folder:
            argv,out=self.fixture(folder); argv += ["--quality","high"]
            with patch.dict(os.environ,{"ROLLDEK_API_KEY":"fake-test-key"}),patch("sys.argv",argv),patch.object(edit.requests,"post",return_value=self.reply(quality="high")) as post:
                edit.main()
            request=post.call_args.kwargs["json"]
            self.assertEqual(request["quality"],"high")
            self.assertEqual(request["size"],"2160x3840")
            self.assertEqual(request["model"],"gpt-image-2.5-sunburst")
            self.assertEqual(request["input_fidelity"],"high")
            self.assertTrue(json.loads(out.with_suffix(".generation.json").read_text(encoding="utf-8"))["quality_verified"])

    def test_invalid_response_retains_diagnostic(self):
        with tempfile.TemporaryDirectory() as folder:
            argv,out=self.fixture(folder)
            with patch.dict(os.environ,{"ROLLDEK_API_KEY":"fake-test-key"}),patch("sys.argv",argv),patch.object(edit.requests,"post",return_value=Response({"error":{"message":"upstream failed"}})):
                with self.assertRaisesRegex(RuntimeError,"Expected one image"): edit.main()
            self.assertFalse(out.exists()); self.assertTrue(out.with_suffix(".response-summary.json").exists())

    def test_existing_asset_preserved_without_request(self):
        with tempfile.TemporaryDirectory() as folder:
            argv,out=self.fixture(folder); out.write_bytes(b"keep-original")
            with patch.dict(os.environ,{"ROLLDEK_API_KEY":"fake-test-key"}),patch("sys.argv",argv),patch.object(edit.requests,"post") as post:
                with self.assertRaises(FileExistsError): edit.main()
            post.assert_not_called(); self.assertEqual(out.read_bytes(),b"keep-original")


if __name__=="__main__": unittest.main()
