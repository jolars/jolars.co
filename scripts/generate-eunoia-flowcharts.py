#!/usr/bin/env python3
"""Regenerate the article's static flowcharts with Quarto's Mermaid and Chromium.

Run from the repository root: devenv shell -- python scripts/generate-eunoia-flowcharts.py
"""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

quarto_share = Path(subprocess.check_output(["quarto", "--paths"], text=True).splitlines()[1])
mermaid = quarto_share / "formats/html/mermaid/mermaid.min.js"
chromium = shutil.which("chromium")
if not chromium:
    raise SystemExit("Chromium is missing. Run this script in devenv shell.")
images = Path(__file__).resolve().parent.parent / "blog/2026-07-04-eunoia/images"

for source in sorted(images.glob("*.mmd")):
    with tempfile.TemporaryDirectory(prefix="eunoia-flowchart-") as directory:
        temporary = Path(directory)
        shutil.copyfile(mermaid, temporary / "mermaid.js")
        page = temporary / "index.html"
        page.write_text(
            '<!doctype html><html><head><meta charset="utf-8"></head><body>'
            '<script src="mermaid.js"></script><script>'
            'mermaid.initialize({startOnLoad: false});'
            f'mermaid.render("flowchart", {json.dumps(source.read_text())})'
            '.then(({svg}) => {document.body.innerHTML = svg;});'
            '</script></body></html>'
        )
        result = subprocess.run(
            [chromium, "--headless", "--no-sandbox", "--disable-gpu",
             f"--user-data-dir={temporary / 'profile'}", "--dump-dom",
             "--virtual-time-budget=5000", page.as_uri()],
            capture_output=True, text=True, check=True, timeout=30,
        )
        match = re.search(r"<svg\b.*?</svg>", result.stdout, re.DOTALL)
        if not match or '<text' not in match.group(0):
            raise SystemExit(f"Chromium did not render {source.name}: {result.stderr}")
        target = source.with_suffix(".svg")
        target.write_text(match.group(0) + "\n")
        print(f"Generated {target.relative_to(images.parent)}")
