# =============================================================================
# PHASE 4: Reliability Analysis
# Project: Probabilistic Reliability Modeling of Web Services
# File:    scripts/04_reliability_analysis.R
# Author:  [Your Name]
# Date:    2026-10-25
#
# PURPOSE:
#   Estimate outage-duration survival probabilities S(t) = P(D > t) using
#   the best-fit Log-normal model and compare with Weibull and Exponential.
#   Generate survival curves and a probability table at key thresholds.
#
# KEY DISTINCTION (important for academic accuracy):
#   - "Outage duration" D = how long a single outage lasts once it starts.
#   - S(t) = P(D > t) = probability an outage is STILL ongoing after t minutes.
#   - This is NOT the same as the probability of a SERVICE FAILURE during
#     normal operation (that would require inter-arrival time data and
#     exposure windows, which this dataset does not provide directly).
#
# HOW TO RUN IN RSTUDIO:
#   1. Session > Set Working Directory > Choose Directory > WebServiceReliability/
#   2. File > Open File > scripts/04_reliability_analysis.R
#   3. Press Ctrl+Shift+Enter
# =============================================================================

# -- 0. Setup ------------------------------------------------------------------

if (basename(getwd()) == "scripts") setwd("..")
cat("Working directory:", getwd(), "\n\n")

for (pkg in c("readr", "fitdistrplus", "survival")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  library(pkg, character.only = TRUE)
}

plot_dir  <- file.path("results", "plots")
table_dir <- file.path("results", "tables")
dir.create(plot_dir,  recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# -- 1. Load Data and Re-Fit Best Models ---------------------------------------

df <- read_csv(file.path("data", "processed", "Snapchat_cleaned.csv"),
               show_col_types = FALSE)
x  <- df$duration_min

cat(sprintf("Loaded %d outage durations (minutes).\n\n", length(x)))

# Re-fit the three models (same as Phase 3)
fit_lnorm <- fitdist(x, "lnorm",   method = "mle")
fit_wei   <- fitdist(x, "weibull", method = "mle")
fit_exp   <- fitdist(x, "exp",     method = "mle")

mu    <- fit_lnorm$estimate["meanlog"]
sigma <- fit_lnorm$estimate["sdlog"]
k     <- fit_wei$estimate["shape"]
lam   <- fit_wei$estimate["scale"]
rate  <- fit_exp$estimate["rate"]

cat("Parameters loaded from MLE fits:\n")
cat(sprintf("  Log-normal: meanlog=%.4f, sdlog=%.4f\n", mu, sigma))
cat(sprintf("  Weibull:    shape=%.4f,   scale=%.4f\n", k, lam))
cat(sprintf("  Exponential: rate=%.6f\n\n", rate))

# -- 2. Conceptual Background (printed to console) -----------------------------

cat("=== CONCEPTUAL BACKGROUND ===\n\n")
cat("Survival function:  S(t) = P(D > t) = 1 - F(t)\n")
cat("where D = outage duration, F(t) = CDF of the fitted distribution.\n\n")
cat("Interpretation: S(30) = 0.40 means 40% of outages last MORE than 30 min.\n\n")
cat("Hazard function: h(t) = f(t) / S(t)\n")
cat("Interpretation: instantaneous 'rate' at which an outage ends at time t,\n")
cat("given it has lasted until time t.\n\n")

# -- 3. Define Time Thresholds -------------------------------------------------

# Based on observed data: min=20 min, median=20 min, mean=34 min, max=1820 min
# Choose thresholds that span the practical range meaningfully.
thresholds <- c(20, 30, 40, 60, 80, 100, 120, 180, 240, 360, 480, 720, 1440)
cat("Time thresholds (minutes):", paste(thresholds, collapse = ", "), "\n\n")

# -- 4. Compute S(t) for Each Model at Each Threshold -------------------------

# S(t) = 1 - CDF(t)
S_lnorm <- 1 - plnorm(thresholds, meanlog = mu,   sdlog  = sigma)
S_wei   <- 1 - pweibull(thresholds, shape  = k,   scale  = lam)
S_exp   <- 1 - pexp(thresholds,    rate   = rate)

# Empirical survival: proportion of observations > t
S_empirical <- sapply(thresholds, function(t) mean(x > t))

# Build survival table
survival_table <- data.frame(
  Threshold_min   = thresholds,
  Threshold_label = c("20 min","30 min","40 min","1 hr","1h20","1h40",
                       "2 hr","3 hr","4 hr","6 hr","8 hr","12 hr","24 hr"),
  S_empirical     = round(S_empirical, 4),
  S_lognormal     = round(S_lnorm,    4),
  S_weibull       = round(S_wei,      4),
  S_exponential   = round(S_exp,      4)
)

cat("=== SURVIVAL TABLE: S(t) = P(Outage Duration > t) ===\n\n")
print(survival_table, row.names = FALSE)

write_csv(survival_table, file.path(table_dir, "04_survival_table.csv"))
cat("\nSurvival table saved to: results/tables/04_survival_table.csv\n\n")

# -- 5. Plain-Language Interpretation of Key Thresholds -----------------------

cat("=== PLAIN-LANGUAGE INTERPRETATION ===\n\n")
t_vals <- c(20, 60, 120, 480)
for (tv in t_vals) {
  idx <- which(thresholds == tv)
  cat(sprintf("  At t = %d minutes:\n", tv))
  cat(sprintf("    Empirical:  %.1f%% of outages last longer than %d min\n",
              100*S_empirical[idx], tv))
  cat(sprintf("    Log-normal: %.1f%% predicted to last longer\n",
              100*S_lnorm[idx]))
  cat(sprintf("    Weibull:    %.1f%% predicted to last longer\n",
              100*S_wei[idx]))
  cat(sprintf("    Exponential:%.1f%% predicted to last longer\n\n",
              100*S_exp[idx]))
}

# -- 6. Compute Hazard Functions -----------------------------------------------

cat("=== HAZARD FUNCTION SUMMARY ===\n\n")
cat("The hazard function h(t) = rate at which an ongoing outage resolves at time t.\n\n")

t_grid <- seq(20, 500, by = 1)

# Log-normal hazard: h(t) = f(t)/S(t)
h_lnorm <- dlnorm(t_grid, meanlog = mu, sdlog = sigma) /
           (1 - plnorm(t_grid, meanlog = mu, sdlog = sigma))

# Weibull hazard: h(t) = (k/lambda)*(t/lambda)^(k-1)
h_wei <- dweibull(t_grid, shape = k, scale = lam) /
         (1 - pweibull(t_grid, shape = k, scale = lam))

# Exponential hazard: constant = rate
h_exp <- rep(rate, length(t_grid))

cat(sprintf("  Exponential hazard (constant): %.6f /min\n", rate))
cat(sprintf("  Weibull shape=%.4f => INCREASING hazard (h(t) grows with t)\n", k))
cat("  Log-normal hazard: rises then falls (non-monotone -- most realistic)\n\n")

# -- 7. PLOT 1: Survival Curves (all three models + empirical KM) --------------

# Kaplan-Meier empirical survival (no censoring: all events observed)
km_fit <- survfit(Surv(x) ~ 1)

png(file.path(plot_dir, "04a_survival_curves.png"), width = 950, height = 600, res = 110)

# Plot KM first
plot(km_fit,
     conf.int = FALSE,
     col      = "#2C3E50",
     lwd      = 2.5,
     main     = "Outage-Duration Survival Curves: S(t) = P(Duration > t)\nSnapchat — Empirical (KM) vs. Fitted Models",
     xlab     = "Outage Duration t (minutes)",
     ylab     = "S(t) = Probability outage is still ongoing",
     xlim     = c(0, 500),
     ylim     = c(0, 1),
     las      = 1)

# Overlay parametric curves
t_smooth <- seq(0.1, 500, length.out = 2000)
lines(t_smooth, 1 - plnorm(t_smooth, meanlog = mu, sdlog = sigma),
      col = "#8E44AD", lwd = 2.5)
lines(t_smooth, 1 - pweibull(t_smooth, shape = k, scale = lam),
      col = "#27AE60", lwd = 2.5, lty = 2)
lines(t_smooth, 1 - pexp(t_smooth, rate = rate),
      col = "#E74C3C", lwd = 2.5, lty = 3)

# Reference lines at key probabilities
abline(h = c(0.50, 0.25, 0.10), col = "gray70", lty = 2, lwd = 0.8)
text(x = 490, y = c(0.52, 0.27, 0.12),
     labels = c("50%", "25%", "10%"),
     col = "gray50", cex = 0.72, adj = 1)

legend("topright",
       legend = c("Kaplan-Meier (empirical)",
                  "Log-normal (best fit)",
                  "Weibull",
                  "Exponential"),
       col    = c("#2C3E50", "#8E44AD", "#27AE60", "#E74C3C"),
       lwd    = 2.5,
       lty    = c(1, 1, 2, 3),
       bty    = "n",
       cex    = 0.85)

dev.off()
cat("Plot saved: results/plots/04a_survival_curves.png\n")

# -- 8. PLOT 2: Survival Curves on Log-Time Scale ------------------------------

png(file.path(plot_dir, "04b_survival_log_scale.png"), width = 950, height = 600, res = 110)

plot(km_fit,
     conf.int = FALSE,
     col      = "#2C3E50",
     lwd      = 2.5,
     log      = "x",
     main     = "Survival Curves on Log Time Scale\nSnapchat Outage Durations",
     xlab     = "Outage Duration t (minutes, log scale)",
     ylab     = "S(t) = P(Duration > t)",
     xlim     = c(20, 2000),
     ylim     = c(0, 1),
     las      = 1)

t_log <- seq(20, 2000, length.out = 3000)
lines(t_log, 1 - plnorm(t_log, meanlog = mu, sdlog = sigma),
      col = "#8E44AD", lwd = 2.5)
lines(t_log, 1 - pweibull(t_log, shape = k, scale = lam),
      col = "#27AE60", lwd = 2.5, lty = 2)
lines(t_log, 1 - pexp(t_log, rate = rate),
      col = "#E74C3C", lwd = 2.5, lty = 3)

legend("topright",
       legend = c("Kaplan-Meier", "Log-normal", "Weibull", "Exponential"),
       col    = c("#2C3E50", "#8E44AD", "#27AE60", "#E74C3C"),
       lwd    = 2.5, lty = c(1,1,2,3), bty = "n", cex = 0.85)

dev.off()
cat("Plot saved: results/plots/04b_survival_log_scale.png\n")

# -- 9. PLOT 3: Hazard Functions -----------------------------------------------

png(file.path(plot_dir, "04c_hazard_functions.png"), width = 950, height = 580, res = 110)

ylim_max <- min(max(h_lnorm, h_wei, na.rm = TRUE), 0.15)

plot(t_grid, h_lnorm,
     type = "l",
     col  = "#8E44AD",
     lwd  = 2.5,
     ylim = c(0, ylim_max),
     main = "Hazard Functions h(t): Rate of Outage Resolution\nSnapchat — All Three Fitted Models",
     xlab = "Outage Duration t (minutes)",
     ylab = "Hazard rate h(t) [per minute]",
     las  = 1)
lines(t_grid, h_wei, col = "#27AE60", lwd = 2.5, lty = 2)
lines(t_grid, h_exp, col = "#E74C3C", lwd = 2.5, lty = 3)

legend("topright",
       legend = c("Log-normal (rises then falls)",
                  "Weibull (monotone increasing)",
                  "Exponential (constant)"),
       col    = c("#8E44AD", "#27AE60", "#E74C3C"),
       lwd    = 2.5,
       lty    = c(1, 2, 3),
       bty    = "n",
       cex    = 0.82)

dev.off()
cat("Plot saved: results/plots/04c_hazard_functions.png\n")

# -- 10. PLOT 4: Bar chart of S(t) at key thresholds --------------------------

png(file.path(plot_dir, "04d_survival_probability_bars.png"), width = 1000, height = 580, res = 110)

sel_idx <- which(thresholds %in% c(20, 40, 60, 120, 240, 480))
sel_t   <- thresholds[sel_idx]
sel_lab <- paste0(sel_t, " min")

# Matrix: rows = thresholds, cols = models
bar_mat <- rbind(
  S_empirical[sel_idx],
  S_lnorm[sel_idx],
  S_wei[sel_idx],
  S_exp[sel_idx]
)

barplot(bar_mat,
        beside  = TRUE,
        names.arg = sel_lab,
        col     = c("#2C3E50", "#8E44AD", "#27AE60", "#E74C3C"),
        border  = NA,
        ylim    = c(0, 1),
        main    = "S(t) = P(Outage Still Ongoing) at Key Thresholds\nSnapchat — Model Comparison",
        xlab    = "Time Threshold",
        ylab    = "Survival Probability S(t)",
        las     = 1,
        cex.names = 0.85)

legend("topright",
       legend = c("Empirical", "Log-normal", "Weibull", "Exponential"),
       fill   = c("#2C3E50", "#8E44AD", "#27AE60", "#E74C3C"),
       border = NA,
       bty    = "n",
       cex    = 0.85)

dev.off()
cat("Plot saved: results/plots/04d_survival_probability_bars.png\n\n")

# -- 11. Median Residual Life --------------------------------------------------

cat("=== MEDIAN RESIDUAL OUTAGE LIFE ===\n\n")
cat("Given an outage has already lasted t minutes,\n")
cat("what is the median ADDITIONAL time it will last?\n\n")

# For log-normal: compute via numerical inversion
med_res_life <- function(t0, model = "lnorm") {
  # Find m such that S(t0 + m) / S(t0) = 0.5 => S(t0+m) = 0.5 * S(t0)
  S_t0 <- 1 - plnorm(t0, meanlog = mu, sdlog = sigma)
  target <- 0.5 * S_t0
  if (target <= 0) return(NA)
  # Solve numerically
  result <- tryCatch(
    uniroot(function(m) (1 - plnorm(t0 + m, meanlog = mu, sdlog = sigma)) - target,
            interval = c(0.001, 10000))$root,
    error = function(e) NA
  )
  return(result)
}

mrl_table <- data.frame(
  Given_lasted_min = c(20, 40, 60, 120),
  Median_additional_min = round(sapply(c(20, 40, 60, 120), med_res_life), 1)
)

print(mrl_table, row.names = FALSE)
write_csv(mrl_table, file.path(table_dir, "04_median_residual_life.csv"))
cat("\nMedian residual life table saved: results/tables/04_median_residual_life.csv\n\n")

# -- 12. Limitations -----------------------------------------------------------

cat("=== LIMITATIONS ===\n\n")
cat("1. OUTAGE DURATION ONLY: S(t) here describes how long an individual\n")
cat("   outage persists once it starts. It does NOT estimate the\n")
cat("   probability of a service failure occurring during normal operation.\n\n")
cat("2. NO CENSORING: All outage events are fully observed (both start and\n")
cat("   end times are recorded). Standard KM and MLE can be applied without\n")
cat("   censoring adjustments.\n\n")
cat("3. DISCRETE GRANULARITY: Durations are multiples of 20 minutes\n")
cat("   (user-report polling). Continuous distributions are approximations.\n\n")
cat("4. NO INTER-ARRIVAL TIMES: This dataset records outage durations, not\n")
cat("   the time between outages. Operating-period reliability estimates\n")
cat("   (MTBF, availability) require inter-arrival data not available here.\n\n")

# -- 13. Final Summary ---------------------------------------------------------

cat("=============================================================\n")
cat("  PHASE 4 COMPLETE -- RELIABILITY ANALYSIS SUMMARY\n")
cat("=============================================================\n")
cat("  Best model: Log-normal (mu=3.2994, sigma=0.5401)\n\n")
cat("  Key survival probabilities (Log-normal model):\n")
key_t <- c(20, 60, 120, 480)
for (tv in key_t) {
  idx <- which(thresholds == tv)
  cat(sprintf("    S(%4d min) = %.1f%% of outages still ongoing\n",
              tv, 100*S_lnorm[idx]))
}
cat("-------------------------------------------------------------\n")
cat("  Plots saved:\n")
cat("    results/plots/04a_survival_curves.png\n")
cat("    results/plots/04b_survival_log_scale.png\n")
cat("    results/plots/04c_hazard_functions.png\n")
cat("    results/plots/04d_survival_probability_bars.png\n")
cat("  Tables saved:\n")
cat("    results/tables/04_survival_table.csv\n")
cat("    results/tables/04_median_residual_life.csv\n")
cat("=============================================================\n\n")
