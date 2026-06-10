#!/usr/bin/env python3
"""SEO and content lint checks for the site.

This complements `lychee` (which checks for broken links). It looks at the
kind of metadata problems that Google Search Console and Bing Webmaster Tools
surface, but does so locally against the rendered site and the source files.

Two layers are checked:

  1. Source frontmatter (``*.qmd``)  -- required fields and referenced image
     files. Fast, runs without a build.
  2. Rendered HTML (``_site``)       -- what actually ships to search engines:
     title and description length, missing/duplicate descriptions, canonical
     tags, Open Graph images, image alt text, and heading structure.

Only the Python standard library is used.

Exit codes:
    0  clean, or warnings only (unless --strict)
    1  one or more errors (or warnings with --strict)
    2  usage / environment error
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path

# --- thresholds -----------------------------------------------------------

# The rendered <title> includes the " – Johan Larsson" site suffix, so the
# upper bound accounts for that. Google truncates titles around 60 characters.
# The lower bound is generous so the brand-name homepage isn't flagged.
TITLE_MAX = 65
TITLE_MIN = 10

# Google shows roughly 150-160 characters of the meta description. Bing
# Webmaster Tools flags descriptions shorter than ~100 characters as "too
# short", so the lower bound is set above that to catch them proactively.
DESC_MIN = 110
DESC_MAX = 160

# Files under _site that are not content pages worth auditing.
SKIP_HTML = re.compile(r"/site_libs/")

# Blog posts get the strictest frontmatter requirements.
BLOG_GLOB = "blog/*/index.qmd"


# --- finding model --------------------------------------------------------

ERROR = "error"
WARNING = "warning"

SEVERITY_RANK = {ERROR: 0, WARNING: 1}


@dataclass
class Finding:
    severity: str
    where: str
    message: str


@dataclass
class Report:
    findings: list[Finding] = field(default_factory=list)

    def add(self, severity: str, where: str, message: str) -> None:
        self.findings.append(Finding(severity, where, message))

    def error(self, where: str, message: str) -> None:
        self.add(ERROR, where, message)

    def warn(self, where: str, message: str) -> None:
        self.add(WARNING, where, message)

    @property
    def n_errors(self) -> int:
        return sum(1 for f in self.findings if f.severity == ERROR)

    @property
    def n_warnings(self) -> int:
        return sum(1 for f in self.findings if f.severity == WARNING)


# --- rendered HTML parsing ------------------------------------------------


class HeadExtractor(HTMLParser):
    """Pull the SEO-relevant bits out of a rendered page."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._title_parts: list[str] = []
        self._in_title = False
        self.meta: dict[str, str] = {}
        self.canonical: str | None = None
        self.html_lang: str | None = None
        self.h1_count = 0
        self.is_listing = False
        # (src, has_alt) for non-decorative <img> elements.
        self.imgs: list[tuple[str, bool]] = []

    def handle_starttag(self, tag, attrs):
        a = {k.lower(): (v or "") for k, v in attrs}
        if "quarto-listing" in a.get("class", ""):
            self.is_listing = True
        if tag == "title":
            self._in_title = True
        elif tag == "html":
            self.html_lang = a.get("lang")
        elif tag == "meta":
            key = a.get("name") or a.get("property")
            if key:
                self.meta.setdefault(key.lower(), a.get("content", ""))
        elif tag == "link":
            if a.get("rel", "").lower() == "canonical":
                self.canonical = a.get("href")
        elif tag == "h1":
            self.h1_count += 1
        elif tag == "img":
            src = a.get("src", "")
            if src.startswith("data:") or SKIP_HTML.search("/" + src):
                return
            self.imgs.append((src, "alt" in a))

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False

    def handle_data(self, data):
        if self._in_title:
            self._title_parts.append(data)

    @property
    def title(self) -> str:
        return "".join(self._title_parts).strip()


def page_url(path: Path, site_dir: Path) -> str:
    """Friendly relative URL for a rendered file."""
    rel = path.relative_to(site_dir).as_posix()
    rel = re.sub(r"(^|/)index\.html$", r"\1", rel)
    return "/" + rel


def check_rendered(site_dir: Path, report: Report) -> None:
    html_files = sorted(
        p
        for p in site_dir.rglob("*.html")
        if not SKIP_HTML.search("/" + p.relative_to(site_dir).as_posix())
    )
    if not html_files:
        report.error(
            str(site_dir),
            "no rendered HTML found -- run `quarto render` first",
        )
        return

    titles: dict[str, list[str]] = defaultdict(list)
    descriptions: dict[str, list[str]] = defaultdict(list)

    for path in html_files:
        url = page_url(path, site_dir)
        parser = HeadExtractor()
        try:
            parser.feed(path.read_text(encoding="utf-8", errors="replace"))
        except Exception as exc:  # noqa: BLE001 - report and continue
            report.error(url, f"could not parse HTML: {exc}")
            continue

        # Quarto emits lightweight redirect stubs (e.g. for moved pages) with
        # this exact title; they carry no real content, so skip them.
        if parser.title == "Redirect":
            continue

        # Title.
        title = parser.title
        if not title:
            report.error(url, "missing <title>")
        else:
            titles[title].append(url)
            n = len(title)
            if n > TITLE_MAX:
                report.warn(
                    url,
                    f"title is {n} chars (>{TITLE_MAX}); may be truncated in results",
                )
            elif n < TITLE_MIN:
                report.warn(url, f"title is only {n} chars (<{TITLE_MIN})")

        # Meta description.
        desc = parser.meta.get("description", "").strip()
        if not desc:
            report.warn(url, "missing meta description")
        else:
            descriptions[desc].append(url)
            n = len(desc)
            if n > DESC_MAX:
                report.warn(
                    url,
                    f"description is {n} chars (>{DESC_MAX}); will be truncated",
                )
            elif n < DESC_MIN:
                report.warn(url, f"description is only {n} chars (<{DESC_MIN})")

        # Canonical + Open Graph image (Quarto usually supplies both).
        if not parser.canonical:
            report.warn(url, "missing rel=canonical link")
        if not parser.meta.get("og:image"):
            report.warn(url, "missing og:image (no social preview image)")

        # Headings.
        if parser.h1_count == 0:
            report.warn(url, "no <h1> heading on page")
        elif parser.h1_count > 1:
            report.warn(url, f"{parser.h1_count} <h1> headings (expected 1)")

        # Image alt text (decorative images use the empty alt="" and are fine;
        # only a missing alt attribute is flagged). Listing pages are skipped
        # because their thumbnails are templated by Quarto, not authored here.
        if not parser.is_listing:
            for src, has_alt in parser.imgs:
                if not has_alt:
                    report.warn(url, f"<img> without alt attribute: {src}")

    # Duplicates across the whole site.
    for title, urls in titles.items():
        if len(urls) > 1:
            report.warn(
                ", ".join(urls),
                f"duplicate <title>: {title!r}",
            )
    for desc, urls in descriptions.items():
        if len(urls) > 1:
            short = desc if len(desc) <= 60 else desc[:57] + "..."
            report.warn(
                ", ".join(urls),
                f"duplicate meta description ({short!r})",
            )


# --- source frontmatter parsing -------------------------------------------

FM_BOUND = re.compile(r"^---\s*$")


def read_frontmatter(path: Path) -> tuple[dict[str, str], int]:
    """Return a shallow {key: raw_value} map for the YAML frontmatter.

    This is deliberately tiny -- it only needs to know which top-level keys are
    present and the literal value of single-line keys like ``image``. The line
    number of the opening fence is returned for nicer reporting.
    """
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines or not FM_BOUND.match(lines[0]):
        return {}, 0
    fm: dict[str, str] = {}
    for line in lines[1:]:
        if FM_BOUND.match(line):
            break
        m = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return fm, 1


def strip_quotes(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
        return value[1:-1]
    return value


def check_frontmatter(root: Path, report: Report) -> None:
    qmd_files = sorted(
        p
        for p in root.rglob("*.qmd")
        if "_site" not in p.parts and "_freeze" not in p.parts
    )
    blog_posts = {p.resolve() for p in root.glob(BLOG_GLOB)}

    for path in qmd_files:
        fm, _ = read_frontmatter(path)
        where = str(path.relative_to(root))
        if not fm:
            continue  # not a frontmatter document (e.g. an include)

        # The value may legitimately sit on the next line (block scalar or a
        # wrapped string), so only the key's presence is required here; an
        # actually-empty rendered <title> is caught by the rendered-HTML pass.
        if "title" not in fm:
            report.error(where, "frontmatter missing a title")

        is_blog = path.resolve() in blog_posts
        if is_blog:
            for key in ("description", "date", "categories", "image"):
                if key not in fm:
                    report.warn(where, f"blog post missing `{key}` in frontmatter")

        # Referenced image must exist on disk.
        if fm.get("image"):
            img = strip_quotes(fm["image"])
            if img and not img.startswith(("http://", "https://", "data:")):
                target = (path.parent / img).resolve()
                if not target.exists():
                    report.error(where, f"image file not found: {img}")


# --- output ---------------------------------------------------------------


def render_report(report: Report, *, markdown: bool) -> None:
    by_severity = sorted(
        report.findings, key=lambda f: (SEVERITY_RANK[f.severity], f.where)
    )
    icon = {ERROR: "❌", WARNING: "⚠️"}

    if markdown:
        print("## SEO & content lint\n")
        if not by_severity:
            print("All checks passed. ✅")
        else:
            print(f"**{report.n_errors} errors, {report.n_warnings} warnings**\n")
            for f in by_severity:
                print(f"- {icon[f.severity]} `{f.where}` — {f.message}")
        print()
        return

    if not by_severity:
        print("seo-lint: all checks passed ✅")
        return
    for f in by_severity:
        print(f"{icon[f.severity]} {f.severity.upper()}  {f.where}\n    {f.message}")
    print(
        f"\nseo-lint: {report.n_errors} error(s), {report.n_warnings} warning(s)"
    )


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "--site", default="_site", help="rendered site directory (default: _site)"
    )
    ap.add_argument(
        "--root", default=".", help="project root for source checks (default: .)"
    )
    ap.add_argument(
        "--strict", action="store_true", help="exit non-zero on warnings too"
    )
    ap.add_argument(
        "--markdown",
        action="store_true",
        help="emit a Markdown summary (for GitHub step summaries)",
    )
    ap.add_argument(
        "--no-rendered", action="store_true", help="skip the rendered _site checks"
    )
    ap.add_argument(
        "--no-source", action="store_true", help="skip the source frontmatter checks"
    )
    args = ap.parse_args(argv)

    report = Report()

    if not args.no_source:
        root = Path(args.root)
        if not root.is_dir():
            print(f"seo-lint: root not found: {root}", file=sys.stderr)
            return 2
        check_frontmatter(root, report)

    if not args.no_rendered:
        site = Path(args.site)
        if not site.is_dir():
            print(
                f"seo-lint: site dir not found: {site} (run `quarto render`)",
                file=sys.stderr,
            )
            return 2
        check_rendered(site, report)

    render_report(report, markdown=args.markdown)

    if report.n_errors:
        return 1
    if args.strict and report.n_warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
