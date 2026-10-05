"""Save one Rolldek GPT Image edit, accepting either base64 or URL responses.

The API key must be supplied through OPENAI_API_KEY. This script never stores it.
Each invocation generates exactly one animation frame from ordered input images.
"""

from __future__ import annotations

import argparse
import base64
from contextlib import ExitStack
from io import BytesIO
import os
from pathlib import Path
from urllib.parse import urlparse

import httpx
from openai import APIError, OpenAI
from PIL import Image


def response_shape(value: object) -> object:
    """Show response structure without logging image data or signed URLs."""
    if isinstance(value, dict):
        return {key: response_shape(item) for key, item in value.items()}
    if isinstance(value, list):
        return [response_shape(item) for item in value[:2]]
    if isinstance(value, str):
        return f"str({len(value)})"
    return type(value).__name__


def image_bytes(item: dict) -> bytes:
    encoded = item.get("b64_json") or item.get("b64")
    if isinstance(encoded, str) and encoded:
        return base64.b64decode(encoded)

    url = item.get("url") or item.get("image_url")
    if isinstance(url, str) and url:
        if url.startswith("data:image/") and ";base64," in url:
            return base64.b64decode(url.split(",", 1)[1])
        parsed = urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname:
            raise ValueError("Image URL must use HTTPS")
        response = httpx.get(url, follow_redirects=True, timeout=120)
        response.raise_for_status()
        if len(response.content) > 50_000_000:
            raise ValueError("Image response exceeds 50 MB")
        return response.content

    raise ValueError(f"No image payload in response: {response_shape(item)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", type=Path, action="append", required=True)
    parser.add_argument("--prompt-file", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--model", default="gpt-image-2.5-sunburst")
    parser.add_argument("--size", default="1024x1024")
    parser.add_argument("--quality", default="medium")
    args = parser.parse_args()

    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("OPENAI_API_KEY is missing")
    if args.out.exists():
        raise SystemExit(f"Output already exists: {args.out}")
    prompt = args.prompt_file.read_text(encoding="utf-8")
    client = OpenAI(base_url=os.getenv("OPENAI_BASE_URL", "https://rolldek.com/v1"), timeout=120, max_retries=0)
    try:
        with ExitStack() as stack:
            files = [stack.enter_context(path.open("rb")) for path in args.image]
            print("API_REQUEST", flush=True)
            result = client.images.edit(
                model=args.model,
                image=files,
                prompt=prompt,
                n=1,
                size=args.size,
                quality=args.quality,
                background="transparent",
                output_format="png",
            )
        print("API_RESPONSE", flush=True)
    except APIError as error:
        raise SystemExit(f"API_ERROR {type(error).__name__}: {error}") from None
    data = result.model_dump(exclude_none=True)
    items = data.get("data") or []
    if not items:
        raise ValueError(f"No data in response: {response_shape(data)}")
    raw = image_bytes(items[0])
    with Image.open(BytesIO(raw)) as opened:
        opened.load()
        image = opened.convert("RGBA")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] == 255:
        rejected = args.out.with_name(args.out.stem + "-opaque.png")
        rejected.parent.mkdir(parents=True, exist_ok=True)
        image.save(rejected)
        raise ValueError(f"API image lacked transparency; inspection copy: {rejected}")
    box = alpha.point(lambda value: 255 if value > 24 else 0).getbbox()
    if box is None:
        raise ValueError("API returned an empty transparent image")
    margin = min(box[0], box[1], image.width - box[2], image.height - box[3])
    if margin < 3:
        rejected = args.out.with_name(args.out.stem + "-clipped.png")
        rejected.parent.mkdir(parents=True, exist_ok=True)
        image.save(rejected)
        raise ValueError(f"Subject touches canvas edge; inspection copy: {rejected}")
    if margin < 32:
        smaller = image.resize((round(image.width * 0.9), round(image.height * 0.9)), Image.Resampling.LANCZOS)
        padded = Image.new("RGBA", image.size)
        padded.alpha_composite(smaller, ((image.width - smaller.width) // 2, (image.height - smaller.height) // 2))
        image = padded
    args.out.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.out)
    print(f"Saved {args.out} ({image.width}x{image.height}, RGBA)")


if __name__ == "__main__":
    main()
