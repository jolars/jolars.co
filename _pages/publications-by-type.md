---
layout: single 
permalink: /publications-by-type/
author_profile: true
title: Publications
toc: true 
toc_label: "Type"
toc_icon: "newspaper"
---

[By Year](/publications-by-year/){: .btn .btn--inverse}
[By Type](/publications-by-type/){: .btn .btn--inverse}

## Articles

{% bibliography -f my_publications --query @article %}

## Proceedings

{% bibliography -f my_publications --query @inproceedings %}

## Theses

{% bibliography -f my_publications --query @thesis %}
