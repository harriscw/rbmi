% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mmrm.R
\name{extract_params}
\alias{extract_params}
\title{Extract glmmTMB model parameters}
\usage{
extract_params(fit)
}
\arguments{
\item{fit}{an object created by \code{\link[glmmTMB:glmmTMB]{glmmTMB::glmmTMB()}}}
}
\description{
Extracts the beta and sigma coefficients from an MMRM model created
by \code{\link[glmmTMB:glmmTMB]{glmmTMB::glmmTMB()}}.
Also returns theta for use in providing initial values to subsequent calls.
}
