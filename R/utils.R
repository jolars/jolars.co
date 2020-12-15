rmd_pattern = '[.][Rr](md|markdown)$'
md_pattern  = '[.][Rr]?(md|markdown)$'

# relative path with '/' as the path separator
rel_path = function(x) {
  xfun::relative_path(xfun::normalize_path(x))
}

dir_exists <- function(x) {
  utils::file_test("-d", x)
}

with_ext = function(...) {
  xfun::with_ext(...)
}

del_empty_dir = bookdown:::clean_empty_dir

dir_rename = function(from, to, clean = FALSE) {
  if (!dir_exists(from))
    return()

  if (clean)
    unlink(to, recursive = TRUE)

  xfun:::dir_create(dirname(to))
  # I don't know why file.rename() might fail, but if it fails, fall back to
  # file.copy(): https://github.com/rstudio/blogdown/issues/232
  suppressWarnings(file.rename(from, to)) || {
    file.copy(from, dirname(to), recursive = TRUE) && unlink(from, recursive = TRUE)
  }
}

dirs_rename = function(from, to, ...) {
  n = length(from)

  if (n == 0)
    return()

  if (length(to) != n) stop(
    'The number of source dirs must be equal to the number of target dirs'
  )

  for (i in seq_len(n))
    dir_rename(from[i], to[i], ...)
}

# is a file the index page of a leaf bundle? i.e., index.*; the filename may
# also contain language code, e.g., index.fr.Rmd
bundle_index = function(x, ext = TRUE) {
  x = basename(x)
  if (ext)
    x = xfun::sans_ext(x)
  grepl('^index([.][a-z]{2})?$', x)
}

move_files = function(lib1, lib2) {
  # don't move by-products of leaf bundles
  i = !bundle_index(gsub('_(files|cache)$', '', lib1), ext = FALSE)
  dirs_rename(lib1[i], lib2[i])
}

# build .Rmarkdown to .markdown, and .Rmd to .html
output_file = function(file, md) {
  with_ext(file, ifelse(md, 'md', 'html'))
}

# tempfile under the current working directory
wd_tempfile = function(..., pattern = '') {
  basename(tempfile(pattern, '.', ...))
}

# given the content of a .html file: replace content/*_files/figure-html with
# /*_files/figure-html since this dir will be moved to /static/, and move the
# rest of dirs under content/*_files/ to /static/rmarkdown-libs/ (HTML
# dependencies), so all posts share the same libs (otherwise each post has its
# own dependencies, and there will be a lot of duplicated libs when HTML widgets
# are used extensively in a website)

decode_uri = function(...) httpuv::decodeURIComponent(...)
encode_uri = function(...) httpuv::encodeURIComponent(...)

# example values of arguments: x = <html> code; deps = '2017-02-14-foo_files';
# parent = 'content/post'; output = 'content/post/hello.md'
encode_paths = function(x, deps, parent, base, to_md, output) {
  if (!dir_exists(deps))
    return(x)  # no external dependencies such as images

  if (!grepl('/$', parent))
    parent = paste0(parent, '/')

  deps = basename(deps)
  need_encode = !to_md

  if (need_encode) {
    deps2 = encode_uri(deps)  # encode the path and see if it can be found in x
    # on Unix, paths containing multibyte chars are always encoded by Pandoc
    if (need_encode <- !xfun::is_windows() || any(grepl(deps2, x, fixed = TRUE)))
      deps = deps2
  }
  # find the dependencies referenced in HTML
  r = paste0('(<img src|<script src|<link href)(=")(', deps, '/)')

  # for bundle index pages, add {{< relref "output" >}} to URLs, to make sure
  # the post content can be displayed anywhere (not limited to the post page,
  # e.g., image paths of a post should also work on the home page if the full
  # post is included on the home page); see the bug report at
  # https://github.com/rstudio/blogdown/issues/501
  if (bundle_index(output)) {
    x = gsub(r, sprintf('\\1\\2{{< relref "%s" >}}\\3', sub('^\\_posts/', '', output)), x)
    return(x)
  }

  # move figures to /static/path/to/post/foo_files/figure-html
  if (FALSE) {
    # this is a little more rigorous: the approach below ("\'?)(%s/figure-html/)
    # means process any paths that "seems to have been generated from Rmd"; the
    # optional single quote after double quote is only for the sake of
    # trelliscopejs, where the string may be "'*_files/figure-html'"
    r1 = paste0(r, '(figure-html/)')
    x = gsub(r1, paste0('\\1\\2', gsub('^\\_posts/', base, parent), '/\\3\\4'), x)
  }
  r1 = sprintf('("\'?)(%s/figure-html/)', deps)
  x = gsub(r1, paste0('\\1', gsub('^\\_posts/', base, parent), '\\2'), x, perl = TRUE)
  # move other HTML dependencies to /static/rmarkdown-libs/
  r2 = paste0(r, '([^/]+)/')
  x2 = grep(r2, x, value = TRUE)
  if (length(x2) == 0)
    return(x)
  libs = unique(gsub(r2, '\\3\\4', unlist(regmatches(x2, gregexpr(r2, x2)))))
  libs = file.path(parent, if (need_encode) decode_uri(libs) else libs)
  x = gsub(r2, sprintf('\\1\\2%srmarkdown-libs/\\4/', base), x)
  to = file.path('rmarkdown-libs', basename(libs))
  dirs_rename(libs, to, clean = TRUE)
  x
}

server_wait = function() {
  Sys.sleep(getOption('blogdown.server.wait', 2))
}

fetch_yaml = function(f) {
  bookdown:::fetch_yaml(rmarkdown:::read_utf8(f))
}

# if YAML contains inline code, evaluate it and return the YAML
fetch_yaml2 = function(f) {
  yaml = fetch_yaml(f)
  n = length(yaml)
  if (n < 2)
    return()

  if (n == 2 || !any(stringr::str_detect(yaml, knitr::all_patterns$md$inline.code)))
    return(yaml)
  res = local({
    knitr::knit(text = yaml[-c(1, n)], quiet = TRUE)
  })
  c('---', res, '---')
}

# prepend YAML of one file to another file
prepend_yaml = function(from, to, body = xfun::read_utf8(to), callback = identity) {
  x = c(callback(fetch_yaml2(from)), '', body)
  xfun::write_utf8(x, to)
}
