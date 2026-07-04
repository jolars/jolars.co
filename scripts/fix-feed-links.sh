#!/usr/bin/env bash
set -euo pipefail

# Quarto's RSS feed generator makes <img src> absolute but leaves internal
# cross-post <a href> links relative (e.g. ../../blog/foo/index.html). Those
# break in feed readers and on aggregators like R-Bloggers that rehost the full
# content on their own domain. Blog posts live at blog/<slug>/index.html, so a
# ../../ prefix from any post resolves to the site root.
# Upstream bug: https://github.com/quarto-dev/quarto-cli/issues/8449

out="${QUARTO_PROJECT_OUTPUT_DIR:-_site}"
site_url="https://jolars.co"

shopt -s nullglob
for feed in "$out"/blog/*.xml; do
  sed -i "s#\"\.\./\.\./#\"${site_url}/#g" "$feed"
done
