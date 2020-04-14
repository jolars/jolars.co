---
title: "Finding the farthest points in a point cloud"
author: "Johan Larsson"
categories: ["R"]
date: 2016-10-30
tags: ["qualpalr", "color-science"]
summary: "A better algorithm for finding a subset of points that maximize the minimal distance between them."
bibliography: [../../../static/library.bib]
---


My R package [qualpalr](https://github.com/jolars/qualpalr) selects qualitative
colors by projecting a bunch of colors (as points) to the three-dimensional
DIN99d color space wherein the distance between any pair colors approximate
their differences in appearance. The package then tries to choose the `n`
colors so that the minimal pairwise distance among them is maximized, that is,
we want the most similar pair of colors to be as dissimilar as possible.

This turns out to be much less trivial that one would suspect, which posts on
[Computational Science](http://scicomp.stackexchange.com/questions/20030/selecting-most-scattered-points-from-a-set-of-points),
[MATLAB Central](https://se.mathworks.com/matlabcentral/answers/42622-how-can-i-choose-a-subset-of-k-points-the-farthest-apart), 
[Stack Overflow](http://stackoverflow.com/questions/27971223/finding-largest-minimum-distance-among-k-objects-in-n-possible-distinct-position), and
and [Computer Science](http://cs.stackexchange.com/questions/22767/choosing-a-subset-to-maximize-the-minimum-distance-between-points)
can attest to.

Up til now, qualpalr solved this problem with a greedy approach. If we, for instance,
want to find `n` points we did the following.

```
M <- Compute a distance matrix of all points in the sample
X <- Select the two most distant points from M
for i = 3:n
    X(i) <- Select point in M that maximize the mindistance to all points in X
```

In R, this code looked like this (in two dimensions):


```r
# packages
library(lattice)

set.seed(1)
# find n points
n <- 3
mat  <- as.data.frame(matrix(runif(100), ncol = 2))
colnames(mat) <- c("x", "y")

dmat <- as.matrix(stats::dist(mat))
ind <- integer(n)
ind[1:2] <- as.vector(arrayInd(which.max(dmat), .dim = dim(dmat)))

for (i in 3:n) {
  mm <- dmat[ind, -ind, drop = FALSE]
  k <- which.max(mm[(1:ncol(mm) - 1) * nrow(mm) + max.col(t(-mm))])
  ind[i] <- as.numeric(dimnames(mm)[[2]][k])
}

xyplot(y ~ x, data = mat,
       asp = 1,
       panel = function(x, y, ...) {
         panel.xyplot(x, y, ...)
         panel.points(x[ind], y[ind], pch = 19)
       })
```

<div class="figure" style="text-align: center">
<img src="/post/2016-10-30-farthest-points/index_files/figure-html/greedy-approach-1.png" alt="Greedy approach to farthest-point picking." width="480" />
<p class="caption">Figure 1: Greedy approach to farthest-point picking.</p>
</div>

While this greedy procedure is fast and works well for large values of `n`
it is quite inefficient in the example above. It is plain to see that there are
other subsets of 3 points that would have a larger minimum distance but because
we base our selection on the previous 2 points that were selected to be
maximally distant, the algorithm has to pick a suboptimal third point. The
minimum distance in our example is 0.7641338.

The solution I came up with is based on a solution from
Schlomer et al. @schlomer_farthest-point_2011 who devised of an algorithm to
partition a sets of points into subsets whilst maximizing the minimal distance.
They used [delaunay triangulations](https://en.wikipedia.org/wiki/Delaunay_triangulation)
but I decided to simply use the distance matrix instead. The algorithm works as
follows.

```
M <- Compute a distance matrix of all points in the sample
S <- Sample n points randomly from M
repeat
    for i = 1:n
        M    <- Add S(i) back into M
        S(i) <- Find point in M\S with max mindistance to any point in S
until M did not change
```

Iteratively, we put one point from our candidate subset (S) back into the
original se (M) and check all distances between the points in S to those in
M to find the point with the highest minimum distance. Rinse and repeat until
we are only putting back the same points we started the loop with, which
always happens. Let's see how this works on the same data set we used above.



```r
r <- sample(nrow(dmat), n)

repeat {
  r_old <- r
  for (i in 1:n) {
    mm <- dmat[r[-i], -r[-i], drop = FALSE]
    k <- which.max(mm[(1:ncol(mm) - 1) * nrow(mm) + max.col(t(-mm))])
    r[i] <- as.numeric(dimnames(mm)[[2]][k])
  }
  if (identical(r_old, r)) break
}

xyplot(y ~ x, data = mat,
       asp = 1,
       panel = function(x, y, ...) {
         panel.xyplot(x, y, ...)
         panel.points(x[r], y[r], pch = 19)
       })
```

<div class="figure">
<img src="/post/2016-10-30-farthest-points/index_files/figure-html/new-approach-1.png" alt="New approach to farthest-point picking." width="480" />
<p class="caption">Figure 2: New approach to farthest-point picking.</p>
</div>

Here, we end up with a minimum distance of 0.8619587. In
qualpalr, this means that we now achieve slightly more distinct colors.

## Performance

The new algorithm is slightly slower than the old, greedy approach and slightly
more verbose


```r
f_greedy <- function(data, n) {
  dmat <- as.matrix(stats::dist(data))
  ind <- integer(n)
  ind[1:2] <- as.vector(arrayInd(which.max(dmat), .dim = dim(dmat)))
  for (i in 3:n) {
    mm <- dmat[ind, -ind, drop = FALSE]
    k <- which.max(mm[(1:ncol(mm) - 1) * nrow(mm) + max.col(t(-mm))])
    ind[i] <- as.numeric(dimnames(mm)[[2]][k])
  }
  ind
}

f_new <- function(dat, n) {
  dmat <- as.matrix(stats::dist(data))
  r <- sample.int(nrow(dmat), n)
  repeat {
    r_old <- r
    for (i in 1:n) {
      mm <- dmat[r[-i], -r[-i], drop = FALSE]
      k <- which.max(mm[(1:ncol(mm) - 1) * nrow(mm) + max.col(t(-mm))])
      r[i] <- as.numeric(dimnames(mm)[[2]][k])
    }
    if (identical(r_old, r)) return(r)
  }
}
```


```r
library(microbenchmark)
library(ggplot2)
n <- 5
data <- matrix(runif(900), ncol = 3)
bench <- microbenchmark(Greedy = f_greedy(data, n), 
                        New = f_new(data, n),
                        times = 1000L)
autoplot(bench)
```

<div class="figure">
<img src="/post/2016-10-30-farthest-points/index_files/figure-html/benchmark-1.png" alt="Benchmark results for the new and old algorithm." width="576" />
<p class="caption">Figure 3: Benchmark results for the new and old algorithm.</p>
</div>

The newest development version of qualpalr now uses this updated algorithm.

## References
