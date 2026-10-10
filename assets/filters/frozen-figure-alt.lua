-- These descriptions preserve figures from historical computations. Remove a
-- post's entries when its computations are refreshed with native fig-alt options.
local descriptions = {
  ["2016-10-15-introducing-qualpalr"] = {
    ["fig-multidim-1.png"] = "Five palette colors shown as separated points in a multidimensional scaling plot of DIN99d color differences.",
    ["fig-pairs-1.png"] = "Scatterplot matrix showing the five palette colors along the lightness and two chromatic coordinates of DIN99d space.",
    ["fig-france-1.png"] = "Map of France with regions filled in the five-color qualpalr palette: blue, pink, tan, green, and pale blue.",
  },
  ["2016-10-19-introducing-eulerr"] = {
    ["unnamed-chunk-2-1.png"] = "Two circles labeled A and B overlap slightly, although the specified intersection is zero.",
    ["residual_plot-1.png"] = "Dot plot of residuals for seven set combinations. The B and C intersection has the largest positive residual; the other residuals are near zero.",
    ["eulerr_plot-1.png"] = "Euler diagram of three overlapping circles labeled A, B, and C, with pale fills and solid outlines.",
    ["eulerr_plot-2.png"] = "The same three-set Euler diagram with dark blue, pink, and cream fills, different border styles, and bold labels.",
  },
  ["2016-10-30-farthest-points"] = {
    ["unnamed-chunk-1-1.png"] = "Fifty points scattered across a unit square before selection by the greedy algorithm.",
    ["unnamed-chunk-1-2.png"] = "The greedy algorithm selects three points near the upper left, lower right, and upper right of the point cloud.",
    ["unnamed-chunk-2-1.png"] = "The same fifty-point cloud before selection by the iterative algorithm.",
    ["unnamed-chunk-2-2.png"] = "The iterative algorithm selects points near the upper left, upper right, and bottom center, increasing the minimum pairwise distance.",
  },
  ["2018-10-29-polygon-labeling-with-polylabelr"] = {
    ["venneuler-1.png"] = "Four overlapping circles labeled Treat, SE, Anti-CCP, and DAS28. Labels at circle centers do not identify all intersection regions.",
    ["polylabelr-1.png"] = "A concave polygon with a triangular hole. A black point marks the pole of inaccessibility inside its broad right-hand region.",
    ["eulerr-1.png"] = "Euler diagram of Anti-CCP, DAS28, SE, and Treat, with labels positioned within their respective regions.",
  },
  ["2020-04-14-slope-0-2-0"] = {
    ["unnamed-chunk-3-1.png"] = "Coefficient paths for two multinomial wine classes. Colored predictor coefficients shrink toward zero as regularization increases.",
    ["unnamed-chunk-5-1.png"] = "Cross-validation mean squared error versus regularization for q values of 0.1 and 0.2. Shaded bands show uncertainty, and a dotted line marks the selected value.",
  },
}

function Image(image)
  -- Scope by both post and generated figure path so unrelated images cannot match.
  local input = quarto.doc.input_file:gsub("\\", "/")
  local post = input:match("blog/([^/]+)/index%.qmd$")
  local figures = descriptions[post]
  local filename = image.src:match("^index_files/figure%-html/([^/]+)$")
  local description = figures and figures[filename]
  -- Native descriptions take precedence after a deliberate computational update.
  if description and not image.attributes["fig-alt"] then
    image.attributes["fig-alt"] = description
    return image
  end
end
