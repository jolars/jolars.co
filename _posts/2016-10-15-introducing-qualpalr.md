---
title: Introducing qualpalr
htmlwidgets:
  introducing-qualpalr.html
category: r
excerpt: "Let me introduce qualpalr: an R package that generates qualitative color palettes with distinct colors using color difference algorithms."
tags: [qualpalr, color-science]
---

With the advent of [colorbrewer](http://colorbrewer2.org/) there now exists good options to generate color palettes for sequential, diverging, and qualitative data. In R, these palettes can be accessed via the popular [RColorBrewer](https://cran.r-project.org/package=RColorBrewer) package. Those palettes, however, are limited to a fixed number of colors. This isn't much of a problem for sequential of diverging data since we can interpolate colors to any range we desire:


{% highlight r %}
pal <- RColorBrewer::brewer.pal(4, "PuBuGn")
color_ramp <- colorRampPalette(pal, space = "Lab")
{% endhighlight %}

There is not, however, an analogue for qualitative color palettes that will get you beyond the limits of 8--12 colors of colorbrewer's qualitative color palettes. 

There is also no customization in colorbrewer. Other R packages, such as [colorspace](https://cran.r-project.org/package=colorspace) offer this, but they are primarily adapted to sequential and diverging data -- not qualitative data.

This is where qualpalr comes in. qualpalr provides the user with a convenient way of generating distinct qualitative color palettes, primarily for use in R graphics. Given `n` (the number of colors to generate), along with a subset in the [hsl color space](https://en.wikipedia.org/wiki/HSL_and_HSV) (a cylindrical representation of the RGB color space) `qualpalr` attempts to find the `n` colors in the provided color subspace that *maximize the smallest pairwise color difference*. This is done by projecting the color subset from the HSL color space to the DIN99d space. DIN99d is (approximately) perceptually uniform, that is, the euclidean distance between two colors in the space is proportional to their perceived difference.

## Examples

`qualpalr` relies on one basic function, `qualpal()`, which takes as its input `n` (the number of colors to generate) and `colorspace`, which can be either

* a list of numeric vectors `h` (hue from -360 to 360), `s` (saturation from 0 to 1), and `l` (lightness from 0 to 1), all of length 2, specifying a min and max.
* a character vector specifying one of the predefined color subspaces, which at the time of writing are *pretty*, *pretty_dark*, *rainbow*, and *pastels*.


{% highlight r %}
library(qualpalr)
pal <- qualpal(n = 5, list(h = c(0, 360), s = c(0.4, 0.6), l = c(0.5, 0.85)))

# Adapt the color space to deuteranopia
pal <- qualpal(n = 5, colorspace = "pretty", cvd = "deutan")
{% endhighlight %}

The resulting object, `pal`, is a list with several color tables and a distance matrix based on the din99d color difference formula.


{% highlight r %}
pal
{% endhighlight %}



{% highlight text %}
## ---------------------------------------- 
## Colors in the HSL color space 
## 
##         Hue Saturation Lightness
## #73CA6F 117       0.46      0.61
## #D37DAD 327       0.50      0.66
## #C6DBE8 203       0.42      0.84
## #6C7DCC 229       0.48      0.61
## #D0A373  31       0.50      0.63
## 
##  ---------------------------------------- 
## DIN99d color difference distance matrix 
## 
##         #73CA6F #D37DAD #C6DBE8 #6C7DCC
## #D37DAD      28                        
## #C6DBE8      19      21                
## #6C7DCC      27      19      19        
## #D0A373      19      18      20      25
{% endhighlight %}

Methods for `pairs` and `plot` have been written for `qualpal` objects to help visualize the results.


{% highlight r %}
# Multidimensional scaling plot
plot(pal)

# Pairs plot in the din99d color space
pairs(pal, colorspace = "DIN99d")
{% endhighlight %}

![plot of chunk unnamed-chunk-2](/figure/posts/2016-10-15-introducing-qualpalr/unnamed-chunk-2-1.png)![plot of chunk unnamed-chunk-2](/figure/posts/2016-10-15-introducing-qualpalr/unnamed-chunk-2-2.png)

The colors are normally used in R by fetching the `hex` attribute of the palette.


{% highlight r %}
library(maps)
map("france", fill = TRUE, col = pal$hex, mar = c(0, 0, 0, 0))
{% endhighlight %}

![plot of chunk map](/figure/posts/2016-10-15-introducing-qualpalr/map-1.png)

## Details

`qualpal` begins by generating a point cloud out of the HSL color subspace provided by the user, using a quasi-random torus sequence from [randtoolbox](https://cran.r-project.org/package=randtoolbox). Here is the color subset in HSL with settings `h = c(-200, 120), s = c(0.3, 0.8), l = c(0.4, 0.9)`.


{% highlight text %}
## Loading required namespace: rmarkdown
{% endhighlight %}



{% highlight text %}
## TypeError: Attempting to change the setter of an unconfigurable property.
## TypeError: Attempting to change the setter of an unconfigurable property.
{% endhighlight %}

![plot of chunk details_input](/figure/posts/2016-10-15-introducing-qualpalr/details_input-1.png)

The function then proceeds by projecting these colors into the sRGB space.


{% highlight text %}
## TypeError: Attempting to change the setter of an unconfigurable property.
## TypeError: Attempting to change the setter of an unconfigurable property.
{% endhighlight %}

![plot of chunk RGB_space](/figure/posts/2016-10-15-introducing-qualpalr/RGB_space-1.png)

It then continues by projecting the colors, first into the XYZ space, then CIELab (not shown here), and then finally the DIN99d space.


{% highlight text %}
## TypeError: Attempting to change the setter of an unconfigurable property.
## TypeError: Attempting to change the setter of an unconfigurable property.
{% endhighlight %}

![plot of chunk DIN_space](/figure/posts/2016-10-15-introducing-qualpalr/DIN_space-1.png)

The DIN99d color space [@cui_uniform_2002] is a euclidean, perceptually uniform color space. This means that the difference between two colors is equal to the euclidean distance between them. We take advantage of this by computing a distance matrix on all the colors in the subset, finding their pairwise color differences. We then apply a power transformation [@huang_power_2015] to fine tune these differences.

To select the `n` colors that the user wanted, we proceed greedily: first, we find the two most distant points, then we find the third point that maximizes the minimum distance to the previously selected points. This is repeated until `n` points are selected. These points are then returned to the user; below is an example using `n = 5.`


{% highlight text %}
## TypeError: Attempting to change the setter of an unconfigurable property.
## TypeError: Attempting to change the setter of an unconfigurable property.
{% endhighlight %}

![plot of chunk selected_points](/figure/posts/2016-10-15-introducing-qualpalr/selected_points-1.png)

### Color specifications

At the time of writing, qualpalr only works in the sRGB color space with
the CIE Standard Illuminant D65 reference white. 

## Future directions

The greedy search to find distinct colors is crude. Particularly when searching
for few colors, the greedy algorithm will lead to sub-optimal results. Other
solutions to finding points that maximize the smallest pairwise distance 
among them are welcome.

## Thanks

[Bruce Lindbloom's webpage](http://www.brucelindbloom.com/) has
been instrumental in making qualpalr. Also thanks to
[i want hue](http://tools.medialab.sciences-po.fr/iwanthue/), which inspired me
to make qualpalr.

## References
