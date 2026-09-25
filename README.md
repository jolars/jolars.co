# jolars.co

<!-- badges: start -->
<!-- badges: end -->

My personal web site, built with Quarto.

## Adding news

Run this from the repository root:

```bash
devenv tasks run news:new --input title="My announcement"
```

This creates `news/YYYY-MM-DD-my-announcement.qmd` with today's local date in
the filename and frontmatter. Edit the placeholder description to write the
announcement. Omit `--input` to use the placeholder title "News title". The task
refuses to overwrite an existing file.
