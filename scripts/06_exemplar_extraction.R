#===============================================================================
# Title: Exemplar Extraction
# Author(s): Joffrey Marchi et al.
# Objective: Identify the representative exemplar model for each cluster based on its usage frequency and publication recency.
# Inputs: data/intermediate/pubmed_extracted_models_gemma3_27b.xlsx, data/raw/ModelV2.csv, data/raw/NameClust.csv
# Outputs: data/final/exemplars_extracted_gemma3_27b.xlsx
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
library(readr)
library(stringi)

#-------------------------------------------------------------------------------
#### I - PARAMETERS ####
#-------------------------------------------------------------------------------
dir.root <- this.proj()
setwd(dir.root)

dir.create("data/final", recursive = TRUE, showWarnings = FALSE)

new_clust_id <- 1:100000
clustBaye <- seq(9999, 9000, -1)
index_dedup_id_baye <- 1

#-------------------------------------------------------------------------------
#### II - DATA IMPORT ####
#-------------------------------------------------------------------------------
# 1 - Pubmed base
baseAllModel <- readxl::read_excel("data/intermediate/pubmed_extracted_models_gemma3_27b.xlsx") %>%
  dplyr::distinct()

# 2 - Cluster base for all models
clustAll <- readr::read_delim("data/raw/ModelV2.csv", 
                              delim = ";", escape_double = FALSE, trim_ws = TRUE) %>%
  dplyr::distinct()

# 3 - Cluster names base
ClusterName <- readr::read_delim("data/raw/NameClust.csv", 
                                 delim = ";", escape_double = FALSE, locale = locale(encoding = "ISO-8859-1"), 
                                 trim_ws = TRUE) %>%
  dplyr::select(ID_Cluster = clust_new, US_Cluster_Name = name_fr, US_Global_Category = name_us, abre_fr, abre_us) %>%
  dplyr::distinct()

#-------------------------------------------------------------------------------
#### III - MODEL NAME NORMALISATION ####
#-------------------------------------------------------------------------------
tbl1 <- baseAllModel %>%
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
  dplyr::arrange(summary2, year)

bad_values <- c('na', 'nan', 'n.a.', 'n/a', 'uncertain')

names <- tbl6 %>%
  dplyr::pull(summary2) %>%          
  as.character() %>%          
  keep(~ str_trim(.x) != "") %>% 
  discard(~ str_to_lower(.x) %in% bad_values) 

z_roots <- c(
  "parameter", "regular", "factor", "marginal", "initial", "general",
  "stabil", "discret", "vector", "orthogonal", "random", "linear",
  "normal", "standard", "categor"
)

uk_us_pairs <- c(
  "\\bmodelling\\b" = "modeling", "\\bmodelled\\b" = "modeled", "\\bmodeller\\b" = "modeler",
  "\\bcentre\\b" = "center", "\\bcentres\\b" = "centers", "\\bcentred\\b" = "centered",
  "\\bcentring\\b" = "centering", "\\bbehavioural\\b" = "behavioral", "\\bbehaviour\\b" = "behavior",
  "\\bcolour\\b" = "color", "\\bcolours\\b" = "colors", "\\bnon ?parametric\\b" = "nonparametric",
  "\\bsemi ?parametric\\b" = "semiparametric", "\\bmulti ?level\\b" = "multilevel", "\\bmulti ?variate\\b" = "multivariate"
)

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

normalize <- function(s) {
  prefix1 <- "^the latent variable model mentioned and used in the article is "
  prefix2 <- "^the latent variable models mentioned and used in the article are:"
  s <- str_remove(s, regex(prefix1, ignore_case = TRUE))
  s <- str_remove(s, regex(prefix2, ignore_case = TRUE))
  
  suffix1 <- " is mentioned and used in the article as latent variable approach$"
  suffix2 <- " is mentioned and used in the article as Latent Variable Approach$"
  s <- str_remove(s, regex(suffix1, ignore_case = TRUE))
  s <- str_remove(s, regex(suffix2, ignore_case = TRUE))
  
  s <- str_to_lower(s)
  s <- stri_trans_general(s, "Latin-ASCII")
  s <- str_replace_all(s, "-", " ")
  s <- str_replace_all(s, "[^a-z0-9\\s]", " ")
  s <- uk_to_us(s)
  s <- str_replace_all(s, "\\b(analysing|analyzing|analyses)\\b", "analysis")
  
  singular_map <- c(
    "\\bmodels?\\b" = "model", "\\bmodel?\\b" = "model", "\\bmixtures?\\b" = "mixture",
    "\\bclasses?\\b" = "class", "\\bprofiles?\\b" = "profile", "\\bfactors?\\b" = "factor",
    "\\bcomponents?\\b" = "component", "\\bitems?\\b" = "item", "\\bvariables?\\b" = "variable",
    "\\bstates?\\b" = "state", "\\bnetworks?\\b" = "network", "\\bmethods?\\b" = "method"
  )
  s <- str_replace_all(s, singular_map)
  s <- str_remove_all(s, "\\bapproaches?$")
  s <- str_remove_all(s, "\\bapproach?$")
  s <- str_trim(s)
  s <- str_replace_all(s, "(?i)model\\w*", "model")
  s <- str_replace_all(s, "\\b(analy[sz]\\w*|method?)\\b", "model")
  s <- str_squish(s)
  
  return(s)
}

normalized_names <- normalize(names)

tbl7 <- tbl6 %>%
  dplyr::mutate(normalized_names) %>%
  dplyr::distinct()

#-------------------------------------------------------------------------------
#### IV - DATABASE MERGING ####
#-------------------------------------------------------------------------------
baseAllModelClust <- tbl7 %>%
  dplyr::left_join(clustAll, by = c("normalized_names" = "name_modele"))  %>%
  dplyr::left_join(ClusterName, by = c("clust_new" = "ID_Cluster"))

#-------------------------------------------------------------------------------
#### V - EXEMPLARS WITHOUT CLUSTER INFORMATION ####
#-------------------------------------------------------------------------------
# 1 - Exemplars based on most used models regardless of cluster association
baseAllModelClust1 <- baseAllModelClust %>%
  dplyr::select(-clust_new, -all_of(colnames(ClusterName)[-1])) %>%
  dplyr::group_by(norm_model) %>%
  dplyr::mutate(parangon_withoutClust = n()) %>%
  dplyr::ungroup()

#-------------------------------------------------------------------------------
#### VI - EXEMPLARS USING CLUSTER INFORMATION ####
#-------------------------------------------------------------------------------
# 1 - Extracting Bayesian models
clustAllWithoutBruit <- clustAll %>%
  dplyr::filter(clust_new != -1) %>%
  dplyr::select(name_modele, clust_new, norm_model_clust = norm_model) %>%
  dplyr::left_join(ClusterName, by = c("clust_new" = "ID_Cluster"))

clustAllWithoutBruiclustNameclustAllWithoutBruitBaye <- clustAllWithoutBruit %>%
  dplyr::mutate(clust_final = paste0(clust_new),
                clust_final = ifelse(str_detect(norm_model_clust, regex("baye", ignore_case = TRUE)),
                                     paste0(clust_final, " - bayesian"),
                                     paste0(clust_final, " - frequentist"))) %>%
  dplyr::arrange(clust_new)

toto <- baseAllModelClust1 %>%
  dplyr::left_join(clustAllWithoutBruiclustNameclustAllWithoutBruitBaye,
                   by = c("normalized_names" = "name_modele")) %>%
  dplyr::group_by(clust_final, norm_model_clust) %>%
  dplyr::mutate(parangon_withClust = n()) %>%
  dplyr::ungroup()

listClsutBaye <- list()
listClsutBaye[['NA']] <- toto %>%
  dplyr::filter(is.na(clust_final))
for(i in unique(na.omit(toto$clust_final))){
  .temp <- toto %>%
    dplyr::filter(clust_final == i)  %>%
    dplyr::mutate(labelClustWith = paste0(norm_model_clust, " - ", parangon_withClust, "/", nrow(toto %>%
                                                                                                   dplyr::filter(clust_final == i)), " articles - cluster ", clust_final))
  listClsutBaye[[i]] <- .temp
}
baseAllModelClust2 <- bind_rows(listClsutBaye)

#-------------------------------------------------------------------------------
#### VII - FINAL EXEMPLAR EXTRACTION ####
#-------------------------------------------------------------------------------
# 1 - Exemplars based on most used models without cluster info
parangonWithoutClust <- baseAllModelClust2 %>%
  dplyr::select(norm_model, parangon_withoutClust) %>%
  dplyr::distinct() %>%
  dplyr::arrange(desc(parangon_withoutClust)) %>%
  dplyr::filter(parangon_withoutClust > 10) %>%
  dplyr::mutate(label = paste0(norm_model, " - ", parangon_withoutClust, " articles"))

# 2 - Exemplars based on most used models with cluster info
parangonWithClust <- baseAllModelClust2 %>%
  dplyr::filter(!is.na(clust_final)) %>%
  dplyr::group_by(clust_final, parangon_withClust, year, month ) %>%
  dplyr::arrange(clust_final, desc(parangon_withClust), desc(year), desc(month)) %>%
  dplyr::ungroup() %>%
  dplyr::group_by(clust_final) %>%
  dplyr::select(clust_final, US_Cluster_Name, US_Global_Category, norm_model, parangon_withClust, labelClustWith, abre_fr, abre_us) %>%
  dplyr::slice(1)

#-------------------------------------------------------------------------------
#### VIII - EXPORT ####
#-------------------------------------------------------------------------------
writexl::write_xlsx(list(
  baseAllModelClust2,
  parangonWithoutClust,
  parangonWithClust),
  "data/final/exemplars_extracted_gemma3_27b.xlsx"
)