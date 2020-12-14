---
layout: single
permalink: /publications-by-year/
author_profile: true
title: Publications
years: [2020, 2019, 2018, 2017, 2016, 2015, 2014]
toc: true
---

[By Year](/publications-by-year/){: .btn .btn--inverse}
[By Type](/publications-by-type/){: .btn .btn--inverse}

{% for y in page.years %}
  <h3  id="{{y}}" class="pubyear">{{y}}</h3>
  {% bibliography -f my_publications -q @*[year={{y}}]* %}
{% endfor %}
