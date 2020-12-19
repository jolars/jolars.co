source("R/utils.R")
source("R/htmlwidgets_deps.R")

build_one <- function(input, to_md = TRUE) {
  options(htmltools.dir.version = FALSE)
  setwd(dirname(input))
  input = basename(input)
  # for bookdown's theorem environments generated from bookdown:::eng_theorem

  if (to_md)
    options(bookdown.output.markdown = TRUE)

  rmarkdown::render(
    input,
    'blogdown::html_page',
    envir = globalenv(),
    quiet = TRUE,
    run_pandoc = !to_md,
    clean = !to_md
  )
}

process_markdown = function(x, res, cit_type = c("pandoc", "jekyll-scholar")) {
  unlink(xfun::attr(res, 'intermediates'))
  # write HTML dependencies to the body of Markdown
  if (length(meta <- xfun::attr(res, 'knit_meta'))) {
    m = rmarkdown:::html_dependencies_as_string(meta, attr(res, 'files_dir'), '.')
    i <- grep('^---\\s*$', x)
    if (length(i) >= 2) {
      x = append(x, m, i[2])
    } else warning(
      'Cannot find the YAML metadata in the .markdown output file. ',
      'HTML dependencies will not be rendered.'
    )
  }
  # resolve bookdown references (figures, tables, sections, ...)
  # TODO: use bookdown >= 0.21.2 to avoid the unnecessary file I/O
  # x = local({
  #   f = wd_tempfile('.md~', pattern = 'post')
  #   on.exit(unlink(f), add = TRUE)
  #   rmarkdown:::write_utf8(x, f)
  #   bookdown:::process_markdown(f, 'markdown', NULL, TRUE, TRUE)
  #   xfun::read_utf8(f)
  # })
  # ## protect math expressions in backticks
  # x = xfun::protect_math(x)
  # remove the special comments from HTML dependencies
  x = gsub('<!--/?html_preserve-->', '', x)

  # render citations
  cit_type <- match.arg(cit_type)

  if (cit_type == "pandoc") {
    if (length(grep('^(references|bibliography):($| )', x))) {
      # temporary .md files to generate citations
      mds = replicate(2, wd_tempfile('.md~', pattern = 'citation'))
      on.exit(unlink(mds), add = TRUE)
      xfun::write_utf8(x, mds[1])
      rmarkdown::pandoc_convert(
        mds[1],
        from = 'markdown',
        to = 'gfm',
        output = mds[2],
        options = c(if (!rmarkdown::pandoc_available('2.11.2')) '--atx-headers', '--wrap=preserve'),
        citeproc = TRUE
      )
      x = c(bookdown:::fetch_yaml(x), '', xfun::read_utf8(mds[2]))
    }
  } else {
    # convert pandoc-style citations to jekyll-scholar
    x = gsub("(\\[\\@)(\\w+)(\\])", "{% cite \\2 %}", x)
  }

  # convert captions to <figcaption>
  x = gsub(
    "<p class=\"caption\">(\\(\\\\\\#fig:[^)]+\\))?([^\\<]+)<\\/p>",
    "<figcaption>\\2</figcaption>",
    x
  )

  # find figure tags and convert them to <figure> and use alignment classes
  # from minimal mistakes
  div_starts <- grep("^<div", x)
  div_ends  <- grep("^</div", x)

  figure_divs <- grepl("class=\"figure\"", x[div_starts])

  div_starts <- div_starts[figure_divs]
  div_ends <- div_ends[figure_divs]

  # find figure widths
  figwidths <- stringr::str_extract(x[div_starts + 1], "(?<=width=\")\\d+")

  # convert to <figure> tags (but leave open for inserting widths)
  x[div_starts] <- gsub("^\\<div class=\"figure\"([^\\>]*)\\>",
                        "<figure\\1",
                        x[div_starts],
                        perl = TRUE)
  # use class= instead of style text-align etc
  x[div_starts] <- gsub("style=\"text-align:\\s(\\w+)\"",
                        "class=\"align-\\1\"",
                        x[div_starts])
  # insert figure withds
  x[div_starts] <- paste0(x[div_starts], " style=\"max-width: ", figwidths, "px\">")

  x[div_ends] <- "</figure>"

  x
}

files <- blogdown:::list_rmds("_posts")

# locks <- paste0(files, ".lock~")
# i = !file.exists(locks)
#
# if (!any(i))
#   return()  # all files are currently being rendered

#files = files[i]

# remove locks on exit
#locks <- locks[i]
#file.create(locks)
#on.exit(file.remove(locks), add = TRUE)

# copy by-products {/content/.../foo_(files|cache) dirs and foo.html} from
# /blogdown/ or /static/ to /content/
lib1 = blogdown:::by_products(files, c('_files', '_cache'))
lib2 = gsub('^\\_posts', 'blogdown', lib1)  # /blogdown/.../foo_(files|cache)
i = grep('_files$', lib2)
#lib2[i] = gsub('^blogdown', 'static', lib2[i])  # _files are copied to /static
lib2[i] = gsub('^blogdown/', '', lib2[i])  # _files are copied to /static
# move by-products of a previous run to content/
blogdown:::dirs_rename(lib2, lib1)

#on.exit(move_files(lib1, lib2), add = TRUE)

base = blogdown:::get_config2('baseurl', '/')
shared_yml = '_output.yml'
copied_yaml = character()
#on.exit(unlink(copied_yaml), add = TRUE)

copy_output_yml = function(to) {
  if (!file.exists(shared_yml))
    return()

  copy <- file.path(to, '_output.yml')

  if (file.exists(copy))
    return()

  if (file.copy(shared_yml, copy))
    copied_yaml <<- c(copied_yaml, copy)
}

to_md = TRUE
cit_type = "jekyll-scholar"

for (i in seq_along(files)) {

  f = files[i]
  d = dirname(f)
  copy_output_yml(d)

  out = output_file(f, to_md)  # expected output file

  # if (!blogdown:::require_rebuild(out, f))
  #   next

  message('Rendering ', f, '... ', appendLF = FALSE)

  res = xfun::Rscript_call(
    build_one,
    list(f, to_md),
    fail = c('Failed to render ', f)
  )  # actual output file

  meta = attr(res, "knit_meta")

  xfun::in_dir(d, {
    x = xfun::read_utf8(res)
    if (res != basename(out))
      unlink(res)
    if (to_md)
      x = process_markdown(x, res, cit_type)
  })

  x = encode_paths(x, lib1[2 * i - 1], d, base, to_md, out)
  move_files(lib1[2 * i - 0:1], lib2[2 * i - 0:1])

  #htmlwidgets_deps(out, meta)

  # if (getOption('blogdown.widgetsID', TRUE))
  #   x = blogdown:::clean_widget_html(x)

  # split html at \n (newline) markers
  script_lines = grep('(<script src|<link href)(=")', x)

  for (j in script_lines) {
    y = strsplit(x[j], "\\n")[[1]]
    y = y[!duplicated(y)]
    x[j] = paste(y, collapse = "\n")
  }

  if (to_md) {
    xfun::write_utf8(x, out)
  } else {
    blogdown:::prepend_yaml(f, out, x, callback = function(s) {
      if (!getOption('blogdown.draft.output', FALSE)) return(s)
      if (length(s) < 2 || length(grep('^draft: ', s)) > 0) return(s)
      append(s, 'draft: true', 1)
    })
  }
  message('Done.')
}

move_files(lib1, lib2)

system2('bundle', 'exec jekyll build')
