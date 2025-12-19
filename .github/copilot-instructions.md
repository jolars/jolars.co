# Copilot Instructions for jolars.co

## Project Overview

This is a personal website for Johan Larsson built with Quarto. The site features a blog, software projects, publications, talks, and CV. The repository is small (~178 files excluding build artifacts) and uses Quarto's static site generation with computational caching via the freeze mechanism.

**Languages & Tools:**
- Quarto (static site generator)
- R (code execution in blog posts)
- Python (code execution, banner generation script)
- Julia (occasional code execution)
- HTML/CSS for styling
- Nix flake for development environment
- GitHub Actions for CI/CD

**Repository Size:** ~14MB total (12MB blog, 1.2MB talks, 4.6MB _freeze cache)

## Build & Deployment

### Prerequisites

The project uses Nix for reproducible development environments. The GitHub Actions workflow installs dependencies automatically, but for local development:

- **With Nix:** `nix develop` (preferred - provides Quarto, R, Python, Julia with all dependencies)
- **Without Nix:** Install Quarto manually from https://quarto.org/docs/get-started/

### Building the Site

**Important:** Always render with Quarto from the repository root.

```bash
# Render the entire site
quarto render

# Preview the site locally (with live reload)
quarto preview

# Render a specific file
quarto render blog/2024-05-30-moloch/index.qmd
```

**Output:** Rendered site goes to `_site/` directory (git-ignored).

### Freeze Mechanism

**Critical:** This project uses Quarto's `freeze: auto` feature to cache computational outputs. The `_freeze/` directory (4.6MB) stores rendered outputs from R/Python/Julia code chunks.

- **When code changes:** Quarto automatically re-executes and updates frozen content
- **When text changes only:** Frozen outputs are reused (faster builds)
- **Never manually edit** `_freeze/` directory contents
- The `_freeze/` directory **is committed** to the repository

### Testing & Validation

**No automated tests exist** for this static site. Validation is done through:

1. **Build validation:** `quarto render` must complete without errors
2. **Preview validation:** `quarto preview` and manually check pages in browser
3. **Link checking:** Verify internal links work correctly

**Note:** The repository has no formal test suite, linters for Quarto content, or validation scripts. The only validation is successful rendering.

## Continuous Integration

### GitHub Actions Workflow

The `.github/workflows/publish.yml` workflow runs on:
- Push to `main` branch
- Manual workflow dispatch

**Build Steps:**
1. Check out repository
2. Setup GitHub Pages
3. Install Quarto with TinyTeX
4. Restore git timestamps (important for freeze mechanism)
5. Render Quarto project
6. Upload and deploy to GitHub Pages

**Important:** The workflow uses `quarto-dev/quarto-actions/render@v2` which handles rendering. Do not use custom render commands in CI.

**Common Failure Points:**
- Missing R/Python packages (add to `flake.nix`)
- Code execution errors in .qmd files
- Broken cross-references or links
- Image files not found

## Project Structure

### Root Directory Files

```
.clang-format          # C/C++ formatting (used in some code examples)
.envrc                 # direnv configuration for Nix
.prettierrc.yaml       # Prettier config: proseWrap: always
_quarto.yml            # Main Quarto configuration file
flake.nix              # Nix development environment (R, Python, Julia packages)
header.html            # Custom HTML injected in every page header
index.qmd              # Homepage content
styles.css             # Site-wide custom CSS
```

### Key Directories

```
_extensions/           # Quarto extensions (fontawesome, academicons, fancy-text, multibib)
_freeze/               # Cached computational outputs (DO NOT MANUALLY EDIT)
assets/                # Shared resources
  └── bibliography.bib # BibTeX references for publications
blog/                  # Blog posts (13 posts, each in dated subdirectory)
  └── _metadata.yml    # Blog-wide metadata (freeze: auto, giscus comments)
cv/                    # CV page with LaTeX/PDF generation
publications/          # Research publications (12 items)
software/              # Software projects (5 items)
talks/                # Conference talks (4 items)
scripts/               # Utility scripts
  └── generate-banner.py  # OpenAI-powered blog banner generation
```

### Content Structure

All content pages are `.qmd` files with YAML frontmatter (title, date, description, categories, image). Blog posts: `blog/YYYY-MM-DD-slug/index.qmd`

### Configuration Files

**_quarto.yml** - Main configuration:
- Project type: `website`
- Theme: `flatly` (Bootswatch)
- Math rendering: KaTeX
- Search enabled
- Google Analytics configured
- Navigation structure defined
- Freeze: `auto` for computational caching

**blog/_metadata.yml:**
- Sets `freeze: auto` for all blog posts
- Configures Giscus comments integration
- Sets `title-block-banner: true` for blog posts

## Making Changes

### Adding/Editing Blog Posts

1. Create `blog/YYYY-MM-DD-post-title/index.qmd` with frontmatter
2. Place images in post directory or `images/` subdirectory
3. Use `{r}`, `{python}`, or `{julia}` code chunks as needed
4. Test: `quarto render blog/YYYY-MM-DD-post-title/index.qmd`
5. Frozen output auto-created in `_freeze/blog/`

### Adding Dependencies

Add to `flake.nix`: R packages under `rPackages`, Python under `python3.withPackages`, Julia via JuliaCall

### Styling & Formatting

- **Global:** Edit `styles.css` or modify `theme: flatly` in `_quarto.yml`
- **Prose:** Prettier with `proseWrap: always` - `npx prettier --write "**/*.qmd"`
- **C/C++:** Mozilla style (`.clang-format`)

## Common Workflows

### Adding a New Blog Post

1. Create directory: `mkdir -p blog/2025-12-19-new-post`
2. Add `index.qmd` with YAML frontmatter (title, date, description, categories)
3. Render to test: `quarto render blog/2025-12-19-new-post/index.qmd`
4. Preview: `quarto preview`

### Updating Dependencies

1. Edit `flake.nix` to add R/Python packages
2. Reload Nix: `nix develop`
3. Test: `quarto render`

### Generating Blog Banners

`python scripts/generate-banner.py blog/YYYY-MM-DD-post/index.qmd` (requires OpenAI API key)

## Important Conventions

1. **Always work from repository root** - Quarto paths are relative to project root
2. **Commit the _freeze/ directory** - It's part of the repository, not a build artifact
3. **Use relative paths** - All internal links should be relative (e.g., `blog/index.qmd`)
4. **Image locations** - Images can be in post directory or `images/` subdirectory
5. **Date format** - Use `YYYY-MM-DD` in blog post directory names
6. **YAML frontmatter** - Always include title, date, and description for blog posts
7. **Categories** - Use lowercase, hyphen-separated category names
8. **Code execution** - R code chunks execute by default; set `eval: false` to disable

## Troubleshooting

### Build Failures

**"Quarto not found"**
- Solution: Install Quarto or use `nix develop`

**"Package 'X' not found" (R/Python)**
- Solution: Add package to `flake.nix` and reload Nix environment

**"Could not find file"**
- Solution: Check paths are relative to project root, not current directory
- Solution: Verify image files exist in expected locations

**Frozen content not updating**
- Solution: Delete specific frozen file in `_freeze/` and re-render
- Solution: Use `quarto render --execute-debug` to see execution details

### CI Failures

The GitHub Actions workflow typically fails due to:
1. Missing dependencies (add to `flake.nix` - but CI uses Ubuntu packages, not Nix)
2. Code execution errors in .qmd files (test locally first)
3. Broken references or missing files

**Note:** The CI uses `quarto-dev/quarto-actions/setup@v2` which installs Quarto and TinyTeX but NOT the Nix environment. It uses Ubuntu's R/Python, not the Nix-provided versions. If you add uncommon packages, the CI may fail even if local builds work.

## What NOT to Do

1. **Do not** manually edit files in `_freeze/` directory
2. **Do not** manually edit files in `_site/` directory (build output)
3. **Do not** commit `_site/` directory (it's git-ignored)
4. **Do not** use absolute file paths
5. **Do not** add test frameworks or CI steps beyond rendering (keep it simple)
6. **Do not** modify Quarto extensions in `_extensions/` without good reason
7. **Do not** change the freeze setting in `_quarto.yml` or `_metadata.yml`

## Quick Reference

**Render site:** `quarto render`
**Preview site:** `quarto preview`
**Check Quarto version:** `quarto --version`
**Project root:** `/home/runner/work/jolars.co/jolars.co` (in CI)
**Build output:** `_site/` (git-ignored)
**Cached outputs:** `_freeze/` (committed)
**Main config:** `_quarto.yml`
**Blog config:** `blog/_metadata.yml`

## Trust These Instructions

These instructions have been validated by exploring the repository structure, configuration files, and workflows. When in doubt, refer to these instructions first before searching through the codebase. Only search the codebase if:
- These instructions are incomplete for your specific task
- You find information here that conflicts with actual repository contents
- You need to understand implementation details not covered here

The build process is straightforward: Quarto renders .qmd files to HTML, caching computational results in `_freeze/`. The GitHub workflow deploys the rendered site to GitHub Pages. There are no complex build steps, no test suite, and no linting beyond what Quarto provides.
