#!/usr/bin/env python3
"""Trim unused math dependencies and resize rendered listing thumbnails."""

import hashlib
import html
import os
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlsplit


class_math = re.compile(r'class=[\"\'][^\"\']*\bmath\b[^\"\']*[\"\']')
math_loader = re.compile(
    r'<script>window\.backupDefine = window\.define;.*?'
    r'<link rel="stylesheet" href="https://cdn\.jsdelivr\.net/npm/katex[^\"]*">',
    re.DOTALL,
)
image_tag = re.compile(r'<img\b[^>]*>', re.IGNORECASE)
source_attr = re.compile(r'\bsrc="([^\"]+)"')


def optimize(output):
    output = output.resolve()
    thumbnails = output / 'assets' / 'thumbnails'
    cache = {}
    saved = 0
    trimmed = 0
    for page in output.rglob('*.html'):
        original = page.read_text()
        content = original
        # Quarto emits the KaTeX loader even on pages without math nodes.
        if not class_math.search(content):
            content, count = math_loader.subn('', content)
            trimmed += count

        def thumbnail(match):
            nonlocal saved
            tag = match.group()
            if not re.search(r'class="[^\"]*\bthumbnail-image\b', tag):
                return tag
            attr = source_attr.search(tag)
            if not attr:
                return tag
            url = urlsplit(html.unescape(attr[1]))
            if url.scheme or url.netloc:
                return tag
            source = (output / unquote(url.path).lstrip('/') if url.path.startswith('/')
                      else page.parent / unquote(url.path)).resolve()
            if not source.is_relative_to(output) or not source.is_file():
                return tag
            # Keep vector diagrams sharp, and avoid converting generated files again.
            if source.suffix.lower() not in {'.png', '.jpg', '.jpeg'}:
                return tag
            if source not in cache:
                digest = hashlib.sha256(source.read_bytes()).hexdigest()[:20]
                target = thumbnails / f'{digest}.webp'
                thumbnails.mkdir(parents=True, exist_ok=True)
                if not target.exists():
                    subprocess.run([
                        'magick', str(source), '-auto-orient', '-resize', '480x480>',
                        '-strip', '-quality', '80', str(target),
                    ], check=True)
                # A small original can be cheaper than its WebP conversion.
                cache[source] = target if target.stat().st_size < source.stat().st_size else source
                saved += source.stat().st_size - cache[source].stat().st_size
            target = cache[source]
            relative = Path(os.path.relpath(target, page.parent)).as_posix()
            return tag[:attr.start(1)] + relative + tag[attr.end(1):]

        content = image_tag.sub(thumbnail, content)
        if content != original:
            page.write_text(content)
    print(f'Assets: removed {trimmed} unused KaTeX loaders; '
          f'thumbnails save {saved / 1024:.0f} KiB across {len(cache)} images.')


if __name__ == '__main__':
    optimize(Path(os.environ.get('QUARTO_PROJECT_OUTPUT_DIR', '_site')))
