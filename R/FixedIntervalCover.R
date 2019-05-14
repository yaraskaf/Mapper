#' Fixed Interval Cover
#'
#' @docType class
#' @description \code{\link{R6}} class representing a fixed interval cover. 
#' @field number_intervals vector of number of bins to cover the Z with (per dimension)
#' @field percent_overlap vector of overlap percentages
#' @details The fixed interval cover is multidimensional, two-parameter family of covers. Given the number of
#' intervals and the overlap percentage between these intervals, this class constructs cover of the
#' given filter space, where the open sets represent a (generalized) collection of interval level sets, 
#' distributed uniformly in a grid-like fashion. Unlike the \code{\link{RestrainedIntervalCover}}, the open sets
#' are not constrained by range of the filter values. \cr 
#' \cr 
#' The mapper corresponding to this cover may be thought of as a relaxed Reeb graph. 
#' @author Matt Piekenbrock
#' @family cover
#' @export
FixedIntervalCover <- R6::R6Class("FixedIntervalCover",
  inherit = CoverRef,
  private = list(.number_intervals=NA, .percent_overlap=NA)
)

#' @export
FixedIntervalCover$set("public", "initialize", function(filter_values, ...){
  super$initialize(filter_values, typename="Fixed Interval")
  params <- list(...)
  if ("number_intervals" %in% names(params)){ self$number_intervals <- params[["number_intervals"]] }
  if ("percent_overlap" %in% names(params)){ self$percent_overlap <- params[["percent_overlap"]] }
})

## Set overlap/gain threshold
FixedIntervalCover$set("active", "percent_overlap",
  function(value){
    if (missing(value)){ private$.percent_overlap }
    else {
      if (any(value < 0) || any(value >= 100)){ stop("The percent overlap must be a percentage between [0, 100).") }
      if (length(value) != private$.filter_dim && length(value) != 1){ stop("The percent overlap must be a single scalar or a vector of scalars with length equal to the dimensionality of the filter space.") }
      if (length(value) == 1 && private$.filter_dim > 1){ value <- rep(value, private$.filter_dim) } ## create a vector
      private$.percent_overlap <- value
      self
    }
  }
)

## Active binding to set the number of intervals to distribute along each dimension. 
## By default, if a scalar is given and the filter dimensionality is > 1, the scalar is 
## repeated along each dimension. 
FixedIntervalCover$set("active", "number_intervals", 
  function(value){
    if (missing(value)){ private$.number_intervals }
    else {
      if (length(value) == 1 && private$.filter_dim > 1){ value <- rep(value, private$.filter_dim) } ## create a vector
      stopifnot(all(value > 0))
      stopifnot(length(value) == private$.filter_dim)
      private$.number_intervals <- value
      self
    }
  }
)

FixedIntervalCover$set("public", "format", function(...){
  # type_pretty <- paste0(toupper(substr(self$typename, start = 1, stop = 1)), tolower(substr(self$typename, start = 2, stop = nchar(self$typename))))
  sprintf("Cover: (typename = %s, number intervals = [%s], percent overlap = [%s]%%)",
          private$.typename,
          paste0(private$.number_intervals, collapse = ", "),
          paste0(format(private$.percent_overlap, digits = 3), collapse = ", "))
})

## This function is specific to the interval-type covers
FixedIntervalCover$set("public", "interval_bounds", function(index=NULL){
  stopifnot(!is.na(private$.percent_overlap))
  stopifnot(!is.na(private$.number_intervals))
 
  ## Get filter min and max ranges
  filter_rng <- apply(self$filter_values, 2, range)
  { filter_min <- filter_rng[1,]; filter_max <- filter_rng[2,] }
  filter_len <- diff(filter_rng)
  
  ## Setup hyper-parameters
  prop_overlap <- self$percent_overlap/100
  base_interval_length <- filter_len/self$number_intervals
  interval_length <- base_interval_length + (base_interval_length * prop_overlap)/(1.0 - prop_overlap)
  eps <- (interval_length/2.0) + sqrt(.Machine$double.eps) ## ensures each point is in the cover
  
  ## If no index is given, construct the entire cover
  if (missing(index) || is.null(index)){
    cart_prod <- arrayInd(seq(prod(self$number_intervals)), .dim = self$number_intervals)
    ls_bounds <- t(apply(cart_prod, 1, function(idx){
      centroid <- filter_min + ((as.integer(idx)-1L)*base_interval_length) + base_interval_length/2.0
      c(centroid - eps, centroid + eps)
    }))
  } else {
    stopifnot(index %in% self$index_set)
    idx <- strsplit(substr(index, start=2L, stop=nchar(index)-1L), split = " ")[[1]]
    centroid <- filter_min + ((as.integer(idx)-1L)*base_interval_length) + base_interval_length/2.0
    ls_bounds <- c(centroid - eps, centroid + eps)
  }
  return(ls_bounds) ## Return bounds
})

## Setup a valid index set (via cartesian product)
FixedIntervalCover$set("public", "construct_index_set", function(...){
  cart_prod <- arrayInd(seq(prod(self$number_intervals)), .dim = self$number_intervals)
  self$index_set <- apply(cart_prod, 1, function(x){ sprintf("(%s)", paste0(x, collapse = " ")) })
})

## Given the current set of parameter values, construct the level sets whose union covers the filter space
FixedIntervalCover$set("public", "construct_cover", function(index=NULL){
  stopifnot(!is.na(private$.percent_overlap))
  stopifnot(!is.na(private$.number_intervals))
  
  ## If the index set hasn't been made yet, construct it.
  if (any(is.na(self$index_set))){ self$construct_index_set() }
  stopifnot(!any(is.na(self$index_set)))
  
  ## If no index specified, return the level sets either by construction
  if (missing(index) || is.null(index)){
    stopifnot(!index %in% self$index_set)
    set_bnds <- self$interval_bounds()
    self$level_sets <- constructIsoAlignedLevelSets(self$filter_values, as.matrix(set_bnds))
    return(invisible(self)) ## return invisibly 
  } else {
    if (!is.na(self$level_sets) && index %in% names(self$level_sets)){
      return(self$level_sets[[index]])
    } else {
      p_idx <- which(index == self$index_set)
      set_bnds <- self$interval_bounds(index)
      level_set <- constructIsoAlignedLevelSets(self$filter_values, set_bnds)
      return(level_set)
    }
  }
})

## Constructs a 'neighborhood', which is an (n x k+1) subset of pullback ids representing 
## the set of n unique (k+1)-fold intersections are required to construct the nerve. 
FixedIntervalCover$set("public", "neighborhood", function(k){
  stopifnot(!is.na(private$.index_set))
  if (k == 1){
    all_pairs <- t(combn(1L:length(private$.index_set), 2))
    multi_index <- arrayInd(seq(prod(self$number_intervals)), .dim = self$number_intervals)
    
    ## Get filter min and max ranges
    filter_rng <- apply(self$filter_values, 2, range)
    { filter_min <- filter_rng[1,]; filter_max <- filter_rng[2,] }
    filter_len <- diff(filter_rng)
    d_rng <- 1:ncol(self$filter_values)
    
    ## Compute the critical distances that determine which pairwise combinations to compare
    base_interval_length <- filter_len/self$number_intervals
    prop_overlap <- self$percent_overlap/100
    critical_dist <- lapply(d_rng, function(d_i) { base_interval_length[d_i] + ((base_interval_length[d_i]/2)*seq(1, self$number_intervals[d_i] - 1))*2 })
    c_interval_length <- base_interval_length + (base_interval_length * prop_overlap)/(1.0 - prop_overlap)
    
    ## Get the maximum index deviation allowed between level sets
    max_dev <- sapply(d_rng, function(d_i) { findInterval(c_interval_length[d_i], critical_dist[[d_i]])+1L })
    
    ## Filter based on percent overlap  
    which_pairs <- apply(all_pairs, 1, function(ls_pair){
      m1 <- multi_index[ls_pair[1],]
      m2 <- multi_index[ls_pair[2],]
      all(sapply(d_rng, function(d_i){ abs(m1[d_i] - m2[d_i]) <= max_dev[d_i] }))
    })
    
    ## Return the bounded pairs to compute
    res <- apply(all_pairs[which_pairs,], 2, function(x) { self$index_set[x] })
    return(res)
  } else {
    return(super$neighborhood(k))
  }
})

## Converts percent overlap to interval length for a fixed number of intervals
FixedIntervalCover$set("public", "overlap_to_interval_len", function(percent_overlap){
  stopifnot(all(is.numeric(self$number_intervals)))
  filter_rng <- apply(self$filter_values, 2, range)
  { filter_min <- filter_rng[1,]; filter_max <- filter_rng[2,] }
  filter_len <- diff(filter_rng)
  base_interval_length <- filter_len/self$number_intervals
  prop_overlap <- percent_overlap/100
  return(base_interval_length + (base_interval_length*prop_overlap)/(1.0 - prop_overlap))
})

## Converts interval length to percent overlap for a fixed number of intervals
FixedIntervalCover$set("public", "interval_len_to_percent_overlap", function(interval_len){
  stopifnot(all(is.numeric(self$number_intervals)))
  filter_rng <- apply(self$filter_values, 2, range)
  { filter_min <- filter_rng[1,]; filter_max <- filter_rng[2,] }
  filter_len <- diff(filter_rng)
  base_interval_length <- filter_len/self$number_intervals
  100.0*(1.0 - (base_interval_length/interval_len))
})
