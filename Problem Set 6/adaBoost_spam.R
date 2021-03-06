################################################################################
####################   Problemset 6 - adaboost algorithm    ####################
################################################################################

# Author:       Felix Gutmann
# Programm:     Barcelona graduate school of economics - M.S. Data Science 
# Course:       15D012 - Advanced Computational Methods (Term 2)
# Last update:  05.03.16

################################################################################
### Preamble
################################################################################

### Clear workspace
rm(list = ls())

### Set working directory
setwd('/Users/felix/Documents/GSE/Term 2/15D012 Advanced Computational Methods/Probelmsets/GSE/15D012 - Advanced Computational Methods/PS6')

### Load Packages 
if (!require("rpart")) 	 	install.packages("rpart");   library(rpart)
if (!require("adabag")) 	install.packages("adabag");  library(adabag)
if (!require("ggplot2")) 	install.packages("ggplot2"); library(ggplot2)

### Auxilliary functions
  
  # Accuracy
  errorRate <- function( true , predicted ){
    n <- length( true )
    ac <- sum( true != predicted ) / n
    return(ac)
  }

### Initialize auxilliary functions
spam <- read.table('spambase.data', sep = ',')

################################################################################
# Initialize adaboost function
################################################################################

adaBoost <- function( formula , data , test = NULL, depth = 1, noTrees = 1, 
                      trace = TRUE ) 
{ 
  
  # Enjure correct scoping 
  environment(formula) <- environment( ) 
  # Get name of response variable
  Nresponse <- all.vars( formula )[1]
  
  # Check for correct format of training
  if( is.data.frame( data ) == FALSE ){
    stop("Error: training must be an object of class data frame")
  } 
  # Check for correct format of test if present
  if( is.null( test ) == FALSE & is.data.frame(test) == FALSE ){ 
    stop("Error: The argument test must be an object of class data frame")
  }
  # Check for trace
  if( is.logical( trace ) == FALSE ){
    stop("Error: trace must be class logical")
  }
  # Check if data are empty - training
  if( ncol(data) == 0 | nrow(data) == 0 ){
    stop("Error: The argument training can't be empty")
  } 
  # Check if data are empty - test if present
  if( is.null( test ) == FALSE & ncol(test) == 0 | nrow(test) == 0 ){
    stop("Error: The argument test can't be empty")
  } 
  # Convert response variable if necessary and check if empty
  if( Nresponse %in% names(data) == FALSE  ){ 
    stop("Error: Response varaible is not an element of data") } 
  # Check if variable is a factor - Convert if not
  y <- data[ , Nresponse ]

  if ( is.factor( y ) == FALSE ) { 
    data$y <- as.factor( y )
    warning("Warning: Response converted to factors")
  }
  
  # Compute domensions and initialise weights
  N       <- nrow( data )
  w       <- rep( (1/N) , N )
  # Initialize alpha and classification 
  global.alpha   <- rep( NA, noTrees )
  classifiers    <- matrix( NA, nrow = N, ncol = noTrees )
  accuracy       <- rep( NA, noTrees )
  
  # Initialize test storage obeject in case of testing
  if( is.null( test ) == FALSE ){ 
    M <- nrow( test )
    classifiers.test <- matrix( NA, nrow = M, ncol = noTrees )
  }
  
  # Run learning procedure
  for( i in 1:noTrees){
    # Compute model with current weights
    temp.model <- rpart( formula ,
                         data     = data , 
                         weights = w , 
                         maxdepth = depth ) 
    # Prediction current model
    prediction <- predict( temp.model, newdata=data, type = 'class') 
    # Compute errors and update parameters 
    error.ind  <- ifelse( prediction == y , 0, 1 )
    errors     <- sum( w * error.ind ) / sum( w )
    alpha      <- log( ( 1 - errors ) / errors )
    w          <- w * exp( alpha * error.ind ) 
    
    # Store variables
    global.alpha[i]   <- alpha 
    classifiers[,i]   <- ifelse( as.numeric( prediction ) == 2, 1, -1 )
    acc <- sum( error.ind )  / length( y )
    accuracy[i]       <- acc
    
    if( trace == TRUE ){
      cat( 'Training accuracy tree ', i , ': ' , acc , '\n' )
    } 
    
    # Get prediction with current model for test set if specified
    if( is.null( test ) == FALSE ){ 
      classifiers.test[,i] <- ifelse( as.numeric( 
                                    predict( temp.model, 
                                             newdata = test, 
                                             type = 'class' ) 
                                    ) == 2, 1, -1)
    }
  }
  # Design final classifier - If test set available add to output
  if( is.null( test ) == FALSE ){
    final.prediction.training <- sign( classifiers      %*% global.alpha ) 
    final.prediction.test     <- sign( classifiers.test %*% global.alpha ) 
    output <- list( predLabels     = as.numeric( final.prediction.training ),
                    errorTRACE     = accuracy, 
                    predLabelsTest = as.numeric( final.prediction.test ) )
  # If no test set output only training set predictions
  } else { 
    final.prediction.training <- sign( classifiers      %*% global.alpha ) 
    output <- list( predLabels = as.numeric( final.prediction.training ),
                    errorTRACE = accuracy
                  )
  }

  # Return output
  return(output)
  
} 

################################################################################
# Predict spam data set
################################################################################

# Adjust and split data
spam$V58      <- as.factor( ifelse( spam$V58 == 0, -1, 1 ) ) 
permutation   <- sample.int(nrow(spam))
size          <- floor( 0.8 * length(permutation) )
trl           <- permutation[1:size]
tel           <- setdiff(permutation, trl)
training.data <- spam[trl, ]
test.data     <- spam[tel,]

# Final data sets
x.test     <- test.data[,!(names(test.data) %in% c('V58') )]
y.test     <- ifelse( as.numeric( test.data[,58] ) == 2, 1, -1)
y.training <- ifelse( as.numeric( training.data[,58] )  == 2, 1, -1)

# Specify model arguments
model       <- formula( V58 ~. )
data        <- training.data 
test        <- x.test
depth       <- 5
trace       <- FALSE 

# Number of repitition and iterations
itterations <- 30
step        <- 1
ntreeseq    <- seq( 1, itterations, step )

# Initialize storage objects
training.error    <- rep( NA , itterations )
test.error        <- rep( NA , itterations )
benchmarkTraining <- rep( NA , itterations ) 
benchmarkTest     <- rep( NA , itterations )

# Run predictions for function and package
for( i in 1:itterations){

# Print iteration
cat( 'Itteration :', i , '\n' )

# Number of iterations
ntree.temp <- ntreeseq[i]

# Fit model with implemented function
tempPrediction <- adaBoost( formula = model, 
                            data    = training.data , 
                            test    = test.data, 
                            depth   = depth,
                            noTrees = ntree.temp,
                            trace   = trace 
                          )

# Compute error for training and test
training.error[i] <- errorRate( y.training, tempPrediction$predLabels  )
test.error[i]     <- errorRate( y.test, tempPrediction$predLabelsTest  )  

# Compute benchmark model form adabag package
benchmark <- boosting(model, 
                      data    = training.data,
                      mfinal  = ntree.temp, 
                      control = rpart.control(depth=depth)
                     )

# Predict training and test data
predBenchmarkTR <- predict(benchmark, newdata = training.data[,!(names(training.data) %in% c('V58') )] )
predBenchmarkTE <- predict(benchmark, newdata = test.data )

# Compute error rate for benchmark model
benchmarkTraining[i] <- errorRate( y.training , as.numeric( predBenchmarkTR$class ) )
benchmarkTest[i]     <- errorRate( y.test , as.numeric ( predBenchmarkTE$class ) )

}

################################################################################

################################################################################

# Find max for x and y axis
maxx <- max(ntreeseq)
maxy <- max( training.error, test.error, benchmarkTraining , benchmarkTest )

# Plot results
pdf( 'adaBoost.pdf' )
plot( ntreeseq , training.error, 
      type = 'l', 
      xlim = c(1,maxx), 
      ylim = c(0,maxy), 
      xlab = '',
      ylab = '',
      col  = 'red')
par(new = TRUE)
plot( ntreeseq , test.error, 
      type = 'l', 
      xlim = c(1,maxx), 
      ylim = c(0,maxy), 
      xlab = '',
      ylab = '',
      col  = 'blue')
par(new = TRUE)
plot( ntreeseq , benchmarkTraining, 
      type = 'l', 
      xlim = c(1,maxx), 
      ylim = c(0,maxy), 
      xlab = '',
      ylab = '',
      col  = 'green')
par(new = TRUE)
plot( ntreeseq , benchmarkTest, 
      type = 'l', 
      xlim = c(1,maxx), 
      ylim = c(0,maxy), 
      xlab = 'Number of iterations',
      ylab = 'Error ( in % ) ',
      col  = 'black')
title( 'Developement of error')
legend('bottomleft', 
       c('Training Error - function (3680 obs.)','Test Error - function (921 obs.)',
         'Training Error - package (3680 obs.)','Test Error - package (921 obs.)') , 
       lty=1, 
       col=c('red', 'blue', 'green',' black'), 
       bty='n', 
       cex=.75)
dev.off()

################################################################################

################################################################################