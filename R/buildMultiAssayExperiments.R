#' A unifying pipeline function for building MultiAssayExperiment objects
#'
#' This is the main function of the package. It brings together all of the
#' exported functions to load, create, and save data objects on ExperimentHub
#' and return documented metadata
#'
#' @inheritParams loadData
#'
#' @param TCGAcodes character(1) A single TCGA cancer code
#'
#' @param analyzeDate The GDAC Firehose analysis run date, only '20160128' is
#' supported
#'
#' @param version character(1) A version string for versioning data runs
#' (such as "1.0.0")
#'
#' @param outDataDir The single string indicating piecewise data product save
#' location
#'
#' @param upload logical (default FALSE) Whether to save data products to the
#' cloud infrastructure, namely AWS S3 ExperimentHub bucket
#'
#' @param update logical (default TRUE) Whether to update the metadata data
#' from the data pooled by the function
#'
#' @export
buildMultiAssayExperiment <-
    function(
    TCGAcode,
    dataType = c("RNASeqGene", "RNASeq2Gene", "RNASeq2GeneNorm",
        "miRNASeqGene", "CNASNP", "CNVSNP", "CNASeq", "CNACGH", "Methylation",
        "mRNAArray", "miRNAArray", "RPPAArray", "Mutation", "GISTIC"),
    runDate = "20160128", analyzeDate = "20160128", version,
    serialDir = "data/raw", outDataDir = "data/bits", mapDir = "data/maps",
    upload = FALSE, update = TRUE, force = FALSE)
{
    if (missing(TCGAcode))
        stop("Provide a valid and available TCGA disease code: 'TCGAcode'")

    message("\n######\n",
            "\nProcessing ", TCGAcode, " : )\n",
            "\n######\n")

    ## slotNames in FirehoseData RTCGAToolbox class
    targets <- c("RNASeqGene", "RNASeq2Gene", "RNASeq2GeneNorm",
        "miRNASeqGene", "CNASNP", "CNVSNP", "CNASeq", "CNACGH",
        "Methylation", "mRNAArray", "miRNAArray", "RPPAArray",
        "Mutation", "GISTIC")

    dataType <- match.arg(dataType, targets, several.ok = TRUE)
    names(dataType) <- dataType

    ## Download raw data if not already serialized
    saveRTCGAdata(runDate, TCGAcode, dataType = dataType,
        analyzeDate = analyzeDate, directory = serialDir,
        force = force)
    dataFull <- loadData(cancer = TCGAcode, dataType = dataType,
        runDate = runDate, serialDir = serialDir, mapDir = mapDir,
        force = force)
    # builddate
    buildDate <- Sys.time()
    # metadata
    metadata <- list(buildDate, TCGAcode, runDate, analyzeDate,
        devtools::session_info())
    names(metadata) <- c("buildDate", "cancerCode", "runDate",
        "analyzeDate", "session_info")

    mustData <- list(dataFull[["colData"]], dataFull[["sampleMap"]],
        metadata)
    mustNames <- paste0(TCGAcode, "_",
        c("colData", "sampleMap", "metadata"), "-", runDate)
    names(mustData) <- mustNames

    # add colData, sampleMap, and metadata to ExperimentList
    if (length(dataFull[["experiments"]]))
        allObjects <- c(as(dataFull[["experiments"]], "list"), mustData)

    # save rda files and upload them to S3
    saveNupload(
        dataList = allObjects, cancer = TCGAcode, directory = outDataDir,
        version = version, upload = upload
    )

    # update MAEOinfo.csv
    if (update)
        updateInfo(
            dataList = allObjects, cancer = TCGAcode,
            folderPath = outDataDir, version = version
        )
    allObjects
}
