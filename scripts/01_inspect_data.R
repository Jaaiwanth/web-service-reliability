# =============================================================================
# PHASE 1: Data Inspection Script
# Project: Probabilistic Reliability Modeling of Web Services
# File:    scripts/01_inspect_data.R
# Author:  [Your Name]
# Date:    2026-10-25
#
# PURPOSE:
#   Load the raw Snapchat outage dataset, inspect its structure, check data
#   quality, calculate outage durations, and produce a summary histogram.
#   All outputs are saved to disk so they can be reviewed in RStudio or
#   independently.
#
# HOW TO RUN IN RSTUDIO:
#   1. Open RStudio and set the working directory to the project root:
#      Session > Set Working Directory > Choose Directory...
#      (select: WebServiceReliability/)
#   2. Open this file: File > Open File > scripts/01_inspect_data.R
#   3. Press Ctrl+Shift+Enter  (or click the "Source" button at the top right
#      of the Source pane) to run the entire script.
#   4. Check the Console pane for printed output.
#   5. Plots are saved to results/plots/ -- open them from the Files pane.
# =============================================================================

# -- 0. Setup ------------------------------------------------------------------

# Use relative paths from the project root.
# If running from RStudio, make sure your working directory is the project root.
# If this script is in the 'scripts/' sub-folder, we set the root explicitly:
if (basename(getwd()) == "scripts") {
  setwd("..")  # go up one level to the project root
}

cat("Working directory:", getwd(), "\n\n")

# Install readr if it is not already available
if (!requireNamespace("readr", quietly = TRUE)) {
  install.packages("readr", repos = "https://cloud.r-project.org")
}
library(readr)

# -- 1. Load the raw dataset ---------------------------------------------------

raw_path <- file.path("data", "raw", "Snapchat_user_reported.csv")

cat("Loading dataset from:", raw_path, "\n")
df_raw <- read_csv(raw_path, show_col_types = FALSE)

# -- 2. Basic Structure --------------------------------------------------------

cat("\n=== DIMENSIONS ===\n")
cat("Rows:", nrow(df_raw), " | Columns:", ncol(df_raw), "\n")

cat("\n=== COLUMN NAMES ===\n")
print(names(df_raw))

cat("\n=== COLUMN DATA TYPES ===\n")
print(sapply(df_raw, class))

cat("\n=== FIRST 10 ROWS ===\n")
print(head(df_raw, 10))

# -- 3. Missing Values ---------------------------------------------------------

cat("\n=== MISSING VALUES PER COLUMN ===\n")
missing_counts <- colSums(is.na(df_raw))
print(missing_counts)
cat("Total missing cells:", sum(is.na(df_raw)), "\n")

# -- 4. Duplicate Records ------------------------------------------------------

n_duplicates <- sum(duplicated(df_raw))
cat("\n=== DUPLICATE ROWS ===\n")
cat("Number of exact duplicate rows:", n_duplicates, "\n")

# -- 5. Unique Service Names ---------------------------------------------------

cat("\n=== UNIQUE SERVICE NAMES ===\n")
print(unique(df_raw$service))

# -- 6. Timestamp Summary ------------------------------------------------------

cat("\n=== TIMESTAMP RANGE (raw seconds) ===\n")
cat("start_time min:", min(df_raw$start_time, na.rm = TRUE), "\n")
cat("start_time max:", max(df_raw$start_time, na.rm = TRUE), "\n")
cat("end_time   min:", min(df_raw$end_time,   na.rm = TRUE), "\n")
cat("end_time   max:", max(df_raw$end_time,   na.rm = TRUE), "\n")

# Note: timestamps appear to be in seconds relative to an epoch.
# Total observation span:
total_span_sec  <- max(df_raw$end_time, na.rm = TRUE) - min(df_raw$start_time, na.rm = TRUE)
total_span_days <- total_span_sec / 86400
cat(sprintf("\nTotal observation window: %.0f seconds (~%.1f days)\n",
            total_span_sec, total_span_days))

# -- 7. Calculate Outage Duration ----------------------------------------------

# Duration = end_time - start_time  (in seconds, since timestamps are seconds)
df_raw$duration_sec <- df_raw$end_time - df_raw$start_time

cat("\n=== OUTAGE DURATION (seconds) -- all rows ===\n")
cat("Min:", min(df_raw$duration_sec, na.rm = TRUE), "\n")
cat("Max:", max(df_raw$duration_sec, na.rm = TRUE), "\n")
cat("Mean:", round(mean(df_raw$duration_sec, na.rm = TRUE), 2), "\n")

# -- 8. Invalid Intervals ------------------------------------------------------

cat("\n=== DATA QUALITY CHECKS ===\n")

# Non-positive durations (zero or negative end - start)
invalid_duration <- df_raw$duration_sec <= 0 | is.na(df_raw$duration_sec)
cat("Rows with zero or negative duration:", sum(invalid_duration, na.rm = TRUE), "\n")

# Rows where end_time < start_time
reversed <- df_raw$end_time < df_raw$start_time
cat("Rows where end_time < start_time:", sum(reversed, na.rm = TRUE), "\n")

# Status column range
cat("\nStatus column summary:\n")
print(summary(df_raw$status))
cat("NOTE: 'status' appears to be a proportion/score (0-1), NOT a binary failure flag.\n")
cat("      We will NOT use it as a failure time or probability without further verification.\n")

# -- 9. Valid Positive Durations -----------------------------------------------

valid_durations <- df_raw$duration_sec[df_raw$duration_sec > 0 & !is.na(df_raw$duration_sec)]
n_valid <- length(valid_durations)

cat("\n=== VALID POSITIVE DURATIONS ===\n")
cat("Count of valid outage records:", n_valid, "\n")
cat("Durations in minutes -- quick look:\n")
print(round(sort(valid_durations / 60), 2))

# Convert to minutes for easier interpretation
valid_minutes <- valid_durations / 60

cat("\nSummary in MINUTES:\n")
print(summary(valid_minutes))

# -- 10. Histogram of Valid Durations ------------------------------------------

plot_dir <- file.path("results", "plots")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

png(filename = file.path(plot_dir, "01_outage_duration_histogram.png"),
    width = 800, height = 500, res = 100)

hist(valid_minutes,
     breaks = 30,
     col    = "steelblue",
     border = "white",
     main   = "Histogram of Snapchat Outage Durations (Raw Data)",
     xlab   = "Outage Duration (minutes)",
     ylab   = "Frequency",
     las    = 1)
abline(v  = median(valid_minutes),
       col = "red", lwd = 2, lty = 2)
legend("topright",
       legend = paste0("Median = ", round(median(valid_minutes), 1), " min"),
       col    = "red", lty = 2, lwd = 2, bty = "n")

dev.off()
cat("\nHistogram saved to: results/plots/01_outage_duration_histogram.png\n")

# -- 11. Save Data Quality Summary ---------------------------------------------

table_dir <- file.path("results", "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

quality_summary <- data.frame(
  Check = c("Total rows",
            "Total columns",
            "Missing values (total)",
            "Duplicate rows",
            "Invalid/zero/negative durations",
            "Valid positive durations",
            "Observation span (days)",
            "Min duration (min)",
            "Max duration (min)",
            "Median duration (min)",
            "Mean duration (min)"),
  Value = c(nrow(df_raw),
            ncol(df_raw),
            sum(is.na(df_raw)),
            n_duplicates,
            sum(invalid_duration, na.rm = TRUE),
            n_valid,
            round(total_span_days, 1),
            round(min(valid_minutes), 2),
            round(max(valid_minutes), 2),
            round(median(valid_minutes), 2),
            round(mean(valid_minutes), 2))
)

write_csv(quality_summary,
          file.path(table_dir, "01_data_quality_summary.csv"))

cat("\nData quality summary saved to: results/tables/01_data_quality_summary.csv\n")

# -- 12. Final Console Summary -------------------------------------------------

cat("\n")
cat("=============================================================\n")
cat("  PHASE 1 COMPLETE -- INSPECTION SUMMARY\n")
cat("=============================================================\n")
cat(sprintf("  Dataset rows:         %d\n", nrow(df_raw)))
cat(sprintf("  Valid outage records: %d\n", n_valid))
cat(sprintf("  Observation window:   %.1f days\n", total_span_days))
cat(sprintf("  Median duration:      %.1f minutes\n", median(valid_minutes)))
cat(sprintf("  Mean duration:        %.1f minutes\n", mean(valid_minutes)))
cat(sprintf("  Max duration:         %.1f minutes\n", max(valid_minutes)))
cat("=============================================================\n")
cat("  Outputs:\n")
cat("    results/plots/01_outage_duration_histogram.png\n")
cat("    results/tables/01_data_quality_summary.csv\n")
cat("=============================================================\n\n")
