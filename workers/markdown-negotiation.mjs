function acceptsMarkdown(header) {
  return (header ?? "").split(",").some((range) => {
    const [type, ...parameters] = range.trim().split(";");
    if (type.trim().toLowerCase() !== "text/markdown") return false;
    const quality = parameters
      .map((parameter) => parameter.trim().match(/^q\s*=\s*([0-9.]+)$/i))
      .find(Boolean);
    return !quality || Number(quality[1]) > 0;
  });
}

function markdownPath(path) {
  if (path === "/software/qualpalr/" || path === "/software/qualpalr/index.html") {
    return "/software/qualpal/index.llms.md";
  }
  if (path.endsWith("/")) return `${path}index.llms.md`;
  if (path.endsWith(".html")) return path.replace(/\.html$/, ".llms.md");
  if (!path.split("/").at(-1).includes(".")) return `${path}/index.llms.md`;
  return null;
}

function addVaryAccept(headers) {
  const vary = headers.get("vary");
  if (!vary) headers.set("vary", "Accept");
  else if (!vary.split(",").some((part) => part.trim().toLowerCase() === "accept")) {
    headers.set("vary", `${vary}, Accept`);
  }
}

function addDiscoveryLinks(headers) {
  headers.append("link", '</.well-known/api-catalog>; rel="api-catalog"');
  headers.append('link', '</.well-known/markdown-service.json>; rel="service-desc"; type="application/json"');
  headers.append('link', '</>; rel="service-doc"; type="text/html"');
  headers.append('link', '</llms.txt>; rel="describedby"; type="text/plain"');
}

function apiCatalogResponse(request) {
  const headers = new Headers({
    "content-type": 'application/linkset+json; profile="https://www.rfc-editor.org/info/rfc9727"',
    "cache-control": "public, max-age=3600",
  });
  headers.append("link", '</.well-known/api-catalog>; rel="api-catalog"');
  const body = JSON.stringify({
    linkset: [{
      anchor: "https://jolars.co/",
      item: [{ href: "https://jolars.co/", title: "Homepage content negotiation endpoint" }],
      "service-desc": [{ href: "https://jolars.co/.well-known/markdown-service.json", type: "application/json" }],
      "service-doc": [{ href: "https://jolars.co/", type: "text/html" }],
    }],
  });
  return new Response(request.method === "HEAD" ? null : body, { headers });
}

async function fetchOriginal(request, fetcher) {
  const response = await fetcher(request);
  if (!response.headers.get("content-type")?.toLowerCase().startsWith("text/html")) {
    return response;
  }
  const headers = new Headers(response.headers);
  addVaryAccept(headers);
  if (new URL(request.url).pathname === "/" && response.status === 200) {
    addDiscoveryLinks(headers);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export async function handleRequest(request, fetcher) {
  if (
    (request.method === "GET" || request.method === "HEAD") &&
    new URL(request.url).pathname === "/.well-known/markdown-service.json"
  ) {
    const body = JSON.stringify({
      name: "Johan Larsson's website content negotiation",
      endpoint: "https://jolars.co/",
      method: "GET",
      requestHeader: "Accept: text/markdown",
      responseMediaType: "text/markdown",
      documentation: "https://jolars.co/",
    });
    return new Response(request.method === "HEAD" ? null : body, {
      headers: { "content-type": "application/json; charset=utf-8", "cache-control": "public, max-age=3600" },
    });
  }

  if (
    (request.method === "GET" || request.method === "HEAD") &&
    new URL(request.url).pathname === "/.well-known/api-catalog"
  ) {
    return apiCatalogResponse(request);
  }

  if (
    (request.method !== "GET" && request.method !== "HEAD") ||
    !acceptsMarkdown(request.headers.get("accept"))
  ) {
    return fetchOriginal(request, fetcher);
  }

  const url = new URL(request.url);
  const path = markdownPath(url.pathname);
  if (!path) return fetchOriginal(request, fetcher);

  url.pathname = path;
  url.search = "";
  const markdown = await fetcher(new Request(url, { headers: { accept: "text/markdown" } }));
  if (
    markdown.status !== 200 ||
    !markdown.headers.get("content-type")?.toLowerCase().startsWith("text/markdown")
  ) {
    return fetchOriginal(request, fetcher);
  }

  const body = await markdown.text();
  const headers = new Headers(markdown.headers);
  // The response is served at the HTML URL, so its validators must not describe the HTML page.
  for (const name of ["content-length", "content-encoding", "etag", "last-modified"]) {
    headers.delete(name);
  }
  addVaryAccept(headers);
  headers.set("x-markdown-tokens", String(Math.ceil(new TextEncoder().encode(body).length / 4)));
  return new Response(request.method === "HEAD" ? null : body, { status: 200, headers });
}

async function fetchAsset(request, assets) {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return assets.fetch(request);
  }

  const url = new URL(request.url);
  // Quarto links to .html files, so resolve indexes without redirecting those links.
  if (url.pathname.endsWith("/")) {
    url.pathname += "index.html";
    return assets.fetch(new Request(url, request));
  }

  const response = await assets.fetch(request);
  if (response.status !== 404 || url.pathname.split("/").at(-1).includes(".")) {
    return response;
  }

  const file = new URL(url);
  file.pathname += ".html";
  const html = await assets.fetch(new Request(file, request));
  if (html.status !== 404) return html;

  const index = new URL(url);
  index.pathname += "/index.html";
  const directory = await assets.fetch(new Request(index, { method: "HEAD" }));
  if (directory.status === 200) {
    url.pathname += "/";
    return Response.redirect(url.href, 301);
  }
  return response;
}

export default {
  fetch(request, env) {
    const url = new URL(request.url);
    let redirect = false;
    if (url.hostname === "www.jolars.co") {
      url.protocol = "https:";
      url.host = "jolars.co";
      redirect = true;
    }

    // Move published URLs before content negotiation, including linked assets.
    const oldPost = "/blog/2026-10-09-panache-an-editor-companion-for-pandoc";
    const newPost = "/blog/2026-10-09-panache-an-editor-companion-for-markdown";
    if (url.pathname === oldPost || url.pathname.startsWith(`${oldPost}/`)) {
      url.pathname = newPost + (url.pathname.slice(oldPost.length) || "/");
      redirect = true;
    }
    if (redirect) return Response.redirect(url.href, 301);

    return handleRequest(request, (assetRequest) => fetchAsset(assetRequest, env.ASSETS));
  },
};
