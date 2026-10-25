# =============================================================================
# PHASE 3: Distribution Fitting and Model Comparison
# Project: Probabilistic Reliability Modeling of Web Services
# File:    scripts/03_distribution_fitting.R
# Author:  [Your Name]
# Date:    2026-10-25
#
# PURPOSE:
#   Fit Exponential, Weibull, and Log-normal distributions to the cleaned
#   outage durations using Maximum Likelihood Estimation (MLE).
#   Compare models via AIC, BIC, and graphical diagnostics.
#
# HOW TO RUN IN RSTUDIO:
#   1. Session > Set Working Directory > Choose Directory > WebServiceReliability/
#   2. File > Open File > scripts/03_distribution_fitting.R
#   3. Press Ctrl+Shift+Enter (or click the Source button)
# =============================================================================

# -- 0. Setup ------------------------------------------------------------------

if (basename(getwd()) == "scripts") setwd("..")
cat("Working directory:", getwd(), "\n\n")

for (pkg in c("readr", "fitdistrplus")) {
  if (!requireNamespace(pkg, quietly = TRUE))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  library(pkg, character.only = TRUE)
}

plot_dir  <- file.path("results", "plots")
table_dir <- file.path("results", "tables")
dir.create(plot_dir,  recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# -- 1. Load Cleaned Data ------------------------------------------------------

df  <- read_csv(file.path("data", "processed", "Snapchat_cleaned.csv"),
                show_col_types = FALSE)
x   <- df$duration_min   # outage durations in minutes (all positive)

cat(sprintf("Loaded %d valid outage durations (minutes).\n\n", length(x)))

# -- 2. Fit the Three Candidate Distributions ----------------------------------
# All three are fitted on the SAME observations using MLE.
# fitdist() from the fitdistrplus package handles this cleanly.

cat("=== FITTING DISTRIBUTIONS (MLE) ===\n\n")

# --- 2a. Exponential ----------------------------------------------------------
# PDF: f(x) = lambda * exp(-lambda * x),  x > 0
# Parameter: rate (lambda = 1/mean)
cat("Fitting Exponential...\n")
fit_exp <- fitdist(x, distr = "exp", method = "mle")
cat("  rate (lambda) =", round(fit_exp$estimate["rate"], 6), "\n")
cat("  Mean of fitted Exp = 1/lambda =",
    round(1 / fit_exp$estimate["rate"], 2), "minutes\n\n")

# --- 2b. Weibull --------------------------------------------------------------
# PDF: f(x) = (shape/scale) * (x/scale)^(shape-1) * exp(-(x/scale)^shape)
# Parameters: shape (k), scale (lambda)
# shape < 1: decreasing failure rate (infant mortality)
# shape = 1: constant failure rate (reduces to Exponential)
# shape > 1: increasing failure rate (aging)
cat("Fitting Weibull...\n")
fit_wei <- fitdist(x, distr = "weibull", method = "mle")
cat("  shape (k)     =", round(fit_wei$estimate["shape"], 4), "\n")
cat("  scale (lambda)=", round(fit_wei$estimate["scale"], 4), "\n\n")

# --- 2c. Log-normal -----------------------------------------------------------
# PDF: f(x) = 1/(x*sigma*sqrt(2*pi)) * exp(-(log(x)-mu)^2 / (2*sigma^2))
# Parameters: meanlog (mu), sdlog (sigma) -- mean and sd of log(x)
cat("Fitting Log-normal...\n")
fit_lnorm <- fitdist(x, distr = "lnorm", method = "mle")
cat("  meanlog (mu)  =", round(fit_lnorm$estimate["meanlog"], 4), "\n")
cat("  sdlog (sigma) =", round(fit_lnorm$estimate["sdlog"], 4), "\n\n")

# -- 3. Model Comparison Table: AIC & BIC --------------------------------------
# AIC = -2*logLik + 2*k   (lower is better; penalises extra parameters)
# BIC = -2*logLik + k*log(n) (lower is better; penalises more strongly)
# k = number of parameters, n = sample size

cat("=== MODEL COMPARISON: AIC & BIC ===\n\n")

models <- list(Exponential = fit_exp,
               Weibull     = fit_wei,
               Lognormal   = fit_lnorm)

comparison <- data.frame(
  Distribution = names(models),
  Parameters   = c(length(fit_exp$estimate),
                   length(fit_wei$estimate),
                   length(fit_lnorm$estimate)),
  LogLik       = round(sapply(models, function(m) m$loglik), 2),
  AIC          = round(sapply(models, function(m) m$aic),    2),
  BIC          = round(sapply(models, function(m) m$bic),    2)
)

# Rank by AIC
comparison <- comparison[order(comparison$AIC), ]
comparison$AIC_rank <- rank(comparison$AIC)
rownames(comparison) <- NULL

print(comparison)

write_csv(comparison, file.path(table_dir, "03_model_comparison_AIC_BIC.csv"))
cat("\nModel comparison table saved to: results/tables/03_model_comparison_AIC_BIC.csv\n\n")

# Best model by AIC
best_model_name <- comparison$Distribution[1]
cat(sprintf("Best model by AIC: %s\n\n", best_model_name))

# -- 4. Parameter Estimates Table ----------------------------------------------

param_table <- data.frame(
  Distribution = c("Exponential", "Exponential",
                   "Weibull",     "Weibull",
                   "Lognormal",   "Lognormal"),
  Parameter    = c("rate (lambda)", "mean = 1/lambda",
                   "shape (k)",    "scale (lambda)",
                   "meanlog (mu)", "sdlog (sigma)"),
  Estimate     = c(round(fit_exp$estimate["rate"],        6),
                   round(1/fit_exp$estimate["rate"],      4),
                   round(fit_wei$estimate["shape"],       4),
                   round(fit_wei$estimate["scale"],       4),
                   round(fit_lnorm$estimate["meanlog"],   4),
                   round(fit_lnorm$estimate["sdlog"],     4)),
  Std_Error    = c(round(fit_exp$sd["rate"],              6),
                   NA,
                   round(fit_wei$sd["shape"],             4),
                   round(fit_wei$sd["scale"],             4),
                   round(fit_lnorm$sd["meanlog"],         4),
                   round(fit_lnorm$sd["sdlog"],           4))
)

write_csv(param_table, file.path(table_dir, "03_parameter_estimates.csv"))
cat("Parameter estimates saved to: results/tables/03_parameter_estimates.csv\n\n")

# -- 5. Goodness-of-Fit Tests (KS test) ----------------------------------------

cat("=== KOLMOGOROV-SMIRNOV GOODNESS-OF-FIT ===\n")
cat("(Tests whether the data could come from the fitted distribution)\n")
cat("A larger p-value means a better fit. p < 0.05 = poor fit.\n\n")

ks_exp   <- ks.test(x, "pexp",   rate     = fit_exp$estimate["rate"])
ks_wei   <- ks.test(x, "pweibull",
                    shape = fit_wei$estimate["shape"],
                    scale = fit_wei$estimate["scale"])
ks_lnorm <- ks.test(x, "plnorm",
                    meanlog = fit_lnorm$estimate["meanlog"],
                    sdlog   = fit_lnorm$estimate["sdlog"])

ks_table <- data.frame(
  Distribution = c("Exponential", "Weibull", "Lognormal"),
  KS_Statistic = round(c(ks_exp$statistic, ks_wei$statistic, ks_lnorm$statistic), 4),
  P_Value      = signif(c(ks_exp$p.value, ks_wei$p.value, ks_lnorm$p.value), 4)
)
print(ks_table)

write_csv(ks_table, file.path(table_dir, "03_ks_test_results.csv"))
cat("\nKS test results saved to: results/tables/03_ks_test_results.csv\n\n")

cat("NOTE: With n=2549 and discrete (granular) data, all KS tests may\n")
cat("      yield small p-values. AIC/BIC and graphical diagnostics are\n")
cat("      more informative for model selection here.\n\n")

# -- 6. PLOT 1: Fitted Density Curves on Histogram -----------------------------

png(file.path(plot_dir, "03a_fitted_densities.png"), width = 950, height = 580, res = 110)

# Plot empirical density
hist(x,
     breaks = 50,
     freq   = FALSE,
     col    = "#D0E8F5",
     border = "#AACCDD",
     main   = "Fitted Probability Density Functions vs. Empirical Data\nSnapchat Outage Durations",
     xlab   = "Outage Duration (minutes)",
     ylab   = "Density",
     las    = 1,
     xlim   = c(0, quantile(x, 0.99)))   # zoom to 99th percentile for clarity

# x grid for smooth curves
x_grid <- seq(1, quantile(x, 0.995), length.out = 1000)

# Overlay fitted PDFs
lines(x_grid, dexp(x_grid, rate = fit_exp$estimate["rate"]),
      col = "#E74C3C", lwd = 2.5)
lines(x_grid, dweibull(x_grid,
                        shape = fit_wei$estimate["shape"],
                        scale = fit_wei$estimate["scale"]),
      col = "#27AE60", lwd = 2.5)
lines(x_grid, dlnorm(x_grid,
                      meanlog = fit_lnorm$estimate["meanlog"],
                      sdlog   = fit_lnorm$estimate["sdlog"]),
      col = "#8E44AD", lwd = 2.5)

legend("topright",
       legend = c(sprintf("Exponential  (AIC=%.0f)", fit_exp$aic),
                  sprintf("Weibull      (AIC=%.0f)", fit_wei$aic),
                  sprintf("Log-normal   (AIC=%.0f)", fit_lnorm$aic),
                  "Empirical"),
       col    = c("#E74C3C", "#27AE60", "#8E44AD", "#D0E8F5"),
       lwd    = c(2.5, 2.5, 2.5, 8),
       bty    = "n",
       cex    = 0.82)

dev.off()
cat("Plot saved: results/plots/03a_fitted_densities.png\n")

# -- 7. PLOT 2: Empirical vs Fitted CDF ----------------------------------------

png(file.path(plot_dir, "03b_cdf_comparison.png"), width = 950, height = 600, res = 110)

# Empirical CDF
plot(ecdf(x),
     col  = "#2C3E50",
     lwd  = 2,
     pch  = NA,
     main = "Empirical CDF vs. Fitted CDFs\nSnapchat Outage Durations",
     xlab = "Outage Duration (minutes)",
     ylab = "Cumulative Probability F(t)",
     las  = 1,
     xlim = c(0, quantile(x, 0.995)))

# Theoretical CDFs
x_cdf <- seq(0.1, quantile(x, 0.999), length.out = 2000)
lines(x_cdf, pexp(x_cdf, rate = fit_exp$estimate["rate"]),
      col = "#E74C3C", lwd = 2.5)
lines(x_cdf, pweibull(x_cdf,
                       shape = fit_wei$estimate["shape"],
                       scale = fit_wei$estimate["scale"]),
      col = "#27AE60", lwd = 2.5)
lines(x_cdf, plnorm(x_cdf,
                     meanlog = fit_lnorm$estimate["meanlog"],
                     sdlog   = fit_lnorm$estimate["sdlog"]),
      col = "#8E44AD", lwd = 2.5)

legend("bottomright",
       legend = c("Empirical (ECDF)",
                  "Exponential",
                  "Weibull",
                  "Log-normal"),
       col    = c("#2C3E50", "#E74C3C", "#27AE60", "#8E44AD"),
       lwd    = c(2, 2.5, 2.5, 2.5),
       bty    = "n",
       cex    = 0.85)

dev.off()
cat("Plot saved: results/plots/03b_cdf_comparison.png\n")

# -- 8. PLOT 3: Q-Q Plots (one per distribution) --------------------------------

png(file.path(plot_dir, "03c_qq_plots.png"), width = 1050, height = 380, res = 110)
par(mfrow = c(1, 3), mar = c(4, 4, 3, 1))

# Exponential Q-Q
qqcomp(fit_exp,
       main   = "Q-Q Plot: Exponential",
       xlab   = "Theoretical Quantiles",
       ylab   = "Empirical Quantiles",
       fitcol = "#E74C3C")

# Weibull Q-Q
qqcomp(fit_wei,
       main   = "Q-Q Plot: Weibull",
       xlab   = "Theoretical Quantiles",
       ylab   = "Empirical Quantiles",
       fitcol = "#27AE60")

# Log-normal Q-Q
qqcomp(fit_lnorm,
       main   = "Q-Q Plot: Log-normal",
       xlab   = "Theoretical Quantiles",
       ylab   = "Empirical Quantiles",
       fitcol = "#8E44AD")

par(mfrow = c(1, 1))
dev.off()
cat("Plot saved: results/plots/03c_qq_plots.png\n")

# -- 9. PLOT 4: Log-scale CDF (reveals tail fit quality) -----------------------

png(file.path(plot_dir, "03d_log_cdf.png"), width = 950, height = 600, res = 110)

# ECDF on log x-scale
plot(ecdf(x),
     log  = "x",
     col  = "#2C3E50",
     lwd  = 2,
     pch  = NA,
     main = "CDF on Log-scale: Tail Fit Comparison\nSnapchat Outage Durations",
     xlab = "Outage Duration (minutes, log scale)",
     ylab = "Cumulative Probability F(t)",
     las  = 1,
     xlim = c(min(x), max(x)))

x_log <- seq(min(x), max(x), length.out = 3000)
lines(x_log, pexp(x_log, rate = fit_exp$estimate["rate"]),
      col = "#E74C3C", lwd = 2.5)
lines(x_log, pweibull(x_log,
                       shape = fit_wei$estimate["shape"],
                       scale = fit_wei$estimate["scale"]),
      col = "#27AE60", lwd = 2.5)
lines(x_log, plnorm(x_log,
                     meanlog = fit_lnorm$estimate["meanlog"],
                     sdlog   = fit_lnorm$estimate["sdlog"]),
      col = "#8E44AD", lwd = 2.5)

legend("bottomright",
       legend = c("Empirical (ECDF)", "Exponential", "Weibull", "Log-normal"),
       col    = c("#2C3E50", "#E74C3C", "#27AE60", "#8E44AD"),
       lwd    = 2.5,
       bty    = "n",
       cex    = 0.85)

dev.off()
cat("Plot saved: results/plots/03d_log_cdf.png\n\n")

# -- 10. Interpretation --------------------------------------------------------

cat("=== INTERPRETATION OF RESULTS ===\n\n")
cat(sprintf("Best model by AIC: %s\n\n", best_model_name))

cat("What the parameters tell us:\n\n")

cat(sprintf("  EXPONENTIAL: rate=%.6f => mean outage = %.1f min\n",
            fit_exp$estimate["rate"], 1/fit_exp$estimate["rate"]))
cat("  Assumes outage resolution is equally likely at any moment (memoryless).\n\n")

cat(sprintf("  WEIBULL: shape=%.4f, scale=%.2f min\n",
            fit_wei$estimate["shape"], fit_wei$estimate["scale"]))
if (fit_wei$estimate["shape"] < 1) {
  cat("  Shape < 1: outage resolution becomes MORE likely over time\n")
  cat("  (once an outage starts, it tends to resolve quickly initially).\n\n")
} else if (fit_wei$estimate["shape"] > 1) {
  cat("  Shape > 1: outage resolution becomes LESS likely over time\n")
  cat("  (longer outages become increasingly hard to resolve).\n\n")
} else {
  cat("  Shape = 1: reduces to Exponential (constant resolution rate).\n\n")
}

cat(sprintf("  LOG-NORMAL: meanlog=%.4f, sdlog=%.4f\n",
            fit_lnorm$estimate["meanlog"], fit_lnorm$estimate["sdlog"]))
cat(sprintf("  Median outage (on original scale) = exp(meanlog) = %.1f min\n",
            exp(fit_lnorm$estimate["meanlog"])))
cat("  Log-normal fits when the LOG of duration is normally distributed,\n")
cat("  common for complex system recovery processes.\n\n")

# -- 11. Final Summary ---------------------------------------------------------

cat("=============================================================\n")
cat("  PHASE 3 COMPLETE -- DISTRIBUTION FITTING SUMMARY\n")
cat("=============================================================\n")
print(comparison[, c("Distribution","AIC","BIC","AIC_rank")], row.names = FALSE)
cat("-------------------------------------------------------------\n")
cat(sprintf("  BEST FIT (lowest AIC): %s\n", best_model_name))
cat("-------------------------------------------------------------\n")
cat("  Plots saved:\n")
cat("    results/plots/03a_fitted_densities.png\n")
cat("    results/plots/03b_cdf_comparison.png\n")
cat("    results/plots/03c_qq_plots.png\n")
cat("    results/plots/03d_log_cdf.png\n")
cat("  Tables saved:\n")
cat("    results/tables/03_model_comparison_AIC_BIC.csv\n")
cat("    results/tables/03_parameter_estimates.csv\n")
cat("    results/tables/03_ks_test_results.csv\n")
cat("=============================================================\n\n")
