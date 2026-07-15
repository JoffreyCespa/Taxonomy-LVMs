#===============================================================================
# Title: Data Acquisition from PubMed API
# Author(s): Joffrey Marchi et al.
# Objective: Extract article metadata (titles and abstracts) based on latent variable keywords to build the primary corpus.
# Inputs: PubMed API
# Outputs: data/raw/pubmed_raw_extraction.xlsx
#===============================================================================

#-------------------------------------------------------------------------------
#### 0 - Library ####
#-------------------------------------------------------------------------------
rm(list = ls())
library(this.path)
library(biorecap)
library(pubmedR)
library(stringr)
library(textclean)
library(purrr) 
library(tidyverse)
library(parallel)
library(furrr)
library(future)

#-------------------------------------------------------------------------------
#### I - PARAMETERS ####
#-------------------------------------------------------------------------------
dir.root <- this.proj()
setwd(dir.root)

# Ensure output directories exist
dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)

# SECURE API KEY MANAGEMENT
# Do not hardcode your API key in this script before committing to GitHub.
# Set it locally in your .Renviron file using: PUBMED_API_KEY="your_actual_key"
api_key <- Sys.getenv("PUBMED_API_KEY")
if (api_key == "") {
  api_key <- NULL
  warning("No API key found in environment variables. Proceeding with NULL (this may restrict API rate limits).")
}

query <- '(variable[Title] OR class[Title] OR patterns[Title] OR profile[Title] OR model[Title] OR modeling[Title] OR methods[Title] OR method[Title]) AND (latent[Title] OR hidden[Title])'

#-------------------------------------------------------------------------------
#### II - PUBMED DATA EXTRACTION ####
#-------------------------------------------------------------------------------
(res <- pmQueryTotalCount(query = query, api_key = api_key))

D <- pmApiRequest(query = query, limit = res$total_count + 1, api_key = api_key)

build_results <- function(D, query = NA) {
  b <- D$data
  b <- b[which(names(b) == 'PubmedArticle')]
  n <- length(b)
  
  res <- data.frame(source = rep('pubmed', n),
                    query = rep(query, n),
                    pmid = rep(NA, n),
                    authors = rep(NA, n),
                    title = rep(NA, n),
                    doi = rep(NA, n),
                    journal = rep(NA, n),
                    volume = rep(NA, n),
                    issue = rep(NA, n),
                    year = rep(NA, n),
                    month = rep(NA, n),
                    startpage = rep(NA, n),
                    endpage = rep(NA, n),
                    pii = rep(NA, n),
                    ref = rep(NA, n),
                    abstract = rep(NA, n))
  
  for (i in seq_along(b)) {
    res$pmid[i] <- b[[i]]$MedlineCitation$PMID$text
    
    for (j in which(names(b[[i]]$MedlineCitation$Article) == 'ELocationID')) {
      if (b[[i]]$MedlineCitation$Article[[j]]$.attrs['EIdType'] == 'doi') {
        res$doi[i] <- b[[i]]$MedlineCitation$Article[[j]]$text
      } else if (b[[i]]$MedlineCitation$Article[[j]]$.attrs['EIdType'] == 'pii') {
        res$pii[i] <- b[[i]]$MedlineCitation$Article[[j]]$text
      }
    }
    
    res$journal[i] <- b[[i]]$MedlineCitation$Article$Journal$ISOAbbreviation
    if (!is.null(b[[i]]$MedlineCitation$Article$Journal$JournalIssue$Volume)) {res$volume[i] <- b[[i]]$MedlineCitation$Article$Journal$JournalIssue$Volume}
    if (!is.null(b[[i]]$MedlineCitation$Article$Journal$JournalIssue$Issue)) {res$issue[i] <- b[[i]]$MedlineCitation$Article$Journal$JournalIssue$Issue}
    if (!is.null(b[[i]]$MedlineCitation$Article$Journal$JournalIssue$PubDate$Year)) {
      res$year[i] <- b[[i]]$MedlineCitation$Article$Journal$JournalIssue$PubDate$Year
    } else if (!is.null(b[[i]]$MedlineCitation$Article$Journal$JournalIssue$PubDate$MedlineDate)) {
      res$year[i] <- substr(b[[i]]$MedlineCitation$Article$Journal$JournalIssue$PubDate$MedlineDate, 1, 4)
    }
    if (!is.null(b[[i]]$MedlineCitation$Article$Journal$JournalIssue$PubDate$Month)) {res$month[i] <- b[[i]]$MedlineCitation$Article$Journal$JournalIssue$PubDate$Month}
    
    if (!is.null(b[[i]]$MedlineCitation$Article$Pagination$StartPage)) {res$startpage[i] <- b[[i]]$MedlineCitation$Article$Pagination$StartPage}
    if (!is.null(b[[i]]$MedlineCitation$Article$Pagination$EndPage)) {res$endpage[i] <- b[[i]]$MedlineCitation$Article$Pagination$EndPage}
    
    res$title[i] <- paste0(b[[i]][['MedlineCitation']][['Article']][['ArticleTitle']], collapse = '')
    
    if (length(b[[i]][['MedlineCitation']][['Article']][['Abstract']][['AbstractText']]) == 1) {
      s <- b[[i]][['MedlineCitation']][['Article']][['Abstract']][['AbstractText']]
    } else {
      s <- ''
      for (j in which(names(b[[i]][['MedlineCitation']][['Article']][['Abstract']]) == "AbstractText")) {
        for (k in which(names(b[[i]][['MedlineCitation']][['Article']][['Abstract']][[j]]) != ".attrs")) {
          s <- paste0(s, b[[i]][['MedlineCitation']][['Article']][['Abstract']][[j]][[k]], collapse = '')
        }
      }
    }
    res$abstract[i] <- s
    
    s <- lapply(which(names(b[[i]]$MedlineCitation$Article$AuthorList) == 'Author'), function(j) {
      paste(b[[i]]$MedlineCitation$Article$AuthorList[[j]]$LastName, b[[i]]$MedlineCitation$Article$AuthorList[[j]]$Initials)
    })
    
    res$authors[i] <- paste0(s, collapse = ', ')
    
    res$ref[i] <- paste0(res$authors[i], '. ', res$title[i], ' ', res$journal[i], '. ', res$year[i], ' ', res$month[i])
    if (is.na(res$volume[i])) {
      res$ref[i] <- paste0(res$ref[i], ':', res$pii[i])
    } else {
      res$ref[i] <- paste0(res$ref[i], ';', res$volume[i], '(', res$issue[i], '):', res$startpage[i], '-', res$endpage[i])
    }
  }
  class(res) <- c("preprints", class(res))
  res
}

bddD <- build_results(D)
bddD <- bddD %>% 
  tidyr::unnest(cols = "abstract")

#-------------------------------------------------------------------------------
#### III - EXPORT ####
#-------------------------------------------------------------------------------
writexl::write_xlsx(bddD, "data/raw/pubmed_raw_extraction.xlsx")