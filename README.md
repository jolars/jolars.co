# jolars.co

My personal web site, built with Quarto.

## Development

Run commands from the repository root in `devenv shell`. The environment
provides Quarto, the computational dependencies, Node.js, and Wrangler.

Workers tooling uses a separate Nixpkgs pin so its local runtime can support the
production compatibility date without changing computational dependencies.

```bash
task preview        # Preview Quarto content with live reload.
task check          # Render the site, lint SEO metadata, and check links.
task worker-test    # Test the Cloudflare Worker.
task worker-preview # Serve the rendered _site/ through the Worker locally.
```

To check the local Worker, run
`python3 scripts/check-deployment.py --url http://localhost:8787` in another
shell. Render the site before starting the Worker preview.

## Publishing

GitHub Actions builds the site with Nix/devenv and publishes `_site/` to
Cloudflare Workers on pushes to `main` and manual workflow dispatches. The
Worker serves the static site, handles Markdown content negotiation, and
redirects `www.jolars.co` to `jolars.co`.

The publishing workflow needs repository secrets `CLOUDFLARE_ACCOUNT_ID` and
`CLOUDFLARE_API_TOKEN`. Scope the token to the site's Cloudflare account with
Workers Editor access, Workers Routes Write for the `jolars.co` zone, and Zone
Read access for Wrangler's zone lookup. Custom Domains currently require Workers
access at the product scope. See [Cloudflare's permissions
documentation](https://developers.cloudflare.com/workers/authorization/workers/).

For a local deployment, authenticate with `wrangler login`, then run
`task deploy`. This renders the site, tests the Worker, deploys it, and checks
the live endpoints. SEO and link checks are advisory in CI, while Worker tests
and deployment checks must pass. After deployment checks pass, CI submits the
sitemap to IndexNow and runs Lighthouse.

Deployment checks retry up to six times, ten seconds apart, to allow the new
Worker version to propagate. A persistent failure stops the publishing job.

`wrangler.toml` defines the asset binding, Custom Domains, and observability.
The Worker preserves Quarto's `.html` links and directory URLs. Requests with
`Accept: text/markdown` receive the rendered `.llms.md` counterpart when one
exists. Missing pages return 404.
