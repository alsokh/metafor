cooks.distance.rma.mv <- function(model, progbar=FALSE, cluster, ...) {

   if (!inherits(model, "rma.mv"))
      stop("Argument 'model' must be an object of class \"rma.mv\".")

   na.act <- getOption("na.action")

   if (!is.element(na.act, c("na.omit", "na.exclude", "na.fail", "na.pass")))
      stop("Unknown 'na.action' specified under options().")

   x <- model

   if (x$k == 1)
      stop("Stopped because k = 1.")

   if (missing(cluster))
      cluster <- 1:x$k.all

   #########################################################################

   ### process cluster variable
   ### note: cluster variable is assumed to be of the same length as the original data passed to the model fitting function
   ###       so we have to apply the same subsetting (if necessary) and removing of missings as done during model fitting

   if (!is.null(x$subset))
      cluster <- cluster[x$subset]

   #cluster <- cluster[x$not.na]

   ### checks on cluster variable

   if (anyNA(cluster))
      stop("No missing values allowed in 'cluster' variable.")

   if (length(cluster[x$not.na]) != x$k)
      stop("Length of variable specified via 'cluster' does not match length of data.")

   ### cluster ids and number of clusters

   ids <- unique(cluster)
   n <- length(ids)

   #########################################################################

   cook.d <- rep(NA_real_, n)
   not.na <- rep(FALSE, n)

   ### calculate inverse of variance-covariance matrix under the full model (needed for the Cook's distances)

   svb <- chol2inv(chol(x$vb))

   ### note: skipping NA cases
   ### also: it is possible that model fitting fails, so that generates more NAs (these NAs will always be shown in output)

   if (progbar)
      pbar <- txtProgressBar(min=0, max=n, style=3)

   for (i in seq_len(n)) {

      if (progbar)
         setTxtProgressBar(pbar, i)

      incl <- cluster %in% ids[i]

      if (any(!x$not.na[incl]))
         next

      not.na[i] <- TRUE

      res <- try(suppressWarnings(rma.mv(x$yi.f, x$V.f, W=x$W.f, mods=x$X.f, intercept=FALSE, random=x$random, struct=x$struct, method=x$method, test=x$test, R=x$R, Rscale=x$Rscale, data=x$mf.r.f, sigma2=ifelse(x$vc.fix$sigma2, x$sigma2, NA), tau2=ifelse(x$vc.fix$tau2, x$tau2, NA), rho=ifelse(x$vc.fix$rho, x$rho, NA), gamma2=ifelse(x$vc.fix$gamma2, x$gamma2, NA), phi=ifelse(x$vc.fix$phi, x$phi, NA), control=x$control, subset=!incl)), silent=TRUE)

      if (inherits(res, "try-error"))
         next

      ### removing an observation could lead to a model coefficient becoming inestimable

      if (any(res$coef.na))
         next

      ### compute dfbeta value(s)

      dfb <- x$beta - res$beta

      ### compute Cook's distance

      cook.d[i]  <- crossprod(dfb,svb) %*% dfb

   }

   if (progbar)
      close(pbar)

   #########################################################################

   if (na.act == "na.omit") {
      out <- cook.d[not.na]
      names(out) <- ids[not.na]
   }

   if (na.act == "na.exclude" || na.act == "na.pass") {
      out <- cook.d
      names(out) <- ids
   }

   if (na.act == "na.fail" && any(!not.na))
      stop("Missing values in results.")

   return(out)

}
