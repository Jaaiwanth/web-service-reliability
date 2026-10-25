# Fit distributions and run chi-square goodness-of-fit tests.

if (basename(getwd()) == "scripts") setwd("..")

plot_dir <- file.path("results", "plots")
table_dir <- file.path("results", "tables")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# Load cleaned durations.
df <- read.csv(file.path("data", "processed", "Snapchat_cleaned.csv"))
x <- df$duration_min
stopifnot(all(is.finite(x)), all(x > 0))
n <- length(x)

# Fit distributions.
normal_mean <- mean(x)
normal_sd <- sd(x)
exp_rate <- 1 / mean(x)
weibull_nll <- function(theta) -sum(dweibull(x, shape = exp(theta[1]), scale = exp(theta[2]), log = TRUE))
wei_opt <- optim(log(c(1, mean(x))), weibull_nll, method = "L-BFGS-B", lower = log(c(.05, 1)), upper = log(c(20, 10000)))
wei_shape <- exp(wei_opt$par[1])
wei_scale <- exp(wei_opt$par[2])

parameters <- data.frame(Distribution = c("Normal", "Normal", "Exponential", "Weibull", "Weibull"), Parameter = c("mean (minutes)", "standard deviation (minutes)", "rate (per minute)", "shape", "scale (minutes)"), Estimate = c(normal_mean, normal_sd, exp_rate, wei_shape, wei_scale))
write.csv(parameters, file.path(table_dir, "03_parameter_estimates.csv"), row.names = FALSE)

# Define duration classes for the chi-square test.
breaks <- c(0, 20, 40, 60, 80, 120, Inf)
labels <- c("(0, 20]", "(20, 40]", "(40, 60]", "(60, 80]", "(80, 120]", "> 120")
observed <- as.numeric(table(cut(x, breaks = breaks, right = TRUE)))

class_prob <- function(cdf, conditional_positive = FALSE) {
  p <- sapply(seq_along(labels), function(i) cdf(breaks[i + 1]) - cdf(breaks[i]))
  if (conditional_positive) p <- p / (1 - cdf(0))
  p
}

# Condition Normal probabilities on positive durations.
p_normal <- class_prob(function(z) pnorm(z, normal_mean, normal_sd), TRUE)
p_exp <- class_prob(function(z) pexp(z, exp_rate))
p_wei <- class_prob(function(z) pweibull(z, wei_shape, wei_scale))

make_gof <- function(name, probs, k) {
  expected <- n * probs
  stat <- sum((observed - expected)^2 / expected)
  dfr <- length(observed) - 1 - k
  pv <- pchisq(stat, dfr, lower.tail = FALSE)

  list(
    row = data.frame(Distribution = name, Chi_square = stat, Degrees_freedom = dfr, P_value = pv, Minimum_expected = min(expected), Decision = ifelse(pv < .05, "Reject H0 at 5%", "Do not reject H0 at 5%")),
    detail = data.frame(Distribution = name, Class = labels, Observed = observed, Expected = expected)
  )
}

tests <- list(
  make_gof("Normal (conditional on positive duration)", p_normal, 2),
  make_gof("Exponential", p_exp, 1),
  make_gof("Weibull", p_wei, 2)
)
gof <- do.call(rbind, lapply(tests, `[[`, "row"))
detail <- do.call(rbind, lapply(tests, `[[`, "detail"))
write.csv(gof, file.path(table_dir, "03_chi_square_gof.csv"), row.names = FALSE)
write.csv(detail, file.path(table_dir, "03_chi_square_observed_expected.csv"), row.names = FALSE)

# Plot fitted densities.
png(file.path(plot_dir, "03a_fitted_densities.png"), width = 950, height = 580, res = 110)
hist(x[x <= 160], breaks = seq(0, 160, 10), freq = FALSE, xlim = c(0, 160), col = "#D0E8F5", border = "white", main = "Outage duration distribution (zoom to 160 min)", xlab = "Outage duration (minutes)", ylab = "Density")
grid <- seq(.01, 160, length.out = 1000)
lines(grid, dnorm(grid, normal_mean, normal_sd), col = "#3366CC", lwd = 2)
lines(grid, dexp(grid, exp_rate), col = "#CC3333", lwd = 2)
lines(grid, dweibull(grid, wei_shape, wei_scale), col = "#228B22", lwd = 2)
legend("topright", c("Normal", "Exponential", "Weibull"), col = c("#3366CC", "#CC3333", "#228B22"), lwd = 2, bty = "n")
dev.off()

# Plot observed and expected frequencies.
png(file.path(plot_dir, "03b_chi_square_observed_expected.png"), width = 950, height = 580, res = 110)
barplot(rbind(observed, n*p_normal, n*p_exp, n*p_wei), beside = TRUE, names.arg = labels, col = c("#333333", "#3366CC", "#CC3333", "#228B22"), main = "Observed and expected frequencies by duration class", xlab = "Outage-duration class (minutes)", ylab = "Frequency")
legend("topright", c("Observed", "Normal", "Exponential", "Weibull"), fill = c("#333333", "#3366CC", "#CC3333", "#228B22"), bty = "n")
dev.off()

cat("Chi-square goodness-of-fit results (H0: the stated distribution describes positive outage durations):\n")
print(gof, row.names = FALSE)
