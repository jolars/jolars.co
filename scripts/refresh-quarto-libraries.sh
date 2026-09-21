#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f _quarto.yml ]]; then
  echo "Run this script from the repository root." >&2
  exit 1
fi

quarto_share=$(quarto --paths | tail -n 1)
refresh_dir=$(mktemp -d)
trap 'rm -rf -- "$refresh_dir"' EXIT

# Nix timestamps packaged resources at the Unix epoch. Quarto copies libraries
# only when their source is newer, so an old frozen library can take precedence.
# Stage the installed resources with fresh timestamps and let Quarto update both
# the frozen libraries and the rendered site, retaining the execution policy.
cp -R --no-preserve=mode,timestamps "$quarto_share" "$refresh_dir/share"
QUARTO_SHARE_PATH="$refresh_dir/share" quarto render "$@"
