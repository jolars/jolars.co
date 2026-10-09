import assert from "node:assert/strict";
import test from "node:test";

import worker, { handleRequest } from "./markdown-negotiation.mjs";

const page = "https://jolars.co/blog/example/";

function origin(paths) {
  const fetched = [];
  const fetcher = async (request) => {
    const url = typeof request === "string" ? request : request.url;
    fetched.push(url);
    return paths[url] ?? new Response("Missing", { status: 404 });
  };
  return { fetcher, fetched };
}

test("serves Quarto Markdown at the browser URL when requested", async () => {
  const { fetcher, fetched } = origin({
    "https://jolars.co/blog/example/index.llms.md": new Response("# Example\n\nContent.", {
      headers: { "content-type": "text/markdown; charset=utf-8", "cache-control": "max-age=600" },
    }),
  });
  const response = await handleRequest(
    new Request(page, { headers: { accept: "text/html, text/markdown;q=0.8" } }),
    fetcher,
  );

  assert.deepEqual(fetched, ["https://jolars.co/blog/example/index.llms.md"]);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-type"), "text/markdown; charset=utf-8");
  assert.equal(response.headers.get("vary"), "Accept");
  assert.equal(response.headers.get("cache-control"), "max-age=600");
  assert.ok(Number(response.headers.get("x-markdown-tokens")) > 0);
  assert.equal(await response.text(), "# Example\n\nContent.");
});

test("keeps HTML as the default and marks it as varying by Accept", async () => {
  const { fetcher, fetched } = origin({
    [page]: new Response("<html>Example</html>", {
      headers: { "content-type": "text/html", vary: "Accept-Encoding" },
    }),
  });
  const response = await handleRequest(new Request(page), fetcher);

  assert.deepEqual(fetched, [page]);
  assert.equal(response.headers.get("content-type"), "text/html");
  assert.equal(response.headers.get("vary"), "Accept-Encoding, Accept");
  assert.equal(await response.text(), "<html>Example</html>");
});

test("honors q=0 and leaves assets alone", async () => {
  const { fetcher, fetched } = origin({
    [page]: new Response("<html>Example</html>", { headers: { "content-type": "text/html" } }),
    "https://jolars.co/styles.css": new Response("body{}", { headers: { "content-type": "text/css" } }),
  });
  await handleRequest(new Request(page, { headers: { accept: "text/markdown;q=0" } }), fetcher);
  const asset = await handleRequest(
    new Request("https://jolars.co/styles.css", { headers: { accept: "text/markdown" } }),
    fetcher,
  );

  assert.deepEqual(fetched, [page, "https://jolars.co/styles.css"]);
  assert.equal(asset.headers.get("vary"), null);
});

test("maps root and .html pages to their Markdown counterparts", async () => {
  const { fetcher, fetched } = origin({
    "https://jolars.co/index.llms.md": new Response("# Home", { headers: { "content-type": "text/markdown" } }),
    "https://jolars.co/news/item.llms.md": new Response("# News", { headers: { "content-type": "text/markdown" } }),
  });
  await handleRequest(new Request("https://jolars.co/", { headers: { accept: "text/markdown" } }), fetcher);
  await handleRequest(new Request("https://jolars.co/news/item.html", { headers: { accept: "text/markdown" } }), fetcher);

  assert.deepEqual(fetched, [
    "https://jolars.co/index.llms.md",
    "https://jolars.co/news/item.llms.md",
  ]);
});

test("falls back to the original page if a Markdown file is missing", async () => {
  const { fetcher, fetched } = origin({
    [page]: new Response("<html>Example</html>", { headers: { "content-type": "text/html" } }),
  });
  const response = await handleRequest(
    new Request(page, { headers: { accept: "text/markdown" } }),
    fetcher,
  );

  assert.deepEqual(fetched, ["https://jolars.co/blog/example/index.llms.md", page]);
  assert.equal(response.headers.get("content-type"), "text/html");
  assert.equal(response.headers.get("vary"), "Accept");
});

test("returns headers without a body for HEAD requests", async () => {
  const { fetcher } = origin({
    "https://jolars.co/index.llms.md": new Response("# Home", { headers: { "content-type": "text/markdown" } }),
  });
  const response = await handleRequest(
    new Request("https://jolars.co/", { method: "HEAD", headers: { accept: "text/markdown" } }),
    fetcher,
  );

  assert.equal(response.headers.get("content-type"), "text/markdown");
  assert.equal(await response.text(), "");
});

function site(paths) {
  const fetched = [];
  const ASSETS = {
    async fetch(request) {
      assert.equal(this, ASSETS);
      fetched.push(request);
      const response = paths[new URL(request.url).pathname]?.clone() ?? new Response("Missing", { status: 404 });
      return request.method === "HEAD"
        ? new Response(null, { status: response.status, headers: response.headers })
        : response;
    },
  };
  return { env: { ASSETS }, fetched };
}

test("serves root, directory, and explicit HTML URLs through the asset binding", async () => {
  const { env, fetched } = site({
    "/index.html": new Response("<html>Home</html>", { headers: { "content-type": "text/html" } }),
    "/blog/example/index.html": new Response("<html>Example</html>", { headers: { "content-type": "text/html" } }),
    "/news/item.html": new Response("<html>News</html>", { headers: { "content-type": "text/html" } }),
  });
  for (const path of ["/", "/blog/example/", "/blog/example/index.html", "/news/item.html"]) {
    const response = await worker.fetch(new Request(`https://jolars.co${path}?view=full`), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get("location"), null);
    assert.equal(response.headers.get("vary"), "Accept");
    if (path === "/") assert.match(response.headers.get("link"), /api-catalog/);
  }
  assert.deepEqual(fetched.map((request) => new URL(request.url).pathname), [
    "/index.html", "/blog/example/index.html", "/blog/example/index.html", "/news/item.html",
  ]);
  assert.ok(fetched.every((request) => new URL(request.url).search === "?view=full"));
});

test("serves extensionless files and redirects bare directories with query strings", async () => {
  const { env } = site({
    "/news/item.html": new Response("<html>News</html>", { headers: { "content-type": "text/html" } }),
    "/blog/index.html": new Response("<html>Blog</html>", { headers: { "content-type": "text/html" } }),
    "/.well-known/funding-manifest-urls": new Response("https://example.com/funding.json"),
  });
  const file = await worker.fetch(new Request("https://jolars.co/news/item?view=full"), env);
  assert.equal(file.status, 200);
  assert.equal(await file.text(), "<html>News</html>");
  const directory = await worker.fetch(new Request("https://jolars.co/blog?category=rust"), env);
  assert.equal(directory.status, 301);
  assert.equal(directory.headers.get("location"), "https://jolars.co/blog/?category=rust");
  const exact = await worker.fetch(new Request("https://jolars.co/.well-known/funding-manifest-urls"), env);
  assert.equal(await exact.text(), "https://example.com/funding.json");
});

test("serves Markdown from assets, removes validators, and preserves HEAD behavior", async () => {
  const { env } = site({
    "/index.llms.md": new Response("# Home", {
      headers: { "content-type": "text/markdown", etag: '"markdown"', "last-modified": "Wed, 07 Oct 2026 00:00:00 GMT" },
    }),
    "/index.html": new Response("<html>Home</html>", { headers: { "content-type": "text/html" } }),
  });
  for (const method of ["GET", "HEAD"]) {
    const response = await worker.fetch(new Request("https://jolars.co/", {
      method, headers: { accept: "text/markdown" },
    }), env);
    assert.equal(response.headers.get("content-type"), "text/markdown");
    assert.equal(response.headers.get("vary"), "Accept");
    assert.equal(response.headers.get("etag"), null);
    assert.equal(response.headers.get("last-modified"), null);
    assert.ok(Number(response.headers.get("x-markdown-tokens")) > 0);
    assert.equal(await response.text(), method === "HEAD" ? "" : "# Home");
  }
  const html = await worker.fetch(new Request("https://jolars.co/", {
    method: "HEAD", headers: { accept: "text/markdown;q=0" },
  }), env);
  assert.equal(html.headers.get("content-type"), "text/html");
  assert.equal(await html.text(), "");
});

test("falls back to HTML assets and keeps missing pages as 404", async () => {
  const { env } = site({
    "/blog/example/index.html": new Response("<html>Example</html>", { headers: { "content-type": "text/html" } }),
  });
  const fallback = await worker.fetch(new Request(page, { headers: { accept: "text/markdown" } }), env);
  assert.equal(fallback.status, 200);
  assert.equal(fallback.headers.get("content-type"), "text/html");
  for (const path of ["/missing", "/missing/", "/missing.html"]) {
    const response = await worker.fetch(new Request(`https://jolars.co${path}`), env);
    assert.equal(response.status, 404);
    assert.equal(response.headers.get("location"), null);
  }
});

test("preserves binary ranges and passes unsupported methods to assets", async () => {
  const bytes = new Uint8Array([0, 97, 115, 109]);
  const { env, fetched } = site({
    "/app.wasm": new Response(bytes, {
      status: 206, headers: { "content-type": "application/wasm", "content-range": "bytes 0-3/8", etag: '"wasm"' },
    }),
  });
  const request = new Request("https://jolars.co/app.wasm", {
    headers: { range: "bytes=0-3", accept: "text/markdown" },
  });
  const response = await worker.fetch(request, env);
  assert.equal(fetched[0], request);
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("content-range"), "bytes 0-3/8");
  assert.equal(response.headers.get("etag"), '"wasm"');
  assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);

  const post = new Request(page, { method: "POST", body: "content" });
  await worker.fetch(post, env);
  assert.equal(fetched.at(-1), post);
});

test("redirects www to HTTPS on the canonical host before accessing assets", async () => {
  const response = await worker.fetch(new Request("http://www.jolars.co/news/item.html?view=full"), {});
  assert.equal(response.status, 301);
  assert.equal(response.headers.get("location"), "https://jolars.co/news/item.html?view=full");
});

test("serves discovery endpoints for GET and HEAD without fetching assets", async () => {
  for (const path of ["/.well-known/api-catalog", "/.well-known/markdown-service.json"]) {
    for (const method of ["GET", "HEAD"]) {
      const response = await worker.fetch(new Request(`https://jolars.co${path}`, { method }), {});
      assert.equal(response.status, 200);
      if (method === "HEAD") assert.equal(await response.text(), "");
      else assert.ok(await response.json());
    }
  }
});
