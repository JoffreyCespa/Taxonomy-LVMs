#===============================================================================
# Title: Data Cleaning
# Author(s): Joffrey Marchi et al.
# Objective: Clean the raw PubMed data, standardise titles, and filter out records missing essential text based on the Govindasamy framework.
# Inputs: data/raw/pubmed_raw_extraction.xlsx
# Outputs: data/intermediate/pubmed_cleaned_govindasamy.xlsx
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
#### I - PARAMETERS & DATA IMPORT ####
#-------------------------------------------------------------------------------
dir.root <- this.proj()
setwd(dir.root)

# Ensure intermediate directory exists
dir.create("data/intermediate", recursive = TRUE, showWarnings = FALSE)

bdd1 <- readxl::read_excel("data/raw/pubmed_raw_extraction.xlsx")

#-------------------------------------------------------------------------------
#### II - DATA CLEANING ####
#-------------------------------------------------------------------------------
# Data cleaning following Govindasamy et al. 2021 framework

bdd2 <- bdd1 %>%
  dplyr::mutate(title_new = str_to_lower(title), # Create a column with the title in lowercase
                title_new = textclean::strip(title_new, apostrophe.remove = TRUE), # Remove apostrophes from the title
                doi_new = str_remove(doi, pattern = "doi."), # Remove 'doi.' prefix from the DOI string
  )

bdd3 <- bdd2 %>%
  dplyr::distinct(title_new, .keep_all = TRUE) # Remove duplicates based on the new title

bdd4 <- bdd3 %>%
  dplyr::filter(!is.na(title_new) | title_new == "") # Remove articles without a title

bdd5 <- bdd4 %>%
  dplyr::filter(!is.na(abstract)) %>%
  dplyr::filter(abstract != "") # Remove articles without an abstract

#-------------------------------------------------------------------------------
#### III - EXPORT ####
#-------------------------------------------------------------------------------
writexl::write_xlsx(bdd5, "data/intermediate/pubmed_cleaned_govindasamy.xlsx")