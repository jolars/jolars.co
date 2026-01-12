#!/usr/bin/env bash
set -euo pipefail

# Get the title from arguments or prompt
if [ $# -eq 0 ]; then
  read -p "Enter blog post title: " title
else
  title="$*"
fi

# Generate slug from title (lowercase, replace spaces with hyphens)
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')

# Get today's date
date=$(date +%Y-%m-%d)

# Create blog post directory
post_dir="blog/${date}-${slug}"
mkdir -p "$post_dir"

# Create index.qmd with template
cat > "$post_dir/index.qmd" << EOF
---
title: "$title"
description: ""
author: "Johan Larsson"
date: "$date"
categories: []
image: ""
---

## Introduction

EOF

echo "Created new blog post at: $post_dir/index.qmd"

# Create corresponding news entry
news_file="news/${date}-${slug}.qmd"
cat > "$news_file" << EOF
---
title: "New Blog Post: $title"
date: $date
description: |
  I have published a new blog post about...
---
EOF

echo "Created news entry at: $news_file"
echo "Opening blog post in editor..."

# Open in editor if available
if command -v \$EDITOR &> /dev/null; then
  \$EDITOR "$post_dir/index.qmd" "$news_file"
elif command -v code &> /dev/null; then
  code "$post_dir/index.qmd" "$news_file"
elif command -v vim &> /dev/null; then
  vim "$post_dir/index.qmd" "$news_file"
else
  echo "No editor found. Please edit files manually."
fi
