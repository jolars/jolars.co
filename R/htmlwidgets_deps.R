# The following bits of code have been exported from https://github.com/brendan-r/brocks
# on
#
# Code required to resolve clashing/overlapping js & css dependencies in
# htmlwidgets.
#
# This code taken from the rmarkdown package v0.9.5.1
# (https://github.com/rstudio/rmarkdown/blob/013d36b13aac24d57fdcc33711abc70d1900d927/R/html_dependencies.R),
# copied here as the functions required are internal, not exported, and thus
# subject to change. Rstudio provide this code under the GPL-3 licence
# (https://www.gnu.org/licenses/gpl-3.0.en.html).
#
# Authors:
#   JJ Allaire <jj@rstudio.com>
#   Joe Cheng <joe@rstudio.com>
#   Jonathan McPherson <jonathan@rstudio.com>
#   Winston Chang <winston@rstudio.com>
#
# Copyright (C) 2016 Rstudio inc.
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.


# rmarkdown internal functions: html dependency resolution ----------------

# check class of passed list for 'html_dependency'
is_html_dependency <- function(list) {
  inherits(list, "html_dependency")
}

# validate that the passed list is a correctly formed html_dependency
validate_html_dependency <- function(list) {
  # ensure it's the right class
  if (!is_html_dependency(list))
    stop("passed object is not of class html_dependency", call. = FALSE)

  # validate required fields
  if (is.null(list$name))
    stop("name for html_dependency not provided", call. = FALSE)
  if (is.null(list$version))
    stop("version for html_dependency not provided", call. = FALSE)
  if (is.null(list$src$file))
    stop("path for html_dependency not provided", call. = FALSE)
  if (!file.exists(list$src$file))
    stop("path for html_dependency not found: ", list$src$file, call. = FALSE)

  list
}

# flattens an arbitrarily nested list and returns all of the html_dependency
# objects it contains
flatten_html_dependencies <- function(knit_meta) {

  all_dependencies <- list()

  # knit_meta is a list of 'meta' attributes returned from custom knit_print
  # functions. since the 'meta' attribute could either be an html dependency or
  # a list of dependencies we recurse on lists that aren't named
  for (dep in knit_meta) {
    if (is.null(names(dep)) && is.list(dep)) {
      inner_dependencies <- flatten_html_dependencies(dep)
      all_dependencies <- append(all_dependencies, inner_dependencies)
    }
    else if (is_html_dependency(dep)) {
      all_dependencies[[length(all_dependencies) + 1]] <- dep
    }
  }

  all_dependencies
}

# consolidate dependencies (use latest versions and remove duplicates). this
# routine is the default implementation for version dependency resolution;
# formats may specify their own.
html_dependency_resolver <- function(all_dependencies) {

  dependencies <- htmltools::resolveDependencies(all_dependencies)

  # validate each surviving dependency
  lapply(dependencies, validate_html_dependency)

  # return the consolidated dependencies
  dependencies
}

#' @keywords internal
#' Adapted from rmarkdown:::html_dependencies_as_string
html_dependencies_to_string <- function (dependencies, lib_dir, output_dir) {

  # Flatten and resolve html deps
  dependencies <- html_dependency_resolver(
    flatten_html_dependencies(dependencies)
  )

  if (!is.null(lib_dir)) {
    dependencies <- lapply(
      dependencies, htmltools::copyDependencyToDir, lib_dir
    )

    dependencies <- lapply(
      dependencies, htmltools::makeDependencyRelative, output_dir
    )
  }

  # A function to add Jekyll boilerplate
  prepend_baseurl <- function(path){
    # If the url doesn't start "/", make sure that it does
    path <- ifelse(!grepl("^/", path), paste0("/", path), path)

    paste0('{{ "', path, '" | prepend: site.baseurl }}')
  }

  htmltools::renderDependencies(
    dependencies, "file",
    encodeFunc = identity,
    hrefFilter = prepend_baseurl
  )
}


#' Configure htmlwidgets dependencies for a knitr-jekyll blog
#'
#' Unlike static image plots, the outputs of htmlwidgets dependencies also have
#' Javascript and CSS dependencies, which are not by default processed by knitr.
#' \code{htmlwdigets_deps} provides a system to add the dependencies to a Jekyll
#' blog. Further details are available in the following blog post:
#' \url{http://brendanrocks.com/htwmlwidgets-knitr-jekyll/}.
#'
#' @param a The file path for the input file being knit
#' @param knit_meta The dependencies object.
#' @param lib_dir The directory where the htmlwidgets dependency source code can
#'   be found (e.g. JavaScript and CSS files)
#' @param includes_dir The directory to add the HTML file to
#' @param always Should dependency files always be produced, even if htmlwidgets
#'   are not being used?
#'
#' @return Used for it's side effects.
htmlwidgets_deps <- function(
    a,
    knit_meta,
    lib_dir = "htmlwidgets_deps",
    includes_dir = "_includes/htmlwidgets/",
    always = FALSE
) {

  # If the directories don't exist, create them
  dir.create(lib_dir,      showWarnings = FALSE, recursive = TRUE)
  dir.create(includes_dir, showWarnings = FALSE, recursive = TRUE)

  # Copy the libraries from the R packages to the 'htmlwidgets_deps' dir, and
  # obtain the html code required to import them
  deps_str <- html_dependencies_to_string(knit_meta, lib_dir, ".")

  # *Sometimes* Jekyll markdown posts are prefixed with a 12 char ISO date and
  # hypen, before becoming html posts. Remove, if present.
  lose_date <- function(x) {
    gsub("^[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}-", "", x)
  }

  # Write the html dependency import code to a file, to be imported by the
  # liquid templates
  deps_file <- paste0(
    includes_dir,
    gsub(".Rmd$", ".html", lose_date(basename(a[1])))
  )

  # Write out the file if either, the dependencies string has anything to add,
  # or, if the always parameter has been set to TRUE (useful for those building
  # with GitHub pages)
  if(always | !grepl("^[[:space:]]*$", deps_str))
    writeLines(deps_str, deps_file)
}


