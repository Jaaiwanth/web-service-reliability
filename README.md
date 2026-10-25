# Probabilistic Reliability Modeling of Web Services Using Failure-Time Distributions

## Project Overview
This project analyzes Snapchat outage data using probability distributions (Exponential, Weibull, Log-normal) to model outage duration behavior and estimate service reliability metrics.

**Research Question:** Which probability distribution best models observed outage durations, and what does the fitted model reveal about web-service reliability?

## Project Structure
```
WebServiceReliability/
├── data/
│   ├── raw/                  # Original, unmodified CSV dataset
│   └── processed/            # Cleaned dataset for analysis
├── scripts/
│   ├── 01_inspect_data.R     # Phase 1: Data loading and inspection
│   ├── 02_clean_and_explore.R # Phase 2: Cleaning and EDA
│   ├── 03_distribution_fitting.R # Phase 3: Distribution fitting
│   └── 04_reliability_analysis.R # Phase 4: Reliability analysis
├── results/
│   ├── plots/                # PNG figures
│   └── tables/               # CSV result tables
├── report/                   # Final report (Markdown / DOCX)
└── README.md
```

## Dataset
- **Source:** [cloud-uptime-archive](https://github.com/atlarge-research/cloud-uptime-archive)
- **File:** Snapchat_user_reported.csv
- **Records:** 2,549 outage events
- **Observation window:** ~557 days
- **Columns:** start_time, end_time, status, service
- **Timestamps:** seconds (relative to dataset epoch)

## How to Reproduce

### Requirements
- R 4.6.1 or later
- RStudio (recommended for viewing plots and console output)
- Internet connection (first run: R will auto-install required packages)

### Running the Scripts in RStudio
1. Open RStudio
2. Go to **Session > Set Working Directory > Choose Directory** and select the `WebServiceReliability/` folder
3. Open each script from **File > Open File**
4. Press **Ctrl+Shift+Enter** or click **Source** to run the full script
5. Check the **Console** pane for output and the **Plots** pane or `results/plots/` for figures

### Running via Command Line
```powershell
cd WebServiceReliability
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\01_inspect_data.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\02_clean_and_explore.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\03_distribution_fitting.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\04_reliability_analysis.R
```

## Packages Used
- `readr` — CSV loading
- `fitdistrplus` — distribution fitting
- `survival` — survival analysis

## Notes
- The raw dataset in `data/raw/` is never modified.
- All outputs are reproducible from the raw CSV alone.
- `status` column is a user-report proportion (0–1), not a binary failure indicator.
