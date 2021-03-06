% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mapperRef.R
\name{as_igraph}
\alias{as_igraph}
\title{Exports Mapper as an igraph object.}
\arguments{
\item{vertex_scale}{scaling function for the vertex sizes.}

\item{vertex_min}{minimum vertex size.}

\item{vertex_min}{maximum vertex size.}

\item{col_pal}{color palette to color the vertices by.}
}
\value{
an igraph object.
}
\description{
Exports the 1-skeleton to a graph using the igraph library.
}
\details{
This method converts the 1-skeleton of the Mapper to an igraph object, and assigns some 
default visual properties. Namely, the vertex attributes "color", "size", and "label" and the 
edge attribute "color" are assigned. 
The vertex colors are colored according on the given color palette (default is rainbow) according 
to their mean filter value (see \code{\link{bin_color}}). The vertex sizes are scaled according 
to the number of points they contain, scaled by \code{vertex_scale}, and bounded between 
(\code{vertex_min}, \code{vertex_max}). The vertex labels are in the format "<id>:<size>".\cr
\cr
The edges are colored similarly by the average filter value of the points intersecting
both nodes they connect too.
}
