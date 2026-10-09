# Agent instructions for jolars.co

## Project Overview

This is Johan Larsson's personal website, built with Quarto. It includes a blog,
news, software projects, publications, talks, and a CV. Content is primarily in
`.qmd` files, with R, Python, and occasional Julia computations. A Cloudflare
Worker in `workers/` serves the rendered site through Workers Static Assets,
handles Markdown content negotiation, and redirects the www hostname.

## Environment and Commands

Always run Quarto from the repository root.

The project uses Nix and devenv. Run `devenv shell` to enter the environment, or
prefix a command with `devenv shell --`, as CI does. The environment provides
Quarto, Pandoc, LaTeX, R, Python, Julia, Node.js, Wrangler, and site validation
tools.

```bash
# Render the entire site.
quarto render

# Preview the site with live reload.
quarto preview

# Render a specific post. This executes its code by default.
quarto render blog/2024-05-30-moloch/index.qmd
```

Rendered output goes to `_site/`, which is git-ignored.

Define dependencies in `devenv.nix`: R packages in the `rWrapper` package list,
Python packages in `pythonEnv`, and other tools in `packages`. Nix inputs and
their pins live in `devenv.yaml` and `devenv.lock`. After changing dependencies,
reenter `devenv shell` and render to validate them. Local builds and the
publishing workflow use the same devenv configuration.

## Computational Outputs

The project uses `freeze: auto` in `_quarto.yml` and `blog/_metadata.yml`.
Quarto stores computational outputs in the committed `_freeze/` directory.

- During a full project render, Quarto reuses frozen outputs when the source
  file has not changed. Any source change, including prose or frontmatter, can
  trigger execution.
- Single-file and subdirectory renders execute code by default. Use
  `--use-freezer` when intentionally reusing frozen computations for an
  incremental render.
- Changes outside the source file, such as input data or dependencies, may
  require an explicit single-file render to refresh the affected outputs.
- Review and commit generated `_freeze/` changes. Never edit them manually, and
  do not change the project's freeze settings.

See [Quarto's freeze
documentation](https://quarto.org/docs/projects/code-execution.html#freeze).

## Validation

For site content and configuration changes:

1. Run `quarto render` and resolve build errors.
2. Use `quarto preview` to inspect affected pages when appearance or interaction
   changes.
3. Run `task seo` to check source frontmatter and rendered SEO metadata with
   `scripts/seo-lint.py`. The script uses only Python's standard library.
4. Run `task links` to check internal and external links in `_site/` with
   lychee, configured in `lychee.toml`. This requires a rendered site and
   network access for external links.

`task check` renders the site and runs the SEO and link checks sequentially.
Locally, a failed command stops the task. In CI, SEO and link checks are
advisory and do not block deployment. SEO lint exits nonzero on errors, or on
warnings with `--strict`. Duplicate title warnings between a paper and its
matching talk are expected.

Quarto content has no unit test suite. For changes to the Worker, run its
existing tests in devenv:

```bash
devenv shell -- task worker-test
```

After rendering, use `task worker-preview` to serve `_site/` through Wrangler
locally. In another devenv shell, run
`python3 scripts/check-deployment.py --url http://localhost:8787` to check
routing, content negotiation, discovery endpoints, and static assets. Before
deployment, run `wrangler deploy --dry-run`. `task deploy` renders, tests,
deploys, and checks the production site.

Preserve existing tests, formatting hooks, and CI checks. Avoid unnecessary new
test frameworks or CI infrastructure for this small site.

## Continuous Integration

`.github/workflows/publish.yml` runs on pushes to `main` and manual dispatch. It
installs Nix and devenv, configures Cachix, restores Git timestamps, and renders
with `devenv shell -- quarto render`. It runs advisory SEO lint and lychee
checks, tests the Worker, and deploys with `devenv shell -- wrangler deploy`.
Repository secrets `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`
authenticate the deployment. It checks production endpoints before submitting
the sitemap to IndexNow and running Lighthouse.

`.github/workflows/lint.yml` runs Panache with external formatters on pushes to
`main`. `devenv.nix` also enables the Panache formatting hook.

For missing packages or execution errors, reproduce the render in devenv and
update `devenv.nix` as needed. Also check referenced files, images, and
cross-references when diagnosing build failures.

## Project Structure

- `_quarto.yml`: Website configuration, navigation, Flatly theme, KaTeX, search,
  and freeze policy.
- `header.html` and `styles.css`: Shared header markup and styling.
- `blog/_metadata.yml`: Blog defaults, including freeze, Giscus comments, title
  banners, and social sharing.
- `blog/YYYY-MM-DD-slug/index.qmd`: Blog posts and their local images.
- `news/`, `publications/`, `software/`, `talks/`, and `cv/`: Other content.
- `assets/bibliography.bib`: Shared bibliography.
- `_extensions/`: Quarto extensions. Modify only with good reason.
- `scripts/`: Site maintenance and generation scripts.
- `workers/` and `wrangler.toml`: Site Worker, its tests, and deployment
  configuration.
- `Taskfile.yml`: Preview, render, Worker test, deployment, SEO, link, and
  Lighthouse commands.
- `.clang-format`: Mozilla style for C/C++ examples.

## Editing Content

Create blog posts at `blog/YYYY-MM-DD-slug/index.qmd`. Include YAML frontmatter
with a title, date, description, and lowercase, hyphen-separated categories. Put
images beside the post or in its `images/` subdirectory. Use relative paths for
internal links and images.

R code chunks execute by default. Set `eval: false` for examples that should not
execute. Render the affected post to check computations and review any generated
`_freeze/` changes.

To generate a blog banner, run
`python scripts/generate-banner.py blog/YYYY-MM-DD-slug/index.qmd`. This
requires an OpenAI API key and writes `images/banner.png` in the post's
directory.

The post-render script `scripts/optimize-site-assets.py` generates WebP listing
thumbnails in `_site/assets/thumbnails/` with ImageMagick and removes unused
KaTeX loaders from pages without math. It preserves original sharing images and
SVG thumbnails. The homepage uses `assets/images/avatar.webp`; regenerate it
from the original JPEG with
`magick assets/images/avatar.jpg -auto-orient -resize '640x640>' -strip -quality 80 assets/images/avatar.webp`
when replacing the portrait. Specialized icon libraries are scoped to the CV,
publications, and software through `assets/templates/icons.html`.

Edit `styles.css` for shared styling or the theme in `_quarto.yml`. Do not
manually edit or commit `_site/` output.

## Troubleshooting

- **Quarto or a package is missing:** Enter `devenv shell`. For missing
  dependencies, update `devenv.nix` and reenter the environment.
- **A file cannot be found:** Check paths relative to the repository root and
  confirm that referenced files exist.
- **Frozen computations are stale:** Render the affected source file explicitly
  to reexecute it. Use `--execute-debug` for execution diagnostics.
- **Listing categories show no matches after a Quarto upgrade:** On Nix,
  packaged resources have epoch timestamps, so Quarto can retain an older cached
  listing script. Run `scripts/refresh-quarto-libraries.sh` from the repository
  root. It stages Quarto resources with fresh timestamps and renders the site
  without changing the freeze policy. Review and commit generated `_freeze/`
  changes, verify category clicks and direct category links, and confirm that an
  ordinary `quarto render` preserves the fix.

## Prose

- Use American English and the Oxford comma.
- Use em dashes sparingly, with no surrounding spaces. Prefer them over en
  dashes for parenthetical remarks. Use semicolons sparingly.
- Prefer active voice and concrete subjects. Follow Steven Pinker's guidelines
  for clear writing.
- Avoid LLM jargon and buzzwords.
- Follow the voice of surrounding author-written text and older posts.

## Visualizations

- Generally prefer the Okabe-Ito color palette for categorical data.
- For R, use ggplot2.
- For Python, use matplotlib.
- For Julia, use Makie.
