# Analyse outage-duration survival and resolution hazards.

if (basename(getwd()) == "scripts") setwd("..")

plot_dir <- file.path("results", "plots")
table_dir <- file.path("results", "tables")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)

# Load cleaned durations and fit Weibull parameters.
df <- read.csv(file.path("data", "processed", "Snapchat_cleaned.csv"))
x <- df$duration_min
rate <- 1 / mean(x)
nll <- function(theta) -sum(dweibull(x, exp(theta[1]), exp(theta[2]), log = TRUE))
fit <- optim(log(c(1, mean(x))), nll, method = "L-BFGS-B", lower = log(c(.05, 1)), upper = log(c(20, 10000)))
shape <- exp(fit$par[1])
scale <- exp(fit$par[2])

# Calculate survival probabilities.
thresholds <- c(20, 40, 60, 120, 240, 480)
surv <- data.frame(Threshold_minutes = thresholds, Empirical = sapply(thresholds, function(t) mean(x > t)), Exponential = pexp(thresholds, rate, lower.tail = FALSE), Weibull = pweibull(thresholds, shape, scale, lower.tail = FALSE))
write.csv(surv, file.path(table_dir, "04_survival_table.csv"), row.names = FALSE)

t <- seq(.1, 500, length.out = 1000)

# Plot survival functions.
png(file.path(plot_dir, "04a_survival_curves.png"), width = 950, height = 600, res = 110)
plot(t, 1 - ecdf(x)(t), type = "s", col = "#333333", lwd = 2, xlim = c(0, 500), ylim = c(0, 1), main = "Outage-duration survival functions", xlab = "Duration (minutes)", ylab = "S(t) = P(duration > t)")
lines(t, pexp(t, rate, lower.tail = FALSE), col = "#CC3333", lwd = 2)
lines(t, pweibull(t, shape, scale, lower.tail = FALSE), col = "#228B22", lwd = 2)
legend("topright", c("Empirical", "Exponential", "Weibull"), col = c("#333333", "#CC3333", "#228B22"), lwd = 2, bty = "n")
dev.off()

# Plot resolution hazards.
png(file.path(plot_dir, "04c_hazard_functions.png"), width = 950, height = 580, res = 110)
wh <- (shape / scale) * (t / scale)^(shape - 1)
plot(t, rep(rate, length(t)), type = "l", col = "#CC3333", lwd = 2, ylim = c(0, max(rate, wh)), main = "Hazard of outage resolution", xlab = "Outage duration (minutes)", ylab = "Resolution hazard (per minute)")
lines(t, wh, col = "#228B22", lwd = 2)
legend("topleft", c("Exponential: constant", "Weibull"), col = c("#CC3333", "#228B22"), lwd = 2, bty = "n")
dev.off()

cat("This analysis models resolution time after an outage begins. It does not estimate uptime, MTBF, or availability.\n")
