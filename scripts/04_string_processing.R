#===============================================================================
# Title: Text Normalisation and Lemmatisation
# Author(s): Joffrey Marchi et al.
# Objective: Standardise extracted model names through lowercasing, prefix/suffix removal, and systematic UK to US spelling conversion.
# Inputs: data/intermediate/pubmed_extracted_models_gemma3_27b.xlsx
# Outputs: data/intermediate/models_cleaned_deduplicated_gemma3_27b.xlsx
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
library(stringi) 

#-------------------------------------------------------------------------------
#### I - PARAMETERS & DATA IMPORT ####
#-------------------------------------------------------------------------------
dir.root <- this.proj()
setwd(dir.root)

tbl <- readxl::read_excel("data/intermediate/pubmed_extracted_models_gemma3_27b.xlsx")

#-------------------------------------------------------------------------------
#### II - INITIAL STRING CLEANING ####
#-------------------------------------------------------------------------------
tbl1 <- tbl %>%
  tidyr::separate_rows(c(summary), sep = "/")

tbl3 <- tbl1 %>%
  dplyr::mutate(summary2 = str_replace_all(summary, c("\\." = "", "-" = " ")),
                summary2 = str_replace_all(summary2, c("\\." = "", "‑" = " ")),
                summary2 = str_trim(str_squish(summary2)))

tbl4 <- tbl3 %>%
  dplyr::mutate(summary2 = str_to_lower(summary2)) %>%
  dplyr::mutate(summary2 = str_replace_all(summary2, pattern = "bi factor", replacement = "bifactor"),
                summary2 = str_replace_all(summary2, pattern = "auto encoder", replacement = "autoencoder"))

tbl5 <- tbl4 %>%
  dplyr::filter(!str_detect(summary2, "none detected")) %>%
  dplyr::filter(!is.na(summary2)) %>%
  dplyr::filter(summary2 != "") %>%
  dplyr::filter(summary2 != "no latent model")

tbl6 <- tbl5 %>%
  dplyr::mutate(year = as.numeric(year)) %>%
  dplyr::arrange(summary2, year) %>%
  dplyr::distinct(summary2, .keep_all = TRUE)

#-------------------------------------------------------------------------------
#### III - TEXT NORMALISATION & LEMMATISATION ####
#-------------------------------------------------------------------------------
# 1. Extraction and initial cleaning of the list
bad_values <- c('na', 'nan', 'n.a.', 'n/a', 'uncertain')

names <- tbl6 %>%
  dplyr::pull(summary2) %>%          
  as.character() %>%          
  keep(~ str_trim(.x) != "") %>% 
  discard(~ str_to_lower(.x) %in% bad_values)

# 2. Preparation of replacement dictionaries from UK to US spelling
z_roots <- c(
  "parameter", "regular", "factor", "marginal", "initial", "general",
  "stabil", "discret", "vector", "orthogonal", "random", "linear",
  "normal", "standard", "categor"
)

# Explicit UK -> US pairs
uk_us_pairs <- c(
  "\\bmodelling\\b" = "modeling",
  "\\bmodelled\\b" = "modeled",
  "\\bmodeller\\b" = "modeler",
  "\\bcentre\\b" = "center",
  "\\bcentres\\b" = "centers",
  "\\bcentred\\b" = "centered",
  "\\bcentring\\b" = "centering",
  "\\bbehavioural\\b" = "behavioral",
  "\\bbehaviour\\b" = "behavior",
  "\\bcolour\\b" = "color",
  "\\bcolours\\b" = "colors",
  "\\bnon ?parametric\\b" = "nonparametric",
  "\\bsemi ?parametric\\b" = "semiparametric",
  "\\bmulti ?level\\b" = "multilevel",
  "\\bmulti ?variate\\b" = "multivariate"
)

# Dynamic construction of regex for the z_roots
z_patterns <- c()
for (root in z_roots) {
  z_patterns[paste0("\\b", root, "isation(s)?\\b")] <- paste0(root, "ization\\1")
  z_patterns[paste0("\\b", root, "ising\\b")] <- paste0(root, "izing")
  z_patterns[paste0("\\b", root, "ise(s|d|r|)\\b")] <- paste0(root, "ize\\1")
}

uk_to_us <- function(s) {
  s <- str_replace_all(s, uk_us_pairs)
  s <- str_replace_all(s, z_patterns)
  return(s)
}

# 3. Main normalisation function
normalize <- function(s) {
  # Prefix removal
  prefix1 <- "^the latent variable model mentioned and used in the article is "
  prefix2 <- "^the latent variable models mentioned and used in the article are:"
  s <- str_remove(s, regex(prefix1, ignore_case = TRUE))
  s <- str_remove(s, regex(prefix2, ignore_case = TRUE))
  
  # Suffix removal
  suffix1 <- " is mentioned and used in the article as latent variable approach$"
  suffix2 <- " is mentioned and used in the article as Latent Variable Approach$"
  s <- str_remove(s, regex(suffix1, ignore_case = TRUE))
  s <- str_remove(s, regex(suffix2, ignore_case = TRUE))
  
  # Lowercase + accent removal
  s <- str_to_lower(s)
  s <- stri_trans_general(s, "Latin-ASCII")
  
  # Replace hyphens with spaces
  s <- str_replace_all(s, "-", " ")
  
  # Remove remaining punctuation (keeping letters, numbers, and spaces)
  s <- str_replace_all(s, "[^a-z0-9\\s]", " ")
  
  # Apply UK -> US filter
  s <- uk_to_us(s)
  
  # 'Analysis' variants
  s <- str_replace_all(s, "\\b(analysing|analyzing|analyses)\\b", "analysis")
  
  # Frequent plurals -> singular
  singular_map <- c(
    "\\bmodels?\\b" = "model",
    "\\bmodel?\\b" = "model",
    "\\bmixtures?\\b" = "mixture",
    "\\bclasses?\\b" = "class",
    "\\bprofiles?\\b" = "profile",
    "\\bfactors?\\b" = "factor",
    "\\bcomponents?\\b" = "component",
    "\\bitems?\\b" = "item",
    "\\bvariables?\\b" = "variable",
    "\\bstates?\\b" = "state",
    "\\bnetworks?\\b" = "network",
    "\\bmethods?\\b" = "method"
  )
  s <- str_replace_all(s, singular_map)
  
  # Remove 'approach/approaches' at the end of the string
  s <- str_remove_all(s, "\\bapproaches?$")
  s <- str_remove_all(s, "\\bapproach?$")
  s <- str_trim(s)
  
  # Modifications on 'model' and derivatives
  s <- str_replace_all(s, "(?i)model\\w*", "model")
  s <- str_replace_all(s, "\\b(analy[sz]\\w*|method?)\\b", "model")
  
  # Clean spaces
  s <- str_squish(s)
  
  return(s)
}

# 4. Execution 
normalized_names <- normalize(names)

tbl7 <- tbl6 %>%
  dplyr::mutate(normalized_names)

tbl8 <- tbl7 %>%
  dplyr::distinct(normalized_names, .keep_all = TRUE)

#-------------------------------------------------------------------------------
#### IV - EXPORT ####
#-------------------------------------------------------------------------------
writexl::write_xlsx(list("model-gemma3 - 27b" = tbl8), 
                    "data/intermediate/models_cleaned_deduplicated_gemma3_27b.xlsx")