#===============================================================================
# Title: LLM Inference for Model Extraction
# Author(s): Joffrey Marchi et al.
# Objective: Automate the extraction of latent variable model canonical names from abstracts using the local LLM gemma3:27b.
# Inputs: data/intermediate/pubmed_cleaned_govindasamy.xlsx
# Outputs: data/intermediate/pubmed_extracted_models_gemma3_27b.xlsx
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

dir.create("data/intermediate/TempFile_gemma3_27b", recursive = TRUE, showWarnings = FALSE)

bdd <- readxl::read_excel("data/intermediate/pubmed_cleaned_govindasamy.xlsx")

#-------------------------------------------------------------------------------
#### II - LLM CONFIGURATION & PROMPT INJECTION ####
#-------------------------------------------------------------------------------
bddLlm <- bdd %>%
  tibble() %>%
  dplyr::mutate(prompt = build_prompt_preprint(
    title,
    abstract,
    nsentences = 1L,
    instructions = c(c("Role: You are a strict scientific data extractor specialized in statistics and machine learning. Your task is to detect and extract ONLY the latent variable models mentioned in a research article, based strictly on its title and abstract.",
                       "Context: By “latent variable model” we mean: models that posit the existence of unobserved variables (factors/latent variables) whose effects are observable. The scope spans historical and modern models. Examples of accepted models (not exhaustive): Exploratory Factor Analysis, Confirmatory Factor Analysis, Probabilistic Principal Component Analysis, Gaussian Mixture Model, Hidden Markov Model, Latent Dirichlet Allocation, Linear Gaussian State-Space Model, Variational Autoencoder, Stochastic Block Model, Probabilistic Nonnegative Matrix Factorization, Item Response Theory / Rasch Model, Probabilistic Independent Component Analysis, etc. Synonyms must be merged under a single canonical English model name, and abbreviations must not be used.",
                       "Tone: Factual, strict, and precise. Machine-readable output only.",
                       "Limits and strict rules: ONLY extract models that fit the latent variable definition. Ignore all other machine learning or statistical models. If NO latent variable model is found, OR if the models mentioned are NOT latent variable models, you MUST output exactly and only: no latent model. Output the canonical English full name of the model. Do NOT use abbreviations (e.g., output 'Hidden Markov Model' instead of 'HMM'). Expand them if they appear as abbreviations in the text. If multiple latent variable models are found, separate them using strictly the '/' character (e.g., 'Gaussian Mixture Model/Variational Autoencoder'). Remove duplicates and synonyms. CRITICAL: Your final output must contain NOTHING ELSE than the model names or the phrase 'no latent model'. Absolutely no introductions, no explanations, no 'Unknown' or 'Uncertain' labels, and no punctuation at the end.")
    )
  ))

class(bddLlm) <- c("preprints", class(bddLlm))
modelOllama <- "gemma3:27b"

#-------------------------------------------------------------------------------
#### III - BATCH PROCESSING & EXTRACTION ####
#-------------------------------------------------------------------------------
full_sequence <- 1:nrow(bddLlm)
chunk_size <- 30
num_chunks <- ceiling(length(full_sequence) / chunk_size)
list_of_vectors <- list()

for (i in 1:num_chunks) {
  start_index <- (i - 1) * chunk_size + 1
  end_index <- min(i * chunk_size, length(full_sequence))
  list_of_vectors[[i]] <- full_sequence[start_index:end_index]
}

tailleList <- length(list_of_vectors)

for(i in 1:tailleList) {
  deb <- Sys.time()
  print(paste0("Starting sequence ", i, "/", tailleList))
  print(paste("Sequence start time : ", deb))
  
  numForPrompt <- list_of_vectors[[i]]
  subBdd <- bddLlm %>%
    dplyr::slice(numForPrompt)
  
  resRowI <- add_summary(subBdd, model = modelOllama)
  
  write.csv2(resRowI, 
             paste0("data/intermediate/TempFile_gemma3_27b/idx_", 
                    i, "_seq_", min(numForPrompt), "-to-", max(numForPrompt), ".csv"),
             row.names = FALSE)
  
  fin <- Sys.time()
  print(paste0("Analysis duration (mins) : ", 
               as.numeric(difftime(time1 = fin, time2 = deb, units = "mins"))))
  print("   ")
}

#-------------------------------------------------------------------------------
#### IV - DATA AGGREGATION & EXPORT ####
#-------------------------------------------------------------------------------
dir.tempBase <- "data/intermediate/TempFile_gemma3_27b/"
listFiles <- list.files(path = dir.tempBase, pattern = "csv", full.names = TRUE)

tbl <-
  list.files(path = dir.tempBase, pattern = "csv$", full.names = T) %>%
  map_df(~read_delim(., delim = ";", escape_double = FALSE, trim_ws = TRUE) %>%
           dplyr::mutate_all(~as.character(.)))

writexl::write_xlsx(tbl, "data/intermediate/pubmed_extracted_models_gemma3_27b.xlsx")