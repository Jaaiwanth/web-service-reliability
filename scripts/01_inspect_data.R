# Inspect raw outage data and create a basic summary.

# Set the project root when run from scripts/.
if (basename(getwd()) == "scripts") {
  setwd("..")
}

cat("Working directory:", getwd(), "\n\n")

# Load packages.
if (!requireNamespace("readr", quietly = TRUE)) {
  install.packages("readr", repos = "https://cloud.r-project.org")
}
library(readr)

# Load data.
raw_path <- file.path("data", "raw", "Snapchat_user_reported.csv")

cat("Loading dataset from:", raw_path, "\n")
df_raw <- read_csv(raw_path, show_col_types = FALSE)

# Inspect structure.
cat("\nData dimensions\n")
cat("Rows:", nrow(df_raw), " | Columns:", ncol(df_raw), "\n")

cat("\nColumn names\n")
print(names(df_raw))

cat("\nColumn types\n")
print(sapply(df_raw, class))

cat("\nFirst 10 rows\n")
print(head(df_raw, 10))

# Check missing values.
cat("\nMissing values per column\n")
missing_counts <- colSums(is.na(df_raw))
print(missing_counts)
cat("Total missing cells:", sum(is.na(df_raw)), "\n")

# Check duplicates.
n_duplicates <- sum(duplicated(df_raw))
cat("\nDuplicate rows\n")
cat("Number of exact duplicate rows:", n_duplicates, "\n")

cat("\nService names\n")
print(unique(df_raw$service))

# Check timestamp range.
cat("\nTimestamp range (seconds)\n")
cat("start_time min:", min(df_raw$start_time, na.rm = TRUE), "\n")
cat("start_time max:", max(df_raw$start_time, na.rm = TRUE), "\n")
cat("end_time   min:", min(df_raw$end_time,   na.rm = TRUE), "\n")
cat("end_time   max:", max(df_raw$end_time,   na.rm = TRUE), "\n")

# Calculate the observation span.
total_span_sec  <- max(df_raw$end_time, na.rm = TRUE) - min(df_raw$start_time, na.rm = TRUE)
total_span_days <- total_span_sec / 86400
cat(sprintf("\nTotal observation window: %.0f seconds (~%.1f days)\n", total_span_sec, total_span_days))

# Calculate durations in seconds.
df_raw$duration_sec <- df_raw$end_time - df_raw$start_time

cat("\nOutage durations (seconds)\n")
cat("Min:", min(df_raw$duration_sec, na.rm = TRUE), "\n")
cat("Max:", max(df_raw$duration_sec, na.rm = TRUE), "\n")
cat("Mean:", round(mean(df_raw$duration_sec, na.rm = TRUE), 2), "\n")

cat("\nData quality checks\n")

# Check invalid intervals.
invalid_duration <- df_raw$duration_sec <= 0 | is.na(df_raw$duration_sec)
cat("Rows with zero or negative duration:", sum(invalid_duration, na.rm = TRUE), "\n")

reversed <- df_raw$end_time < df_raw$start_time
cat("Rows where end_time < start_time:", sum(reversed, na.rm = TRUE), "\n")

# `status` is not used as a failure indicator without verification.
cat("\nStatus column summary:\n")
print(summary(df_raw$status))
cat("NOTE: 'status' appears to be a proportion/score (0-1), NOT a binary failure flag.\n")
cat("      We will NOT use it as a failure time or probability without further verification.\n")

# Keep positive durations.
valid_durations <- df_raw$duration_sec[df_raw$duration_sec > 0 & !is.na(df_raw$duration_sec)]
n_valid <- length(valid_durations)

cat("\nValid positive durations\n")
cat("Count of valid outage records:", n_valid, "\n")
cat("Durations in minutes -- quick look:\n")
print(round(sort(valid_durations / 60), 2))

valid_minutes <- valid_durations / 60

cat("\nDuration summary (minutes)\n")
print(summary(valid_minutes))

# Create histogram.
plot_dir <- file.path("results", "plots")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

png(filename = file.path(plot_dir, "01_outage_duration_histogram.png"), width = 800, height = 500, res = 100)
hist(valid_minutes, breaks = 30, col = "steelblue", border = "white", main = "Histogram of Snapchat Outage Durations (Raw Data)", xlab = "Outage Duration (minutes)", ylab = "Frequency", las = 1)
abline(v = median(valid_minutes), col = "red", lwd = 2, lty = 2)
legend("topright", legend = paste0("Median = ", round(median(valid_minutes), 1), " min"), col = "red", lty = 2, lwd = 2, bty = "n")

dev.off()
cat("\nHistogram saved to: results/plots/01_outage_duration_histogram.png\n")

# Save quality summary.
table_dir <- file.path("results", "tables")
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

quality_summary <- data.frame(Check = c("Total rows", "Total columns", "Missing values (total)", "Duplicate rows", "Invalid/zero/negative durations", "Valid positive durations", "Observation span (days)", "Min duration (min)", "Max duration (min)", "Median duration (min)", "Mean duration (min)"), Value = c(nrow(df_raw), ncol(df_raw), sum(is.na(df_raw)), n_duplicates, sum(invalid_duration, na.rm = TRUE), n_valid, round(total_span_days, 1), round(min(valid_minutes), 2), round(max(valid_minutes), 2), round(median(valid_minutes), 2), round(mean(valid_minutes), 2)))

write_csv(quality_summary, file.path(table_dir, "01_data_quality_summary.csv"))

cat("\nData quality summary saved to: results/tables/01_data_quality_summary.csv\n")
