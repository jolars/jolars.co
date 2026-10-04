# jolars.co

<!-- badges: start -->
<!-- badges: end -->

My personal web site, built with Quarto.

## Markdown for agents

Quarto generates an `index.llms.md` file beside each rendered `index.html` page
and a matching `.llms.md` file beside other HTML pages. A Cloudflare Worker
serves those files when a client sends `Accept: text/markdown` to the page URL.
Browser requests continue to receive HTML.

The Worker source is in `workers/markdown-negotiation.mjs`, and its route is
configured in `wrangler.toml`. Run
`node --test workers/markdown-negotiation.test.mjs` to check the routing logic.
Deploy Worker changes with `wrangler deploy`.
