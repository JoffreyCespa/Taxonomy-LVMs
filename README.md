# 🧬 Taxonomy-LVMs: Latent Variable Models Characterisation and Classification Pipeline

**Description:** 
This repository contains the complete data pipeline, scripts, and documentation used to extract, characterise, and classify latent variable models (LVMs) from the scientific literature. The project is based on a reproducible methodology. The analytical pipeline integrates LLM inference, text mining, TF-IDF vectorization, and DBSCAN clustering to derive representative exemplars under strict control and validation based on expert opinion.

---

## 📂 Repository Structure

The project directory tree is designed to clearly separate raw data, intermediate steps, LLM instructions, and analysis code:

### 📁 `data/`
Main directory containing all the project's datasets, divided into three sub-directories:

*   **`final/`**: Final pipeline results.
    *   `exemplars_extracted_gemma3_27b.xlsx`: [Description of the role of this final exemplars file]
*   **`intermediate/`**: Files generated during the various processing steps.
    *   **`TempFile_gemma3_27b/`**: Temporary storage space to prevent data loss during inference (contains its own `README.md`).
    *   `models_cleaned_deduplicated_gemma3_27b.xlsx`: [Description: Models file after the cleaning and deduplication step]
    *   `pubmed_cleaned_govindasamy.xlsx`: [Description: Data from PubMed after cleaning]
    *   `pubmed_extracted_models_gemma3_27b.xlsx`: [Description: Raw models extracted specifically from PubMed data via Gemma]
*   **`raw/`**: Input data, metadata, and validation files.
    *   `ModelV2.csv`: Expert validation file recording the manual reassignment of models into clusters after automated processing.
    *   `NameClust.csv`: Final nomenclature assigned to each model cluster, validated by the experts.
    *   `pubmed_raw_extraction.xlsx`: [Description: Initial raw data extracted from the PubMed database]
    *   `codebook_caracterisation.csv`: Data dictionary defining the 22 variables expected for the characterisation (used as a strict constraint in the prompt).

### 📁 `prompts/`
Contains the text files documenting the exact instructions sent to the language model.
*   `03_prompt_inference.md`: [Description of this specific inference prompt]
*   `prompt_caracterisation.md`: "Zero hallucination" system prompt guaranteeing strict extraction from the source documents.

### 📁 `scripts/`
Contains the entire source code executing the research pipeline.
*   `01_data_acquisition.R`: [Initial data acquisition script]
*   `02_data_cleaning.R`: [Script responsible for data preparation and cleaning]
*   `03_llm_inference.R`: Script managing the LLM call and feature extraction.
*   `04_string_processing.R`: [Script handling the formatting and manipulation of character strings post-inference]
*   `05_canonicalisation.ipynb`: [Python notebook dedicated to the canonicalisation of terms/models]
*   `06_exemplar_extraction.R`: [Script extracting the final exemplars for the taxonomy]

### 📄 Configuration Files (Root)
*   `.gitignore`: List of files and folders (such as temporary files) not tracked by Git.
*   `LICENSE`: [Indicate the type of open-source license here, e.g., MIT, CC-BY]
*   `README.md`: This documentation file.
*   `renv.lock`: File ensuring the exact reproducibility of the environment and R packages used.
*   `requirement.txt`: [List of required Python dependencies, notably for the canonicalisation notebook]

---

## 🚀 Usage and Reproducibility

1.  **Environment:** Ensure you restore the R environment via `renv` and install the Python dependencies listed in `requirement.txt`.
2.  **Execution:** The scripts in the `scripts/` folder are numbered (from 01 to 06) and must be executed sequentially to reproduce the entire pipeline.
3.  **LLM Constraints:** Any reproduction of the inference step (`03_llm_inference.R`) must strictly rely on the rules defined in the `prompts/` folder and the `codebook_caracterisation.csv`.
