-- The frozen document contains the old link alongside historical benchmarks.
-- Correct the link during rendering without regenerating those computations.
function Link(link)
  if link.target == "https://jolars.github.io/SLOPE/news/index.html#slope-0-2-0-unreleased" then
    link.target = "https://jolars.github.io/SLOPE/news/index.html#slope-020"
  end
  return link
end
