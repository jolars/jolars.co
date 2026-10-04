import assert from "node:assert/strict";
import test from "node:test";

import { handleRequest } from "./markdown-negotiation.mjs";

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
