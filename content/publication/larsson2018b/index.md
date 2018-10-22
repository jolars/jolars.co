---
title: "eulerr: Area-Proportional Euler Diagrams with Ellipses"
date: "2018-02-12"
draft: false
authors: ["Johan Larsson"]
publication_types: ["7"]

publication: "LUP Student Papers"
publication_short: ""

abstract: "Euler diagrams are common and intuitive visualizations for data involving
  sets and relationships thereof. Compared to Venn diagrams, Euler diagrams do not
  require all set relationships to be present and may therefore be area-proportional
  also with subset or disjoint relationships in the input.
  Most Euler diagrams use circles, but circles do not always
  support accurate diagrams. A promising alternative for Euler diagrams is ellipses,
  which enable accurate diagrams for a wider range
  of set combinations. Ellipses, however, have not yet
  been implemented for more than three sets or three-set diagrams where
  there are disjoint or subset relationships. The aim of this thesis is
  to present a method and software for elliptical Euler diagrams for any
  number of sets.
  
  In this thesis, we provide and outline an R-based implementation called eulerr.
  It fits Euler diagrams using numerical optimization and exact-area
  algorithms through two steps: first, an initial layout is formed using
  the sets' pairwise relationships; second, this layout is finalized
  taking all the sets' intersections into account.
  
  Finally, we compare eulerr with other software implementations of Euler
  diagrams and show that the package
  is overall both more consistent and accurate as well as
  faster for up to seven sets compared to the other R-packages. eulerr perfectly
  reproduces samples of circular Euler diagrams as well
  as three-set diagrams with ellipses, but performs suboptimally with elliptical
  diagrams of more than three sets. eulerr also outperforms the other software tested in
  this thesis in fitting Euler diagrams to set configurations that might
  lack exact solutions provided that we use ellipses; eulerr's circular diagrams,
  meanwhile, fit better
  on all accounts save for the diagError metric in the case of three-set diagrams."
abstract_short: ""
selected: true
projects: ["euler-diagrams"]
tags: ["Venn diagrams", "Euler diagrams"]
url_pdf: "http://lup.lub.lu.se/student-papers/record/8934042/file/8935805.pdf"
url_preprint: ""
url_code: ""
url_dataset: ""
url_project: ""
url_slides: ""
url_video: ""
url_poster: ""
url_source: "https://github.com/jolars/eulerr2017bsc"
# url_custom: [{name = "Custom Link", url = "http://example.org"}]
doi: ""
# image:
#   - caption: ""
#   - focal_point: ""
---
