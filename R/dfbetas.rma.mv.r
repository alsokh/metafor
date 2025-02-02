dfbetas.rma.mv <- function(model, progbar=FALSE, cluster, reestimate=TRUE, parallel="no", ncpus=1, cl, ...) {

   mstyle <- .get.mstyle("crayon" %in% .packages())

   .chkclass(class(model), must="rma.mv", notav="robust.rma")

   na.act <- getOption("na.action")

   if (!is.element(na.act, c("na.omit", "na.exclude", "na.fail", "na.pass")))
      stop(mstyle$stop("Unknown 'na.action' specified under options()."))

   x <- model

   parallel <- match.arg(parallel, c("no", "snow", "multicore"))

   if (parallel == "no" && ncpus > 1)
      parallel <- "snow"

   if (missing(cl))
      cl <- NULL

   if (!is.null(cl) && inherits(cl, "SOCKcluster")) {
      parallel <- "snow"
      ncpus <- length(cl)
   }

   if (parallel == "snow" && ncpus < 2)
      parallel <- "no"

   if (parallel == "snow" || parallel == "multicore") {

      if (!requireNamespace("parallel", quietly=TRUE))
         stop(mstyle$stop("Please install the 'parallel' package for parallel processing."))

      ncpus <- as.integer(ncpus)

      if (ncpus < 1L)
         stop(mstyle$stop("Argument 'ncpus' must be >= 1."))

   }

   if (!progbar) {
      pbo <- pbapply::pboptions(type="none")
      on.exit(pbapply::pboptions(pbo), add=TRUE)
   }

   misscluster <- ifelse(missing(cluster), TRUE, FALSE)

   if (misscluster)
      cluster <- seq_len(x$k.all)

   ddd <- list(...)

   .chkdots(ddd, c("time", "LB"))

   if (.isTRUE(ddd$time))
      time.start <- proc.time()

   #########################################################################

   ### process cluster variable

   # note: cluster variable is assumed to be of the same length as the size of
   # the original dataset passed to the model fitting function and so we apply
   # the same subsetting and removing of missings (if necessary) as was done
   # during model fitting

   if (!is.null(x$subset))
      cluster <- cluster[x$subset]

   cluster.f <- cluster

   cluster <- cluster[x$not.na]

   ### checks on cluster variable

   if (anyNA(cluster.f))
      stop(mstyle$stop("No missing values allowed in 'cluster' variable."))

   if (length(cluster.f) == 0L)
      stop(mstyle$stop(paste0("Cannot find 'cluster' variable (or it has zero length).")))

   if (length(cluster) != x$k)
      stop(mstyle$stop(paste0("Length of variable specified via 'cluster' (", length(cluster), ") does not match length of data (", x$k, ").")))

   ### cluster ids and number of clusters

   ids <- unique(cluster)
   n <- length(ids)

   #########################################################################

   if (parallel == "no")
      res <- pbapply::pblapply(seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate)

   if (parallel == "multicore")
      res <- pbapply::pblapply(seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate, cl=ncpus)
      #res <- parallel::mclapply(seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate, mc.cores=ncpus)

   if (parallel == "snow") {
      if (is.null(cl)) {
         cl <- parallel::makePSOCKcluster(ncpus)
         on.exit(parallel::stopCluster(cl), add=TRUE)
      }
      if (.isTRUE(ddd$LB)) {
         res <- parallel::parLapplyLB(cl, seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate)
         #res <- parallel::clusterApplyLB(cl, seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate)
      } else {
         res <- pbapply::pblapply(seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate, cl=cl)
         #res <- parallel::parLapply(cl, seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate)
         #res <- parallel::clusterApply(cl, seq_len(n), .dfbetas.rma.mv, obj=x, parallel=parallel, cluster=cluster, ids=ids, reestimate=reestimate)
      }
   }

   dfbs <- lapply(res, function(x) x$dfbs)
   dfbs <- do.call(rbind, dfbs)

   #########################################################################

   if (na.act == "na.omit") {
      out <- dfbs
      if (misscluster) {
         rownames(out) <- x$slab[x$not.na]
      } else {
         rownames(out) <- ids
         out <- out[order(ids),,drop=FALSE]
      }
   }

   if (na.act == "na.exclude" || na.act == "na.pass") {

      ids.f <- unique(cluster.f)

      out <- matrix(NA_real_, nrow=length(ids.f), ncol=x$p)
      out[match(ids, ids.f),] <- dfbs

      if (misscluster) {
         rownames(out) <- x$slab
      } else {
         rownames(out) <- ids.f
         out <- out[order(ids.f),,drop=FALSE]
      }

   }

   if (na.act == "na.fail" && any(!x$not.na))
      stop(mstyle$stop("Missing values in results."))

   colnames(out) <- rownames(x$beta)

   out <- data.frame(out)

   if (.isTRUE(ddd$time)) {
      time.end <- proc.time()
      .print.time(unname(time.end - time.start)[3])
   }

   return(out)

}
