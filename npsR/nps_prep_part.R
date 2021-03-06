VERSION <- "1.0.1"

cat("Non-Parametric Shrinkage", VERSION, "\n")

ASSERT <- function(test) {
    if (length(test) == 0) {
        stop(paste("ASSERT fail for empty conditional:",
                   deparse(substitute(test))))
    }

    if (is.na(test)) {
        stop(paste("ASSERT fail for missing value:",
                   deparse(substitute(test))))
    }
    
    if (!test) {
        stop(paste("ASSERT fail:", deparse(substitute(test))))
    }
}

w.quant.o2 <- function(x, nbin) {

    ASSERT(all(x >= 0))
    ASSERT(all(!is.na(x)))

    x <- sort(x, decreasing=FALSE)

    w <- x / sum(x)                     # normalize
    
    sum.wx <- cumsum(w * x)

    cuts <- sum(w * x) * (1:(nbin - 1) / nbin)

    q <- c()

    for (cx in cuts) {
        xL <- max(x[sum.wx < cx])
        xR <- min(x[sum.wx > cx])
        q <- c(q, (xL + xR)/2)
    }
    
    c(min(x), q, max(x))

}

#########################################################################

cargs <- commandArgs(trailingOnly=TRUE)

if (length(cargs) != 4) {
    stop("Usage: Rscript nps_prep_part.R <work dir> <WINSHIFT> <N of eigenvalue partitions> <N of eta hat partitions>")
}

tempprefix <- paste(cargs[1], "/", sep='')

args <- readRDS(paste(tempprefix, "args.RDS", sep=''))

Nt <- args[["Nt"]]
WINSZ <- args[["WINSZ"]]


WINSHIFT <- as.numeric(cargs[2])

if (is.nan(WINSHIFT) || WINSHIFT < 0 || WINSHIFT >= WINSZ) {
    stop("Invalid shift:", cargs[2])
}

nLambdaPT <- as.numeric(cargs[3])
nEtaPT <- as.numeric(cargs[4])

if (is.nan(nLambdaPT) || nLambdaPT < 1) {
    stop("Invalid nLambdaPT:", cargs[3])
}

if (is.nan(nEtaPT) || nEtaPT < 1) {
    stop("Invalid nEtaPT:", cargs[4])
}

#############################################################################

etahat.all <- c()
eval.all <- c()                         # lambda (eigenvalue)

chrom <- 1

for (chrom in 1:22) {
    cat("chrom", chrom, "\n")

    I <- 1

    if (WINSHIFT == 0) {
        winfilepre <-
            paste(tempprefix, "win.", chrom, ".", I, sep='')
    } else {
        winfilepre <-
            paste(tempprefix, "win_", WINSHIFT, ".", chrom, ".", I,
                  sep='')
    }
    
    while (file.exists(paste(winfilepre, ".pruned", ".table", sep=''))) {

        wintab <- read.delim(paste(winfilepre, ".pruned", ".table", sep=''),
                             header=TRUE, sep="\t")

        tailfixfile <- paste(winfilepre, ".pruned", ".tailfix.table", sep='')
                             
        if (file.exists(tailfixfile)) {
            # override
            cat("Using window data residualized on GWAS-sig SNPs: ",
                tailfixfile, "\n")
            
            wintab <- read.delim(tailfixfile, header=TRUE, sep="\t")
        }


        lambda0 <- wintab$lambda
        etahat0 <- wintab$etahat

        etahat0 <- etahat0[lambda0 > 0]
        lambda0 <- lambda0[lambda0 > 0]

#        print(length(lambda0))
        
        etahat.all <- c(etahat.all, etahat0)
        eval.all <- c(eval.all, lambda0)
        
        # move on to next iteration
        I <- I + 1

        if (WINSHIFT == 0) {
            winfilepre <-
                paste(tempprefix, "win.", chrom, ".", I, sep='')
        } else {
            winfilepre <-
                paste(tempprefix, "win_", WINSHIFT, ".", chrom, ".", I, sep='')
        }
    }
}

cat("\n\n\n")
cat("Start partitioning:")
cat("Total number of eigenlocus projections:", length(etahat.all), "\n")

######
# Partition by lambda 
# variance scale to sd scale

lambda.all <- eval.all

lambda.q <- w.quant.o2(sqrt(lambda.all), nLambdaPT)
lambda.q <- lambda.q ** 2
lambda.q[1] <- 0
lambda.q[nLambdaPT + 1] <- lambda.q[nLambdaPT + 1] * 1.1

cat("Partition cut-offs on intervals of eigenvalues:\n")
print(lambda.q)


######
# Partition by eta hat (betahat_H)

betahatH.q <- matrix(NA, nrow=(nEtaPT + 1), ncol=nLambdaPT)

count <- 0
nBetahatH <- array(0, dim=c(nLambdaPT, nEtaPT, 1))
meanBetahatH <- array(0, dim=c(nLambdaPT, nEtaPT, 1))

for (I in 2:length(lambda.q)) {
    etahat.all.sub <- etahat.all[lambda.all > lambda.q[I - 1] &
                                 lambda.all <= lambda.q[I]]
    etahat.all.sub <- abs(etahat.all.sub)

    betahatH.q[, I - 1] <- w.quant.o2(etahat.all.sub, nEtaPT)
    betahatH.q[1, I - 1] <- 0
    betahatH.q[nEtaPT + 1, I - 1] <- betahatH.q[nEtaPT + 1, I - 1] * 1.1 
    
    for (J in 1:nEtaPT) {

        betahatH.lo <- betahatH.q[J, I - 1]
        betahatH.hi <- betahatH.q[J+1, I - 1]
#        print(sum(etahat.all.sub > betahatH.lo &
#                  etahat.all.sub <= betahatH.hi))

        nBetahatH[I - 1, J, 1] <- nBetahatH[I - 1, J, 1] +
            sum(etahat.all.sub > betahatH.lo &
                etahat.all.sub <= betahatH.hi)
        meanBetahatH[I - 1, J, 1] <- meanBetahatH[I - 1, J, 1] +
            sum(etahat.all.sub[(etahat.all.sub > betahatH.lo &
                                etahat.all.sub <= betahatH.hi)])

        count <- count + sum(nBetahatH[I - 1, J, ])
    }
}

ASSERT((count + sum(etahat.all == 0)) == length(lambda.all))

cat("Partition cut-offs on intervals on eta-hat:\n")
print(betahatH.q)

meanBetahatH <- meanBetahatH / nBetahatH

meanBetahatH[is.nan(meanBetahatH)] <- 0

# print(meanBetahatH)


# Save partition boundaries 
partdata <- list()

partdata[["Nt"]] <- Nt
partdata[["nLambdaPT"]] <- nLambdaPT
partdata[["nEtaPT"]] <- nEtaPT

partdata[["lambda.q"]] <- lambda.q
partdata[["betahatH.q"]] <- betahatH.q

if (WINSHIFT == 0) {
    saveRDS(partdata, paste(tempprefix, "part.RDS", sep=''))
} else {
    saveRDS(partdata,
            paste(tempprefix, "win_", WINSHIFT, ".part.RDS", sep=''))
}

save.image(file=paste(tempprefix, "nps_prep_part.", "win_", WINSHIFT, ".RData",
               sep=''))

cat("Done\n")
