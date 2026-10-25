# Clean outage data and create descriptive plots.

if (basename(getwd()) == "scripts") setwd("..")
cat("Working directory:", getwd(), "\n\n")

# Load packages.
for (pkg in c("readr", "moments")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  library(pkg, character.only = TRUE)
}

plot_dir  <- file.path("results", "plots")
table_dir <- file.path("results", "tables")
dir.create(plot_dir,  recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# Load raw data without modifying it.
raw_path <- file.path("data", "raw", "Snapchat_user_reported.csv")
df_raw   <- read_csv(raw_path, show_col_types = FALSE)

cat("Raw dataset loaded:", nrow(df_raw), "rows,", ncol(df_raw), "columns.\n")
cat("Raw dataset is PRESERVED unchanged.\n\n")

# Apply documented cleaning rules.
cat("Cleaning rules\n")

df_work <- df_raw

# Remove missing timestamps.
r1_before <- nrow(df_work)
df_work   <- df_work[!is.na(df_work$start_time) & !is.na(df_work$end_time), ]
r1_removed <- r1_before - nrow(df_work)
cat(sprintf("Rule 1 (remove NA timestamps):           removed %d rows\n", r1_removed))

# Remove non-positive durations.
r2_before  <- nrow(df_work)
df_work$duration_sec <- df_work$end_time - df_work$start_time
df_work    <- df_work[df_work$duration_sec > 0, ]
r2_removed <- r2_before - nrow(df_work)
cat(sprintf("Rule 2 (remove non-positive duration):   removed %d rows\n", r2_removed))

# Remove exact duplicates.
r3_before  <- nrow(df_work)
df_work    <- df_work[!duplicated(df_work), ]
r3_removed <- r3_before - nrow(df_work)
cat(sprintf("Rule 3 (remove exact duplicates):        removed %d rows\n", r3_removed))

# Convert duration to minutes.
df_work$duration_min <- df_work$duration_sec / 60

n_clean <- nrow(df_work)
n_raw   <- nrow(df_raw)
cat(sprintf("\nRows before cleaning: %d\n", n_raw))
cat(sprintf("Rows after  cleaning: %d\n", n_clean))
cat(sprintf("Rows removed total:   %d (%.1f%%)\n\n",
            n_raw - n_clean, 100 * (n_raw - n_clean) / n_raw))

# Save cleaned data.
proc_path <- file.path("data", "processed", "Snapchat_cleaned.csv")
write_csv(df_work, proc_path)
cat("Cleaned dataset saved to:", proc_path, "\n\n")

# Calculate descriptive statistics.
x <- df_work$duration_min

cat("Descriptive statistics (minutes)\n")

desc_stats <- data.frame(Statistic = c("n (sample size)", "Minimum", "1st Quartile (Q1)", "Median", "3rd Quartile (Q3)", "Maximum", "Mean", "Variance", "Standard Deviation", "Skewness", "Kurtosis (excess)", "IQR"), Value = c(length(x), round(min(x), 2), round(quantile(x, 0.25), 2), round(median(x), 2), round(quantile(x, 0.75), 2), round(max(x), 2), round(mean(x), 4), round(var(x), 4), round(sd(x), 4), round(skewness(x), 4), round(kurtosis(x) - 3, 4), round(IQR(x), 2))) # excess kurtosis is relative to Normal.

print(desc_stats, row.names = FALSE)

write_csv(desc_stats, file.path(table_dir, "02_descriptive_statistics.csv"))
cat("\nDescriptive statistics saved to: results/tables/02_descriptive_statistics.csv\n\n")

# Print a short interpretation.
cat("\nInterpretation\n")
cat(sprintf("  * We have %d valid Snapchat outage events.\n", length(x)))
cat(sprintf("  * The SHORTEST outage lasted %.0f minutes.\n", min(x)))
cat(sprintf("  * HALF of all outages were over within %.0f minutes (median).\n", median(x)))
cat(sprintf("  * The AVERAGE outage lasted %.1f minutes (~%.1f hours).\n",
            mean(x), mean(x)/60))
cat(sprintf("  * The LONGEST outage lasted %.0f minutes (~%.1f hours).\n",
            max(x), max(x)/60))
cat(sprintf("  * Skewness = %.2f: the distribution is strongly RIGHT-SKEWED --\n", skewness(x)))
cat("    most outages are short, but a few very long ones pull the mean up.\n")
cat("    This pattern is typical of failure-time data and motivates\n")
cat("    Normal, Exponential, and Weibull distribution fits.\n\n")

# Durations are recorded in 20-minute increments.
cat("  [NOTE] Durations are multiples of 20 minutes (user-report polling\n")
cat("  granularity). This is a known limitation of the dataset.\n\n")

# Create histogram.
png(file.path(plot_dir, "02a_histogram.png"), width = 900, height = 550, res = 110)

hist(x, breaks = 40, freq = FALSE, col = "#4A90D9", border = "white", main = "Histogram of Outage Durations — Snapchat (Cleaned Data)", xlab = "Outage Duration (minutes)", ylab = "Density", las = 1)

lines(density(x, bw = "SJ"), col = "#E8542A", lwd = 2.5)

abline(v = mean(x),   col = "#2ECC71", lwd = 2, lty = 2)
abline(v = median(x), col = "#F39C12", lwd = 2, lty = 3)

legend("topright", legend = c("KDE", paste0("Mean = ", round(mean(x), 1), " min"), paste0("Median = ", round(median(x), 1), " min")), col = c("#E8542A", "#2ECC71", "#F39C12"), lwd = c(2.5, 2, 2), lty = c(1, 2, 3), bty = "n", cex = 0.85)

dev.off()
cat("Plot saved: results/plots/02a_histogram.png\n")

# Create boxplot.
png(file.path(plot_dir, "02b_boxplot.png"), width = 700, height = 550, res = 110)

boxplot(x, col = "#4A90D9", border = "#1A3A5C", main = "Boxplot of Outage Durations — Snapchat", ylab = "Outage Duration (minutes)", las = 1, outcol = "#E8542A", outpch = 20, whisklty = 1)

mtext(side = 3, text = sprintf("n=%d  |  Median=%.0f min  |  Mean=%.1f min  |  Max=%.0f min", length(x), median(x), mean(x), max(x)), cex = 0.75, line = 0.3)

dev.off()
cat("Plot saved: results/plots/02b_boxplot.png\n")

# Create ECDF plot.
png(file.path(plot_dir, "02c_ecdf.png"), width = 900, height = 550, res = 110)

plot(ecdf(x), main = "Empirical CDF of Outage Durations — Snapchat", xlab = "Outage Duration (minutes)", ylab = "Cumulative Probability F(t)", col = "#4A90D9", lwd = 2, pch = NA, las = 1)

pcts <- c(0.50, 0.75, 0.90, 0.95)
pct_vals <- quantile(x, pcts)
abline(h = pcts, col = "gray60", lty = 2, lwd = 0.8)
abline(v = pct_vals, col = "gray60", lty = 2, lwd = 0.8)
points(pct_vals, pcts, col = "#E8542A", pch = 19, cex = 1.1)
text(pct_vals, pcts, labels = paste0(round(pct_vals, 0), " min"), pos = 4, cex = 0.72, col = "#E8542A")

legend("bottomright", legend = c("ECDF", "Key percentiles (50/75/90/95%)"), col = c("#4A90D9", "#E8542A"), lwd = c(2, NA), pch = c(NA, 19), bty = "n", cex = 0.85)

dev.off()
cat("Plot saved: results/plots/02c_ecdf.png\n")

# Optional exploratory log-scale histogram.

if (FALSE) { # Retained but not generated.
png(file.path(plot_dir, "02d_log_histogram.png"), width = 900, height = 550, res = 110)

log10_x <- log10(x)

hist(log10_x, breaks = 30, freq = FALSE, col = "#7B68EE", border = "white", main = "Histogram of log10(Outage Duration) — Snapchat", xlab = "log10(Outage Duration in minutes)", ylab = "Density", las = 1, xaxt = "n")

axis_ticks <- c(20, 40, 60, 120, 240, 480, 1000, 2000)
axis_ticks <- axis_ticks[axis_ticks <= max(x)]
axis(1, at = log10(axis_ticks), labels = paste0(axis_ticks, " min"), las = 2, cex.axis = 0.75)

lines(density(log10_x, bw = "SJ"), col = "#E8542A", lwd = 2.5)

legend("topright", legend = "KDE on log10 scale", col = "#E8542A", lwd = 2.5, bty = "n")

dev.off()
cat("Plot saved: results/plots/02d_log_histogram.png\n\n")
}

# Identify high-duration outliers.
cat("Extreme observations\n")
q1  <- quantile(x, 0.25)
q3  <- quantile(x, 0.75)
iqr <- q3 - q1
upper_fence <- q3 + 1.5 * iqr
outliers    <- x[x > upper_fence]

cat(sprintf("Upper fence (Q3 + 1.5*IQR): %.1f minutes\n", upper_fence))
cat(sprintf("Number of outliers above fence: %d (%.1f%% of data)\n",
            length(outliers), 100 * length(outliers) / length(x)))
cat("Outlier values (minutes):\n")
print(sort(outliers))

cat("\n  Outliers are genuine extreme outage events (very long outages),\n")
cat("  NOT errors. They are KEPT for distribution fitting, as they\n")
cat("  carry important information about the tail behavior of the data.\n")
cat("  We will note them as a limitation in the report.\n\n")

outlier_table <- data.frame(duration_min = sort(outliers), duration_hours = round(sort(outliers) / 60, 2))
write_csv(outlier_table, file.path(table_dir, "02_outliers.csv"))
cat("Outlier table saved to: results/tables/02_outliers.csv\n\n")
