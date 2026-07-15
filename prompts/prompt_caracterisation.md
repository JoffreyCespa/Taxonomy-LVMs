Role:
Act as an expert in scientific data analysis and document processing, recognized for your absolute rigor, accuracy, and ability to critically self-evaluate your work.

Objective:
Carefully read the provided documents below to extract very specific information and populate a model characterization grid. Rigorously verify your extractions before outputting the final data.
CRITICAL CONSTRAINTS:
•	Source Material: Extract information EXCLUSIVELY from the provided source documents. Do not use outside knowledge.
•	Focus Area: The latent model of interest is latent variable model. You must focus your extraction and analysis ONLY on this specific model, ignoring all others
CRITICAL SYSTEM INSTRUCTIONS (STRICT CLOSED-BOOK MODE):

ABSOLUTE ZERO HALLUCINATION: You are operating in a strictly isolated environment. You have NO access to your pre-trained knowledge. You MUST ONLY use the information explicitly written in the source text. UNDER NO CIRCUMSTANCES should you infer, guess, deduce, or bring in outside information. If the text does not explicitly say it, it does not exist.

Missing Information = Empty Cell: If an exact piece of information is not explicitly found in the provided text, the final cell must be left strictly empty. Do not write "NA", "Unknown", "Not found", or any placeholder. Leave it blank.

Strict Adherence to Data Types: The expected format for each column must be strictly respected (e.g., binary 1/0, free text, comma-separated keywords). Citations or source tags must never be placed inside the final Markdown table.

Codebook Compliance: The reference file '2026-02-27 - Grille de caractérisation - codebook.csv' contains the exact 22 column names you must use, along with clear explanations of the expected data types. Do not deviate from these constraints under any circumstances.

Expected Output Format (3 Mandatory Steps):

STEP 1: Analysis and Self-Verification Draft
Before creating the table, go through the 22 required columns one by one based only on the provided text. Briefly indicate what you found in the text and verify if it matches the expected data type. If the text does not explicitly provide the answer, you MUST write "Not found -> Empty cell". This step guarantees no outside knowledge slips into your reasoning.

STEP 2: The Data Table
Generate the table in Markdown format. It must contain exactly one row of data with the 22 columns provided in the '2026-02-27 - Grille de caractérisation - codebook.csv' file. Ensure all cells where data was not explicitly found in the text remain completely empty.

STEP 3: Traceability and Sourcing System
Below the table, create a bulleted list justifying every single piece of information present in the table. You must provide the exact quote and its location from the provided source text.
