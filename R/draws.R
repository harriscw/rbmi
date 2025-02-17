#' @title Fit the base imputation model and get parameter estimates
#'
#' @description `draws` fits the base imputation model to the observed outcome data
#' according to the given multiple imputation methodology.
#' According to the user's method specification, it returns either draws from the posterior distribution of the
#' model parameters as required for Bayesian multiple imputation or frequentist parameter estimates from the
#' original data and bootstrapped or leave-one-out datasets as required for conditional mean imputation.
#' The purpose of the imputation model is to estimate model parameters
#' in the absence of intercurrent events (ICEs) handled using reference-based imputation methods.
#' For this reason, any observed outcome data after ICEs, for which reference-based imputation methods are
#' specified, are removed and considered as missing for the purpose of estimating the imputation model, and for
#' this purpose only. The imputation model is a mixed effects model repeated measures (MMRM) model that is valid
#' under a missing-at-random (MAR) assumption.
#' It can be fit using frequentist maximum likelihood (ML) or restricted ML (REML) estimation,
#' a Bayesian approach, or an approximate Bayesian approach according to the user's method specification.
#' The ML/REML approaches and the approximate Bayesian approach support several possible covariance structures,
#' while the Bayesian approach based on MCMC sampling supports only an unstructured covariance structure.
#' In any case the covariance matrix can be assumed to be the same or different across each group.
#'
#' @name draws
#' @param data A `data.frame` containing the data to be used in the model. See details.
#' @param data_ice A `data.frame` that specifies the information related
#' to the ICEs and the imputation strategies. See details.
#' @param vars A `vars` object as generated by [set_vars()]. See details.
#' @param method A `method` object as generated by either [method_bayes()],
#' [method_approxbayes()] or [method_condmean()].
#' It specifies the multiple imputation methodology to be used. See details.
#'
#' @details
#'
#' `draws` performs the first step of the multiple imputation (MI) procedure: fitting the
#' base imputation model. The goal is to estimate the parameters of interest needed
#' for the imputation phase (i.e. the regression coefficients and the covariance matrices
#' from a MMRM model).
#'
#' The function distinguishes between the following methods:
#' - Bayesian MI based on MCMC sampling: `draws` returns the draws
#' from the posterior distribution of the parameters using a Bayesian approach based on
#' MCMC sampling. This method can be specified by using `method = method_bayes()`.
#' - Approximate Bayesian MI based on bootstrapping: `draws` returns
#' the draws from the posterior distribution of the parameters using an approximate Bayesian approach,
#' where the sampling from the posterior distribution is simulated by fitting the MMRM model
#' on bootstrap samples of the original dataset. This method can be specified by using
#' `method = method_approxbayes()]`.
#' - Conditional mean imputation with bootstrap re-sampling: `draws` returns the
#' MMRM parameter estimates from the original dataset and from `n_samples` bootstrap samples.
#' This method can be specified by using `method = method_condmean()` with
#' argument `type = "bootstrap"`.
#' - Conditional mean imputation with jackknife re-sampling: `draws` returns the
#' MMRM parameter estimates from the original dataset and from each leave-one-subject-out sample.
#' This method can be specified by using `method = method_condmean()` with
#' argument `type = "jackknife"`.
#'
#' Bayesian MI based on MCMC sampling has been proposed in Carpenter, Roger, and Kenward (2013) who first introduced
#' reference-based imputation methods. Approximate Bayesian MI is discussed in Little and Rubin (2002).
#' Conditional mean imputation methods are discussed in Wolbers et al (2021).
#'
#' The argument `data` contains the longitudinal data. It must have at least the following variables:
#' - `subjid`: a factor vector containing the subject ids.
#' - `visit`: a factor vector containing the visit the outcome was observed on.
#' - `group`: a factor vector containing the group that the subject belongs to.
#' - `outcome`: a numeric vector containing the outcome variable. It might contain missing values.
#' Additional baseline or time-varying covariates must be included in `data`.
#'
#' `data` must have one row per visit per subject. This means that incomplete
#' outcome data must be set as `NA` instead of having the related row missing. Missing values
#' in the covariates are not allowed. If `data` is incomplete
#' then the [expand_locf()] helper function can be used to insert any missing rows using
#' Last Observation Carried Forward (LOCF) imputation to impute the covariates values.
#' Note that LOCF is generally not a principled imputation method and should only be used when appropriate
#' for the specific covariate.
#'
#' Please note that there is no special provisioning for the baseline outcome values. If you do not want baseline
#' observations to be included in the model as part of the response variable then these should be removed in advance
#' from the outcome variable in `data`. At the same time if you want to include the baseline outcome as covariate in
#' the model, then this should be included as a separate column of `data` (as any other covariate).
#'
#' The argument `data_ice` contains information about the occurrence of ICEs. It is a
#' `data.frame` with 3 columns:
#' - **Subject ID**: a character vector containing the ids of the subjects that experienced
#'   the ICE. This column must be named as specified in `vars$subjid`.
#' - **Visit**: a character vector containing the first visit after the occurrence of the ICE
#'   (i.e. the first visit affected by the ICE).
#'   The visits must be equal to one of the levels of `data[[vars$visit]]`.
#'   If multiple ICEs happen for the same subject, then only the first non-MAR visit should be used.
#'   This column must be named as specified in `vars$visit`.
#' - **Strategy**: a character vector specifying the imputation strategy to address the ICE for this subject.
#'   This column must be named as specified in `vars$strategy`.
#'   Possible imputation strategies are:
#'   - `"MAR"`: Missing At Random.
#'   - `"CIR"`: Copy Increments in Reference.
#'   - `"CR"`: Copy Reference.
#'   - `"JR"`: Jump to Reference.
#'   - `"LMCF"`: Last Mean Carried Forward.
#' For explanations of these imputation strategies, see Carpenter, Roger, and Kenward (2013), Cro et al (2021),
#' and Wolbers et al (2021).
#' Please note that user-defined imputation strategies can also be set.
#'
#' The `data_ice` argument is necessary at this stage since (as explained in Wolbers et al (2021)), the model is fitted
#' after removing the observations which are incompatible with the imputation model, i.e.
#' any observed data on or after `data_ice[[vars$visit]]` that are addressed with an imputation
#' strategy different from MAR are excluded for the model fit. However such observations
#' will not be discarded from the data in the imputation phase
#' (performed with the function ([impute()]). To summarize, **at this stage only pre-ICE data
#' and post-ICE data that is after ICEs for which MAR imputation is specified are used**.
#'
#' If the `data_ice` argument is omitted, or if a subject doesn't have a record within `data_ice`, then it is
#' assumed that all of the relevant subject's data is pre-ICE and as such all missing
#' visits will be imputed under the MAR assumption and all observed data will be used to fit the base imputation model.
#' Please note that the ICE visit cannot be updated via the `update_strategy` argument
#' in [impute()]; this means that subjects who didn't have a record in `data_ice` will always have their
#' missing data imputed under the MAR assumption even if their strategy is updated.
#'
#' The `vars` argument is a named list that specifies the names of key variables within
#' `data` and `data_ice`. This list is created by [set_vars()] and contains the following named elements:
#' - `subjid`: name of the column in `data` and `data_ice` which contains the subject ids variable.
#' - `visit`: name of the column in `data` and `data_ice` which contains the visit variable.
#' - `group`: name of the column in `data` which contains the group variable.
#' - `outcome`: name of the column in `data` which contains the outcome variable.
#' - `covariates`: vector of characters which contains the covariates to be included
#'   in the model (including interactions which are specified as "covariateName1*covariateName2").
#'   If no covariates are provided the default model specification of `outcome ~ 1 + visit + group` will be used.
#'   Please note that the `group*visit` interaction
#'   is **not** included in the model by default.
#' - `strata`: covariates used as stratification variables in the bootstrap sampling.
#'   By default only the `vars$group` is set as stratification variable.
#'   Needed only for `method_condmean(type = "bootstrap")` and `method_approxbayes()`.
#' - `strategy`: name of the column in `data_ice` which contains the subject-specific imputation strategy.
#'
#' @inherit as_draws return
#'
#'@seealso [method_bayes()], [method_approxbayes()], [method_condmean()] for setting `method`.
#'@seealso [set_vars()] for setting `vars`.
#'@seealso [expand_locf()] for expanding `data` in case of missing rows.
#'
#' For more details see the quickstart vignette:
#' \code{vignette("quickstart", package = "rbmi")}.
#'
#' @references
#'
#' James R Carpenter, James H Roger, and Michael G Kenward. Analysis of longitudinal trials with protocol deviation: a
#' framework for relevant, accessible assumptions, and inference via multiple imputation. Journal of Biopharmaceutical
#' Statistics, 23(6):1352–1371, 2013.
#'
#' Suzie Cro, Tim P Morris, Michael G Kenward, and James R Carpenter. Sensitivity analysis for clinical trials with
#' missing continuous outcome data using controlled multiple imputation: a practical guide. Statistics in
#' Medicine, 39(21):2815–2842, 2020.
#'
#' Roderick J. A. Little and Donald B. Rubin. Statistical Analysis with Missing Data, Second Edition. John Wiley & Sons,
#' Hoboken, New Jersey, 2002. \[Section 10.2.3\]
#'
#' Marcel Wolbers, Alessandro Noci, Paul Delmar, Craig Gower-Page, Sean Yiu, Jonathan W. Bartlett. Reference-based
#' imputation methods based on conditional mean imputation. \url{http://arxiv.org/abs/2109.11162}, 2021.
#'
#' @export
draws <- function(data, data_ice = NULL, vars, method) {
    UseMethod("draws", method)
}




#' @rdname draws
#' @export
draws.approxbayes <- function(data, data_ice = NULL, vars, method) {
    longdata <- longDataConstructor$new(data, vars)
    longdata$set_strategies(data_ice)
    x <- get_bootstrap_draws(longdata, method, use_samp_ids = FALSE, first_sample_orig = FALSE)
    return(x)
}


#' @rdname draws
#' @export
draws.condmean <- function(data, data_ice = NULL, vars, method, mc.cores=1) {
    longdata <- longDataConstructor$new(data, vars)
    longdata$set_strategies(data_ice)
    if (method$type == "bootstrap") {
        x <- get_bootstrap_draws(longdata, method, use_samp_ids = TRUE, first_sample_orig = TRUE)
    } else if (method$type == "jackknife") {
        x <- get_jackknife_draws(longdata, method, mc.cores)
    } else {
        stop("Unknown method type")
    }
    return(x)
}


#' Fit the base imputation model on bootstrap samples
#'
#' @description
#' Fit the base imputation model using a ML/REML approach on a given number of bootstrap samples as
#' specified by `method$n_samples`. Returns the parameter estimates from the model fit.
#'
#' @param longdata R6 `longdata` object containing all relevant input data information.
#' @param method A `method` object as generated by either
#' [method_approxbayes()] or [method_condmean()] with argument `type = "bootstrap"`.
#' @param use_samp_ids Logical. If `TRUE`, the sampled subject ids are returned. Otherwise
#' the subject ids from the original dataset are returned.
#' @param first_sample_orig Logical. If `TRUE` the function returns `method$n_samples + 1` samples where
#' the first sample contains the parameter estimates from the original dataset and `method$n_samples`
#' samples contain the parameter estimates from bootstrap samples.
#' If `FALSE` the function returns `method$n_samples` samples containing the parameter estimates from
#' bootstrap samples.
#'
#' @details
#' Bootstrapping refers to resampling of subjects (and their full longitudinal data) from `data` with
#' replacement and and not to resampling of individual rows from `data`.
#' If the model fit fails in the original dataset, an error message is thrown. If
#' the model fit fails in a bootstrap sample, then that bootstrap sample is not considered
#' and replaced by another bootstrap sample. `method$threshold` defines the
#' maximum fraction of model fit failures: if the number of failures overcomes
#' `ceiling(method$threshold * method$n_samples)` the process stops and an error message
#' is displayed.
#'
#' @inherit as_draws return
get_bootstrap_draws <- function(
    longdata,
    method,
    use_samp_ids = FALSE,
    first_sample_orig = FALSE
) {
    n_samples <- ife(first_sample_orig, method$n_samples + 1, method$n_samples)

    samples <- vector("list", length = n_samples)
    current_sample <- 1
    failed_samples <- 0
    failure_limit <- ceiling(method$threshold * n_samples)

    initial_sample <- get_mmrm_sample(
        ids = longdata$ids,
        longdata = longdata,
        method = method,
        optimizer = c("L-BFGS-B", "BFGS")
    )

    if (initial_sample$failed) {
        stop("Fitting MMRM to original dataset failed")
    }

    optimizer <- list(
        "L-BFGS-B" = NULL,
        "BFGS" = initial_sample[c("beta", "theta")]
    )

    if (first_sample_orig) {
        samples[[1]] <- initial_sample
        current_sample <- current_sample + 1
    }

    while (current_sample <= n_samples & failed_samples <= failure_limit) {

        ids_boot <- longdata$sample_ids()
        sample_boot <- get_mmrm_sample(
            ids = ids_boot,
            longdata = longdata,
            method = method,
            optimizer = optimizer
        )

        if (sample_boot$failed) {
            failed_samples <- failed_samples + 1
            if (failed_samples > failure_limit) {
                msg <- "More than %s failed fits. Try using a simpler covariance structure"
                stop(sprintf(msg, failure_limit))
            }
        } else {
            if (!use_samp_ids) {
                sample_boot$ids <- longdata$ids
            }
            samples[[current_sample]] <- sample_boot
            current_sample <- current_sample + 1
        }
    }
    ret <- as_draws(
        method = method,
        samples = as_sample_list(samples),
        data = longdata,
        formula = as_simple_formula(longdata$vars),
        n_failures = failed_samples
    )
    return(ret)
}


#' Fit the base imputation model for the jackknife procedure
#'
#' @description
#' Fit the base imputation model using a ML/REML approach on the original dataset
#' and on each leave-one-subject-out sample as per the jackknife procedure. Returns the
#' parameter estimates from all the fits.
#'
#' @param longdata R6 `longdata` object containing all relevant input data information.
#' @param method A `method` object as generated by [method_condmean()] with `type = "jackknife"`.
#'
#' @details
#' If there is a model fit failure, the process stops and an error is displayed.
#'
#' @importFrom parallel mclapply
#'
#' @inherit as_draws return
get_jackknife_draws <- function(longdata, method, mc.cores=1) {

    ids <- longdata$ids
    # samples <- vector("list", length = length(ids) + 1)

    samples1 <- list(get_mmrm_sample(
        ids = ids,
        longdata = longdata,
        method = method,
        optimizer = c("L-BFGS-B", "BFGS")
    ))

    optimizer <- list(
        "L-BFGS-B" = NULL,
        "BFGS" = samples[[1]][c("beta", "theta")]
    )

    ids_jack <- lapply(seq_along(ids), function(i) ids[-i])

    # for (i in seq_along(ids)) {
    samples2 = mclapply(seq_along(ids),function(i){
        ids_jack <- ids[-i]
        sample <- get_mmrm_sample(
            ids = ids_jack,
            longdata = longdata,
            method = method,
            optimizer = optimizer
        )
        if (sample$failed) {
            stop("Jackknife sample failed")
        }
        # samples[[i + 1]] <- sample
        sample
    },mc.cores = mc.cores)

    samples = c(samples1,samples2)

    ret <- as_draws(
        method = method,
        samples = as_sample_list(samples),
        data = longdata,
        formula = as_simple_formula(longdata$vars),
        n_failures = 0
    )
    return(ret)
}


#' Fit MMRM and returns parameter estimates
#'
#' @description
#' `get_mmrm_sample` fits the base imputation model using a ML/REML approach.
#' Returns the parameter estimates from the fit.
#'
#' @param ids vector of characters containing the ids of the subjects.
#' @param longdata R6 `longdata` object containing all relevant input data information.
#' @param method A `method` object as generated by either
#' [method_approxbayes()] or [method_condmean()].
#' @param optimizer vector of characters defining the optimizer to be used.
#' Every optimizer must be one of the [stats::optim()] function. The list of possible
#' optimizers are `r sapply(formals(fun = stats::optim)$method, function(x) paste0(x, ","))[-1]`.
#'
#' @inherit as_sample_single return
get_mmrm_sample <- function(ids, longdata, method, optimizer) {

    vars <- longdata$vars
    dat <- longdata$get_data(ids, nmar.rm = TRUE, na.rm = TRUE)
    model_df <- as_model_df(dat, as_simple_formula(vars))

    sample <- fit_mmrm_multiopt(
        designmat = model_df[, -1, drop = FALSE],
        outcome = as.data.frame(model_df)[, 1],
        subjid = dat[[vars$subjid]],
        visit = dat[[vars$visit]],
        group = dat[[vars$group]],
        cov_struct = method$covariance,
        REML = method$REML,
        same_cov = method$same_cov,
        optimizer = optimizer
    )

    if (sample$failed) {
        ret <- as_sample_single(
            ids = ids,
            failed = TRUE
        )
    } else {
        ret <- as_sample_single(
            ids = ids,
            failed = FALSE,
            beta = sample$beta,
            sigma = sample$sigma,
            theta = sample$theta
        )
    }
    return(ret)
}


#' Set to NA outcome values that would be MNAR if they were missing
#' (i.e. which occur after an ICE handled using a reference-based imputation strategy)
#'
#' @param longdata R6 `longdata` object containing all relevant input data information.
#'
#' @return
#' A `data.frame` containing `longdata$get_data(longdata$ids)`, but MNAR outcome
#' values are set to `NA`.
extract_data_nmar_as_na <- function(longdata) {
    # remove non-MAR data
    data <- longdata$get_data(longdata$ids, nmar.rm = FALSE, na.rm = FALSE)
    is_mar <- unlist(longdata$is_mar)
    data[!is_mar, longdata$vars$outcome] <- NA
    return(data)
}


#' @rdname draws
#' @export
draws.bayes <- function(data, data_ice = NULL, vars, method) {

    if (!is.na(method$seed)) {
        set.seed(method$seed)
    }

    longdata <- longDataConstructor$new(data, vars)
    longdata$set_strategies(data_ice)

    data2 <- extract_data_nmar_as_na(longdata)

    # compute design matrix
    frm <- as_simple_formula(vars)
    model_df <- as_model_df(data2, frm)

    # scale input data
    scaler <- scalerConstructor$new(model_df)
    model_df_scaled <- scaler$scale(model_df)

    fit <- fit_mcmc(
        designmat = model_df_scaled[, -1, drop = FALSE],
        outcome = model_df_scaled[, 1, drop = TRUE],
        group = data2[[vars$group]],
        visit = data2[[vars$visit]],
        subjid = data2[[vars$subjid]],
        n_imputations = method$n_samples,
        burn_in = method$burn_in,
        seed = method$seed,
        burn_between = method$burn_between,
        same_cov = method$same_cov,
        verbose = method$verbose
    )

    # set names of covariance matrices
    fit$samples$sigma <- lapply(
        fit$samples$sigma,
        function(sample_cov) {
            lvls <- levels(data2[[vars$group]])
            sample_cov <- ife(
                method$same_cov == TRUE,
                rep(sample_cov, length(lvls)),
                sample_cov
            )
            setNames(sample_cov, lvls)
        }
    )

    # unscale samples
    samples <- mapply(
        function(x, y) list("beta" = x, "sigma" = y),
        lapply(fit$samples$beta, scaler$unscale_beta),
        lapply(fit$samples$sigma, function(covs) lapply(covs, scaler$unscale_sigma)),
        SIMPLIFY = FALSE
    )

    # set ids associated to each sample
    samples <- lapply(
        samples,
        function(x) {
            as_sample_single(
                ids = longdata$ids,
                beta = x$beta,
                sigma = x$sigma,
                failed = FALSE
            )
        }
    )

    result <- as_draws(
        method = method,
        samples = as_sample_list(samples),
        data = longdata,
        fit = fit$fit,
        formula = frm,
        n_failures = 0
    )

    return(result)
}




#' Print `draws` object
#'
#' @param x A `draws` object generated by [draws()].
#' @param ... not used.
#' @export
print.draws <- function(x, ...) {

    frm <- as.character(x$formula)
    frm_str <- sprintf("%s ~ %s", frm[[2]], frm[[3]])

    meth <- switch(
         class(x$method)[[2]],
         "approxbayes" = "Approximate Bayes",
         "condmean" = "Conditional Mean",
         "bayes" = "Bayes"
    )

    method <- x$method
    method$n_samples <- ife(
        is.null(method$n_samples),
        "NULL",
        method$n_samples
    )

    meth_args <- vapply(
        mapply(
            function(x, y) sprintf("    %s: %s", y, x),
            method,
            names(method),
            USE.NAMES = FALSE,
            SIMPLIFY = FALSE
        ),
        identity,
        character(1)
    )

    n_samp <- length(x$samples)
    n_samp_string <- ife(
        has_class(x$method, "condmean"),
        sprintf("1 + %s", n_samp - 1),
        as.character(n_samp)
    )

    string <- c(
        "",
        "Draws Object",
        "------------",
        sprintf("Number of Samples: %s", n_samp_string),
        sprintf("Number of Failed Samples: %s", x$n_failures),
        sprintf("Model Formula: %s", frm_str),
        sprintf("Imputation Type: %s", class(x)[[2]]),
        "Method:",
        sprintf("    Type: %s", meth),
        meth_args,
        ""
    )

    cat(string, sep = "\n")
    return(invisible(x))
}




#' Create object of `sample_single` class
#'
#' @description
#' Creates an object of class `sample_single` which is a named list
#' containing the input parameters and validate them.
#'
#' @param ids Vector of characters containing the ids of the subjects included in the original dataset.
#' @param beta Numeric vector of estimated regression coefficients.
#' @param sigma List of estimated covariance matrices (one for each level of `vars$group`).
#' @param theta Numeric vector of transformed covariances.
#' @param failed Logical. `TRUE` if the model fit failed.
#' @param ids_samp Vector of characters containing the ids of the subjects included in the given sample.
#'
#' @return
#' A named list of class `sample_single`. It contains the following:
#' - `ids` vector of characters containing the ids of the subjects included in the original dataset.
#' - `beta` numeric vector of estimated regression coefficients.
#' - `sigma` list of estimated covariance matrices (one for each level of `vars$group`).
#' - `theta` numeric vector of transformed covariances.
#' - `failed` logical. `TRUE` if the model fit failed.
#' - `ids_samp` vector of characters containing the ids of the subjects included in the given sample.
#'
as_sample_single <- function(
    ids,
    beta = NA,
    sigma = NA,
    theta = NA,
    failed = any(is.na(beta)),
    ids_samp = ids
) {
    x <- list(
        ids = ids,
        failed = failed,
        beta = beta,
        sigma = sigma,
        theta = theta,
        ids_samp = ids_samp
    )
    class(x) <- c("sample_single", "list")
    validate(x)
    return(x)
}


#' Validate `sample_single` object
#'
#' @param x A `sample_single` object generated by [as_sample_single()].
#' @param ... Not used.
#' @export
validate.sample_single <- function(x, ...) {

    assert_that(
        x$failed %in% c(TRUE, FALSE),
        is.character(x$ids),
        length(x$ids) > 1,
        is.character(x$ids_samp),
        length(x$ids_samp) > 1
    )

    if (x$failed == TRUE) {
        assert_that(
            is.na(x$beta),
            is.na(x$sigma),
            is.na(x$theta)
        )
    } else {
        assert_that(
            is.numeric(x$beta),
            all(!is.na(x$beta)),
            is.list(x$sigma),
            !is.null(names(x$sigma)),
            all(vapply(x$sigma, is.matrix, logical(1)))
        )
    }
}


#' Create and validate a `sample_list` object
#'
#' @description
#' Given a list of `sample_single` objects generate by [as_sample_single()],
#' creates a `sample_list` objects and validate it.
#'
#'
#' @param ... A list of `sample_single` objects.
as_sample_list <- function(...) {
    x <- list(...)
    if (length(x) == 1 & class(x[[1]])[[1]] != "sample_single") {
        x <- x[[1]]
    }
    class(x) <- c("sample_list", "list")
    validate(x)
    return(x)
}


#' Validate `sample_list` object
#'
#' @param x A `sample_list` object generated by [as_sample_list()].
#' @param ... Not used.
#' @export
validate.sample_list <- function(x, ...) {
    assert_that(
        is.null(names(x)),
        all(vapply(x, function(x) class(x)[[1]] == "sample_single", logical(1))),
        all(vapply(x, function(x) validate(x), logical(1)))
    )
}


#' Creates a `draws` object
#'
#' @description
#' Creates a `draws` object which is the final output of a call to [draws()].
#'
#' @param method A `method` object as generated by either [method_bayes()],
#' [method_approxbayes()] or [method_condmean()].
#' @param samples A list of `sample_single` objects. See [as_sample_single()].
#' @param data R6 `longdata` object containing all relevant input data information.
#' @param formula Fixed effects formula object used for the model specification.
#' @param n_failures Absolute number of failures of the model fit.
#' @param fit If `method_bayes()` is chosen, returns the MCMC Stan fit object. Otherwise `NULL`.
#'
#' @return
#' A `draws` object which is a named list containing the following:
#' - `data`: R6 `longdata` object containing all relevant input data information.
#' - `method`: A `method` object as generated by either [method_bayes()],
#' [method_approxbayes()] or [method_condmean()].
#' - `samples`: list containing the estimated parameters of interest.
#'   Each element of `samples` is a named list containing the following:
#'   - `ids`: vector of characters containing the ids of the subjects included in the original dataset.
#'   - `beta`: numeric vector of estimated regression coefficients.
#'   - `sigma`: list of estimated covariance matrices (one for each level of `vars$group`).
#'   - `theta`: numeric vector of transformed covariances.
#'   - `failed`: Logical. `TRUE` if the model fit failed.
#'   - `ids_samp`: vector of characters containing the ids of the subjects included in the given sample.
#' - `fit`: if `method_bayes()` is chosen, returns the MCMC Stan fit object. Otherwise `NULL`.
#' - `n_failures`: absolute number of failures of the model fit.
#' Relevant only for `method_condmean(type = "bootstrap")` and `method_approxbayes()`.
#' - `formula`: fixed effects formula object used for the model specification.
#'
as_draws <- function(
    method,
    samples,
    data,
    formula,
    n_failures = NULL,
    fit = NULL
) {
    x <- list(
        data = data,
        method = method,
        samples = samples,
        fit = fit,
        n_failures = n_failures,
        formula = formula
    )

    next_class <- switch(class(x$method)[[2]],
        "approxbayes" = "random",
        "condmean" = "condmean",
        "bayes" = "random"
    )

    class(x) <- c("draws", next_class, "list")
    return(x)
}


#' Validate `draws` object
#'
#' @param x A `draws` object generated by [as_draws()].
#' @param ... Not used.
#' @export
validate.draws <- function(x, ...) {
    assert_that(
        has_class(x$data, "longdata"),
        has_class(x$method, "method"),
        has_class(x$samples, "sample_list"),
        validate(x$samples),
        is.null(x$n_failures) | is.numeric(x$n_failures),
        is.null(x$fit) | has_class(x$fit, "stanfit"),
        has_class(x$formula, "formula")
    )
}
