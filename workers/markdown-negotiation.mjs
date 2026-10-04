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

async function fetchOriginal(request, fetcher) {
  const response = await fetcher(request);
  if (!response.headers.get("content-type")?.toLowerCase().startsWith("text/html")) {
    return response;
  }
  const headers = new Headers(response.headers);
  addVaryAccept(headers);
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export async function handleRequest(request, fetcher = fetch) {
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

export default {
  fetch(request) {
    return handleRequest(request);
  },
};
