#' Construct copy-number single sample plot
#'
#' Given a data frame construct a plot to display raw copy number calls for a
#' single sample.
#' @name cnView
#' @param x Object of class data frame with rows representing copy number calls
#' from a single sample. The data frame must contain columns with the following
#' names "chromosome", "coordinate", "cn", and optionally "p_value"
#' (see details).
#' @param y Object of class data frame with rows representing cytogenetic bands
#' for a chromosome. The data frame must contain columns with the following
#' names "chrom", "chromStart", "chromEnd", "name", "gieStain" for plotting the
#' ideogram (optional: see details).
#' @param z Object of class data frame with row representing copy number segment
#' calls. The data frame must contain columns with the following names
#' "chromosome", "start", "end", "segmean" (optional: see details)
#' @param genome Character string specifying a valid UCSC genome (see details).
#' @param chr Character string specifying which chromosome to plot one of
#' "chr..." or "all"
#' @param CNscale Character string specifying if copy number calls supplied are
#' relative (i.e.copy neutral == 0) or absolute (i.e. copy neutral ==2). One of
#' "relative" or "absolute"
#' @param ideogram_txtAngle Integer specifying the angle of cytogenetic labels
#' on the ideogram subplot.
#' @param ideogram_txtSize Integer specifying the size of cytogenetic labels on
#' the ideogram subplot.
#' @param plotLayer Valid ggplot2 layer to be added to the copy number plot.
#' @param ideogramLayer Valid ggplot2 layer to be added to the ideogram
#' sub-plot.
#' @param out Character vector specifying the the object to output, one of
#' "data", "grob", or "plot", defaults to "plot" (see returns).
#' @param segmentColor Character string specifying the color of segment lines. Used only if 
#' Z is not null.
#' @details cnView is able to plot in two modes specified via the `chr`
#' parameter, these modes are single chromosome view in which an ideogram is
#' displayed and genome view where chromosomes are faceted. For the single
#' chromosome view cytogenetic band information is required giving the
#' coordinate, stain, and name of each band. As a convenience cnView stores this
#' information for the following genomes "hg19", "hg38", "mm9", "mm10", and
#' "rn5". If the genome assembly supplied to the `genome` parameter is not one
#' of the 5 afore mentioned genome assemblies cnView will attempt to query the
#' UCSC MySQL database to retrieve this information. Alternatively the user can
#' manually supply this information as a data frame to the `y` parameter, input
#' to the `y` parameter take precedence of input to `genome`.
#'
#' cnView is also able to represent p-values for copy-number calls if they are
#' supplied via the "p_value" column in the argument supplied to x. The presence
#' of this column in x will set a transparency value to copy-number calls with
#' calls of less significance becoming more transparent.
#'
#' If it is available cnView can plot copy-number segment calls on top of raw
#' calls supplied to parameter `x` via the parameter `z`.
#' @examples
#' # Create data
#' chromosome <- 'chr14'
#' coordinate <- sort(sample(0:106455000, size=2000, replace=FALSE))
#' cn <- c(rnorm(300, mean=3, sd=.2), rnorm(700, mean=2, sd=.2), rnorm(1000, mean=3, sd=.2))
#' data <- as.data.frame(cbind(chromosome, coordinate, cn))
#'
#' # Plot raw copy number calls
#' cnView(data, chr='chr14', genome='hg19', ideogram_txtSize=4)
#' @return One of the following, a list of dataframes containing data to be
#' plotted, a grob object, or a plot.
#' @importFrom stats aggregate
#' @export

cnView <- function(x, y=NULL, z=NULL, genome='hg19', chr='chr1',
                   CNscale="absolute", ideogram_txtAngle=45,
                   ideogram_txtSize=5, plotLayer=NULL, ideogramLayer=NULL,
                   out="plot", segmentColor=NULL)
{
    # Perform a basic quality check
    input <- cnView_qual(x, y, z, genome, CNscale=CNscale)
    x <- input[[1]]
    y <- input[[2]]
    z <- input[[3]]

    # Obtain Cytogenetic Band information
    # use y input or query UCSC for the data if it's not preloaded
    preloaded <- c("hg38", "hg19", "mm10", "mm9", "rn5")
    if(is.null(y) && any(genome == preloaded))
    {
        message("genome specified is preloaded, retrieving data...")
        cytobands <- GenVisR::cytoGeno[GenVisR::cytoGeno$genome == genome,]
        cytobands <- cytobands[,-which(colnames(cytobands) == "genome")]
    } else if(is.null(y)) {
        # Obtain data for UCSC genome and extract relevant columns
        memo <- paste0("attempting to query UCSC mySQL database for chromosome",
                       " positions and cytogenetic information")
        message(memo)
        cytobands <- suppressWarnings(multi_cytobandRet(genome=genome))
    } else {
        memo <- paste0("Detected argument supplied to y.. using y for",
                       "position and cytogenetic information")
        message(memo)
        cytobands <- y
    }

    # Create Dummy data and add to x for proper plot dimensions
    fakeStart <- stats::aggregate(data=cytobands, FUN=min, chromStart~chrom)
    colnames(fakeStart) <- c("chromosome", "coordinate")
    fakeEnd <- stats::aggregate(data=cytobands, FUN=max, chromEnd~chrom)
    colnames(fakeEnd) <- c("chromosome", "coordinate")
    dummyData <- rbind(fakeStart, fakeEnd)
    dummyData$chromosome <- as.factor(dummyData$chromosome)
    dummyData <- multi_subsetChr(dummyData, chr)

    # Plot all chromosomes at once if specified
    if(chr == 'all')
    {
        # plot the graphic
        p1 <- cnView_buildMain(x, z=z, dummyData, chr=chr, CNscale = CNscale)
    } else {
        # plot chromosome
        chromosome_plot <- ideoView(cytobands, chromosome=chr,
                                    txtAngle=ideogram_txtAngle,
                                    txtSize=ideogram_txtSize,
                                    plotLayer=ideogramLayer)

        # if requested plot only selected chromosome
        x <- multi_subsetChr(x, chr)
        if(!is.null(z))
        {
            z <- multi_subsetChr(z, chr)
        }

        # build the plot
        CN_plot <- cnView_buildMain(x, dummyData, z=z, chr=chr, CNscale=CNscale,
                                    layers=plotLayer, segmentColor=segmentColor)
    }

    # Decide what to output
    dataOut <- list(main=x, dummyData=dummyData, segments=z, cytobands=cytobands)
    if(!exists("p1", inherits=FALSE))
    {
        p1 <- multi_align(chromosome_plot, CN_plot)
        output <- multi_selectOut(data=dataOut, plot=p1, draw=TRUE, out=out)
    } else {
        output <- multi_selectOut(data=dataOut, plot=p1, draw=FALSE, out=out)
    }

    return(output)
}
