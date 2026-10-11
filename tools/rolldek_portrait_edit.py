"""User-authorized Rolldek image edits. Credentials stay in ROLLDEK_API_KEY only.

No automatic POST retries: a timed-out request may already have been charged.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import io
import json
import os
import sys
import time
from urllib.parse import urlparse

from PIL import Image
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

ENDPOINT = "https://rolldek.com/v1/images/edits"
MODEL = "gpt-image-2.5-sunburst"

def download_generated(location):
    if urlparse(location).scheme!="https": raise RuntimeError("Expected HTTPS image download URL")
    # Downloads are idempotent; retries here never submit another paid generation.
    with requests.Session() as session:
        retry=Retry(total=3,connect=3,read=3,backoff_factor=1,allowed_methods=["GET"],status_forcelist=[502,503,504])
        session.mount("https://",HTTPAdapter(max_retries=retry))
        response=session.get(location,timeout=(30,180));response.raise_for_status()
        return response.content


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, action="append", required=True)
    parser.add_argument("--mask", type=Path)
    parser.add_argument("--prompt-file", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--transport", choices=["json", "multipart"], default="json")
    parser.add_argument("--quality", choices=["low", "medium", "high", "xhigh", "max", "auto"], default="max")
    args = parser.parse_args()
    key = os.environ.get("ROLLDEK_API_KEY", "")
    if not key:
        raise RuntimeError("Configure ROLLDEK_API_KEY in the calling environment.")
    if args.out.exists():
        raise FileExistsError("Existing output preserved: " + str(args.out))
    prompt = args.prompt_file.read_text(encoding="utf-8")
    if len(prompt) > 32000:
        raise ValueError("Prompt exceeds provider limit")
    payload = {"model": MODEL, "prompt": prompt, "size": "2160x3840",
               "quality": args.quality, "background": "transparent",
               "output_format": "png", "input_fidelity": "high"}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    request_record = {"endpoint": ENDPOINT, "request": payload,
                      "content_type": "application/json" if args.transport=="json" else "multipart/form-data",
                      "references": [str(p) for p in args.image],
                      "mask": str(args.mask) if args.mask else None}
    args.out.with_suffix(".request.json").write_text(
        json.dumps(request_record, ensure_ascii=False, indent=2), encoding="utf-8")
    # The user's channel explicitly requires n and response_format to be omitted.
    streams = []
    files = []
    start = time.monotonic()
    try:
        field = "image" if len(args.image) == 1 else "image[]"
        for source in args.image:
            stream = source.open("rb"); streams.append(stream)
            files.append((field, (source.name, stream, "image/png")))
        if args.mask:
            stream = args.mask.open("rb"); streams.append(stream)
            files.append(("mask", (args.mask.name, stream, "image/png")))
        if args.transport=="json":
            encoded = dict(payload)
            encoded["images"]=[{"image_url":"data:image/png;base64,"+base64.b64encode(p.read_bytes()).decode("ascii")} for p in args.image]
            if args.mask: encoded["mask"]={"image_url":"data:image/png;base64,"+base64.b64encode(args.mask.read_bytes()).decode("ascii")}
            response = requests.post(ENDPOINT, headers={"Authorization":"Bearer "+key},
                                     json=encoded, timeout=(30,900), allow_redirects=False)
        else:
            response = requests.post(ENDPOINT, headers={"Authorization": "Bearer " + key},
                                     data=payload, files=files, timeout=(30, 900),
                                     allow_redirects=False)
        if response.status_code != 200:
            # Report a bounded, redacted error; never dump response image data.
            try:
                error = response.json().get("error", {})
                message = error.get("message", str(error)) if isinstance(error, dict) else str(error)
            except ValueError:
                message = "Non-JSON provider error"
            raise RuntimeError(f"Provider HTTP {response.status_code}: " + message.replace(key, "[redacted]")[:500])
        result = response.json()
        # Even protocol failures need a reviewable sanitized response summary.
        summary = {"http_status": response.status_code,
                   "top_level_keys": list(result.keys()),
                   "fields": {k: result[k] for k in ["model", "quality", "size", "background", "output_format", "usage", "created"] if k in result},
                   "data_type": type(result.get("data")).__name__,
                   "data_entries": [list(e.keys()) if isinstance(e, dict) else type(e).__name__ for e in result.get("data", [])] if isinstance(result.get("data"), list) else None,
                   "error": str(result.get("error", "")).replace(key, "[redacted]")[:500]}
        args.out.with_suffix(".response-summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
        entries = result.get("data", [])
        if not isinstance(entries,list) or len(entries)!=1 or not isinstance(entries[0],dict):
            raise RuntimeError("Expected one image; inspect saved response summary")
        if entries[0].get("b64_json"):
            raw=base64.b64decode(entries[0]["b64_json"],validate=True)
        elif entries[0].get("url"):
            location=entries[0]["url"]
            # Generated asset retrieval; never forward the API key to an image host.
            args.out.with_suffix(".download.json").write_text(json.dumps({"url":location,"quality_requested":args.quality},indent=2),encoding="utf-8")
            raw=download_generated(location)
        else: raise RuntimeError("No image content; inspect saved response summary")
        with Image.open(io.BytesIO(raw)) as image:
            image.load()
            extent, mode = image.size, image.mode
            alpha = image.getchannel("A").getextrema() if "A" in image.getbands() else None
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_bytes(raw)
        record = {"provider": "Rolldek", "endpoint": ENDPOINT,
                  "documentation": "https://www.rolldek.com/docs/#/img25",
                  "model_requested": MODEL, "request": payload,
                  "references": [{"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in args.image],
                  "mask": str(args.mask) if args.mask else None,
                  "response": {k: result[k] for k in ["created", "background", "quality", "output_format", "size", "usage"] if k in result},
                  "quality_verified": result.get("quality")==args.quality,
                  "actual_size": list(extent), "mode": mode, "alpha_extrema": alpha,
                  "sha256": hashlib.sha256(raw).hexdigest(),
                  "seconds": round(time.monotonic() - start, 2)}
        args.out.with_suffix(".generation.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
        print(json.dumps({"output": str(args.out), "size": extent, "mode": mode,
                          "alpha": alpha, "seconds": record["seconds"]}, ensure_ascii=False), flush=True)
        if extent != (2160, 3840) or alpha is None or alpha[0] != 0 or alpha[1] < 200:
            raise RuntimeError("Saved for inspection, but 4K/transparency validation failed")
        if "quality" in result and result["quality"]!=args.quality:
            raise RuntimeError("Saved for inspection, but provider reported quality="+str(result["quality"])+" instead of "+args.quality)
    finally:
        for stream in streams:
            stream.close()


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Do not print tracebacks containing prepared Authorization headers.
        print(f"{type(error).__name__}: {error}", file=sys.stderr)
        sys.exit(1)
