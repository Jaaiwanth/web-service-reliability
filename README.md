# Probabilistic Reliability Modeling of Web Services

BMAT202L Probability and Statistics project using 2,549 Snapchat outage events from the Cloud Uptime Archive.

## Scope

The project calculates outage duration as `end_time - start_time`, in minutes, and covers:

- Module 1: descriptive statistics, histogram, boxplot, skewness, and kurtosis
- Module 4: Normal, Exponential, and Weibull duration models
- Module 6: chi-square goodness-of-fit test
- Module 7: outage-duration survival and resolution-hazard functions, plus series/parallel concepts

The raw file is preserved. This is an outage-duration analysis, not an availability or MTBF study: the dataset has no complete uptime/exposure or inter-failure information.

## Run

Run from the repository root, in order:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\01_inspect_data.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\02_clean_and_explore.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\03_distribution_fitting.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\04_reliability_analysis.R
```

Results are written to `results/plots/` and `results/tables/`. The report is [report/final_report.md](report/final_report.md).

## Important limitation

Durations are in 20-minute increments. The continuous models are therefore approximations; the formal chi-square test rejects all three fitted models at the 5% level. See the report and generated tables for the exact results.
