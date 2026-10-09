#!/usr/bin/env python3
"""Check a rendered site served by the Cloudflare Worker."""

import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import HTTPRedirectHandler, Request, build_opener


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--url", default="https://jolars.co", help="Site origin to check."
    )
    parser.add_argument(
        "--www-url", help="Optional www origin whose redirect should be checked."
    )
    args = parser.parse_args()
    base = args.url.rstrip("/") + "/"
    opener = build_opener(NoRedirect())

    def check(path, *, method="GET", accept="text/html", status=200, origin=base):
        url = urljoin(origin.rstrip("/") + "/", path.lstrip("/"))
        request = Request(
            url,
            method=method,
            headers={
                "Accept": accept,
                "User-Agent": "jolars.co deployment check",
            },
        )
        try:
            response = opener.open(request, timeout=30)
        except HTTPError as error:
            response = error
        with response:
            require(
                response.status == status,
                f"{method} {url}: expected {status}, got {response.status}",
            )
            require(
                not response.headers.get("x-github-request-id"),
                f"{url}: still served by GitHub Pages",
            )
            body = response.read()
            headers = response.headers
        print(f"OK {method} {url} ({status})")
        return headers, body

    for path in ["/", "/index.html", "/blog/", "/blog/index.html", "/news/index.html"]:
        headers, body = check(path)
        require(headers.get_content_type() == "text/html", f"{path}: expected HTML")
        require(b"<html" in body.lower(), f"{path}: empty HTML page")
        require(
            "accept"
            in {part.strip().lower() for part in headers.get("Vary", "").split(",")},
            f"{path}: missing Vary: Accept",
        )
        if path == "/":
            require(
                "api-catalog" in headers.get("Link", ""),
                "Homepage: missing discovery links",
            )

    for method in ["GET", "HEAD"]:
        headers, body = check("/", method=method, accept="text/markdown")
        require(
            headers.get_content_type() == "text/markdown", "Homepage: expected Markdown"
        )
        require(
            int(headers.get("x-markdown-tokens", "0")) > 0,
            "Homepage: missing Markdown token count",
        )
        require(
            not body if method == "HEAD" else b"# " in body,
            "Homepage: unexpected Markdown body",
        )
        headers, body = check("/", method=method, accept="text/markdown;q=0")
        require(
            headers.get_content_type() == "text/html", "Homepage: q=0 must return HTML"
        )
        if method == "HEAD":
            require(not body, "HEAD returned a body")

    headers, _ = check("/blog?category=rust", status=301)
    require(
        headers.get("Location") == urljoin(base, "blog/?category=rust"),
        "Directory: incorrect redirect",
    )
    for path in ["/.well-known/api-catalog", "/.well-known/markdown-service.json"]:
        _, body = check(path, accept="application/json")
        require(
            isinstance(json.loads(body), dict), f"{path}: invalid discovery document"
        )
    for path in [
        "/llms.txt",
        "/sitemap.xml",
        "/blog/index.xml",
        "/styles.css",
        "/.well-known/funding-manifest-urls",
    ]:
        _, body = check(path, accept="*/*")
        require(bool(body), f"{path}: empty asset")
    for path in [
        "/deployment-check-missing",
        "/deployment-check-missing/",
        "/deployment-check-missing.html",
    ]:
        check(path, status=404)
    if args.www_url:
        headers, _ = check(
            "/blog/index.html?category=rust", status=301, origin=args.www_url
        )
        require(
            headers.get("Location")
            == "https://jolars.co/blog/index.html?category=rust",
            "www: incorrect redirect",
        )
    print("Deployment checks passed.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, URLError, ValueError) as error:
        print(f"Deployment check failed: {error}", file=sys.stderr)
        sys.exit(1)
