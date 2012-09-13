cv_penalizedSVM <-
function(X, Y, ncv=5, repeats=10, filename=NULL,
					seed=123, avg="none", spread.estimate="none",
					colorize=FALSE, maxiter=1000, maxevals=500,
					fs.method="scad", plotscaddiag=FALSE) {
		#library(penalizedSVM)
		#library(ROCR)
		## remove NAs in stratification and data
		nasY <- which(is.na(Y))
		nasX <- which(apply(X, 1, function(x) all(is.na(x))))
		nas <- unique(c(nasY, nasX))
		if(length(nas)>0) {
			X <- X[-nas,]
			Y <- Y[-nas]
		}
		lambda1.scad <- c(seq(0.01 ,0.05, .01),  seq(0.1,0.5, 0.2), 1 ) 
		# for presentation don't check  all lambdas : time consuming! 
		#lambda1.scad<-lambda1.scad[2:3]
		bounds=t(data.frame(log2lambda1=c(-10, 10)))
		colnames(bounds)<-c("lower", "upper")
		## CV
		cvby <- ceiling(nrow(X)/ncv)
		## initialize the result objects
		sn <- sp <- fitted <- labels <- testdim <- NULL
		fitlist <- testlist <- features <- list()
		it <- 0
		set.seed(seed)
		for(ri in 1:repeats) {
			## find a permutation leaving stratified test/training sets
			## with regard to the class label distributions
			folds <- select_cv_balanced(X, Y, ncv)
			for(i in 1:ncv) {
				it <- it + 1
				sel <- folds[[1]]
				seltrain <- setdiff(1:nrow(X), sel)
				test <- X[sel,]
				testg <- Y[sel]
				train <- X[seltrain,]
				traing <- Y[seltrain]
				## run svmscad
				st <- system.time( scad<- my.svm.fs(train, y=traing, fs.method=fs.method, bounds=bounds, 
								cross.outer= 0, grid.search = "interval",  maxIter = maxiter, 
								inner.val.method = "cv", cross.inner= 5, maxevals=maxevals,
								seed=seed, parms.coding = "log2", show="none", verbose=FALSE ) )		
				scad.test <- predict.penSVM(scad, test, newdata.labels=testg)
				sn <- c(sn, scad.test$sensitivity)
				sp <- c(sp, scad.test$specificity)
				fitted <- cbind(fitted, scad.test$fitted)
				labels <- cbind(labels, testg)
				fitlist[[it]] <- scad
				testlist[[it]] <- scad.test
				features[[it]] <- scad$model$fit.info$model.list$model$w
			} # cv loop
		} # repeat loop

		## plot roc curves
		if(!is.null(filename)) {
			pdf(filename)
		}
		roc(as.vector(fitted),as.vector(labels),measure="tpr",x.measure="fpr",colorize=colorize, avg="none", spread.estimate="none", filter=0)
		title(main="ROC curves averaged over all CV runs")
		auc <- roc(fitted,labels,measure="tpr",x.measure="fpr",colorize=colorize, avg="threshold", spread.estimate="stddev", filter=0)
		title(main="ROC curves averaged over CV runs, with stddev")
		## some diagnostic plots from penalized svm package
		if(plotscaddiag) {
			for(i in 1:length(fitlist)) {
				scad <- fitlist[[i]]
				# 						 
				# create  3 plots on one screen: 
				# 1st plot: distribution of initial points in tuning parameter space
				# 2nd plot: visited lambda points vs. cv errors
				# 3rd plot: the same as the 2nd plot, Ytrain.exclude points are excluded. 
				# The value cv.error = 10^16 stays for the cv error for an empty model ! 
				.plot.EPSGO.parms (scad$model$fit.info$Xtrain, scad$model$fit.info$Ytrain, bounds=bounds, Ytrain.exclude=10^16, plot.name=NULL )
			}
		}
		
		if(!is.null(filename)) {
			dev.off()
		}
		invisible(list(filename=filename, sn=sn, sp=sp, fitted=fitted, labels=labels, fitlist=fitlist, testlist=testlist, features=features, auc=auc, repeats=repeats, ncv=ncv))
	}