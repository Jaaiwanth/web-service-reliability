# Probabilistic Reliability Modeling of Web Services Using Failure-Time Distributions

## Abstract

This BMAT202L project analyses 2,549 user-reported Snapchat outage durations from the Cloud Uptime Archive. Durations were computed as `end_time - start_time` and expressed in minutes. Descriptive statistics show a strongly right-skewed distribution (mean 34.23 minutes; median 20 minutes). Normal, Exponential, and Weibull distributions were fitted. Chi-square goodness-of-fit tests at 5% rejected all three fitted continuous models, so none is claimed as an exact distribution. The Weibull model remains useful as a descriptive reliability approximation: its estimated resolution-hazard shape is 1.184. Because the event is outage resolution, this increasing hazard means the instantaneous rate of resolution rises among outages still unresolved—not that recovery becomes harder. The data do not contain uptime exposure or inter-failure intervals, so availability and MTBF are not estimated.

## 1. Introduction, Research Question, and Objectives

**Research question:** How are observed Snapchat outage durations distributed, and what do syllabus-approved distribution and reliability concepts say about outage recovery?

Objectives are to: (1) check and describe the data; (2) fit Normal, Exponential, and Weibull distributions (Module 4); (3) apply chi-square goodness-of-fit tests (Module 6); and (4) interpret survival, hazard, maintainability, and series/parallel concepts (Module 7).

## 2. Dataset and Data Quality

`data/raw/Snapchat_user_reported.csv` has 2,549 rows and four columns: `start_time`, `end_time`, `status`, and `service`. All records are Snapchat. The timestamp values are seconds, as verified by the existing data values and duration calculation; durations are converted to minutes. There are no missing cells, exact duplicates, non-positive durations, or reversed intervals. No observation was removed. The observation span is about 557.2 days.

Durations occur in 20-minute increments. This coarse, user-report-based resolution creates many tied values, so continuous models are approximations rather than literal generating mechanisms.

## 3. Descriptive Statistics — Module 1

| Statistic | Value (minutes) |
|---|---:|
| Sample size | 2,549 |
| Minimum / maximum | 20 / 1,820 |
| Q1 / median / Q3 | 20 / 20 / 40 |
| Mean | 34.2330 |
| Variance / standard deviation | 2,947.1058 / 54.2873 |
| IQR | 20 |
| Skewness | 18.8537 |
| Excess kurtosis | 531.0927 |

The histogram and boxplot show substantial right skew: most durations are 20 minutes, while a small number of long outages lift the mean. See `results/plots/02a_histogram.png` and `02b_boxplot.png`.

## 4. Probability Distributions — Module 4

Parameters were estimated from all positive durations. The Exponential rate is the reciprocal of the sample mean. Weibull parameters were obtained by maximum likelihood; this is an estimation procedure, not an additional syllabus method.

| Distribution | Parameters |
|---|---|
| Normal | mean = 34.2330 min; SD = 54.2873 min |
| Exponential | rate = 0.0292116 per min |
| Weibull | shape = 1.1842; scale = 36.9121 min |

The Normal model is limited because duration is positive, markedly right-skewed, and a Normal distribution allocates probability to negative values. The fitted-density figure is `results/plots/03a_fitted_densities.png`.

## 5. Chi-Square Goodness-of-Fit — Module 6

For each model, **H0** states that positive outage durations follow that fitted distribution; **H1** states that they do not. Six classes were used: (0,20], (20,40], (40,60], (60,80], (80,120], and >120 minutes. Every expected count exceeds 5. For the Normal model, expected probabilities are conditional on a positive duration because only positive durations can be observed. Degrees of freedom are `classes − 1 − estimated parameters`. The significance level is 5%.

| Model | Chi-square | df | p-value | Decision |
|---|---:|---:|---:|---|
| Normal (positive-duration conditional) | 4867.35 | 3 | < 0.001 | Reject H0 |
| Exponential | 731.79 | 4 | < 0.001 | Reject H0 |
| Weibull | 1137.60 | 3 | < 0.001 | Reject H0 |

Thus, the chi-square test rejects all three as exact models at 5%. This is consistent with the strong 20-minute granularity and concentration at 20 minutes. Observed and expected counts are in `results/tables/03_chi_square_observed_expected.csv` and the supporting plot is `03b_chi_square_observed_expected.png`. No AIC, BIC, KS test, or non-syllabus model was used for a formal conclusion.

## 6. Reliability and Hazard Analysis — Module 7

Let D be outage duration. Here `S(t) = P(D > t)` is the probability that an outage remains unresolved beyond time t; it is not service uptime reliability. The Exponential resolution hazard is constant at 0.0292116 per minute. The Weibull hazard is `h(t) = (k/scale)(t/scale)^(k-1)`. Since k = 1.1842 > 1, its resolution hazard increases with elapsed outage time: among outages still unresolved, the instantaneous rate of resolution increases. This must not be interpreted as recovery becoming harder.

| t (minutes) | Empirical S(t) | Exponential | Weibull |
|---:|---:|---:|---:|
| 20 | 0.2997 | 0.5575 | 0.6163 |
| 60 | 0.0624 | 0.1733 | 0.1690 |
| 120 | 0.0212 | 0.0300 | 0.0176 |
| 480 | 0.0016 | 0.0000 | 0.0000 |

The survival and hazard plots are `results/plots/04a_survival_curves.png` and `04c_hazard_functions.png`. For maintainability, these results describe recovery duration after an outage starts; they can inform recovery-time discussion but do not estimate a repair process beyond the available event durations.

For a series system with independent components, `R_system = product(R_i)`. For independent redundant parallel components, `R_system = 1 - product(1 - R_i)`. The dataset has no component-level records, so these formulas are presented conceptually only.

## 7. Discussion, Limitations, and Conclusion

The data clearly show short, discretised outages with a long upper tail. The three course distributions are useful visual/reliability approximations, but the formal chi-square results do not support treating any as an exact fit. Normal is particularly unsuitable due to positivity and skewness. The dataset includes outage events, not complete uptime exposure or intervals between failures; therefore availability, uptime probability, and MTBF cannot be calculated. User reports, ties at 20-minute intervals, and a single service also limit generalisation.

## 8. Reproduction in R

From the project root, run scripts in order:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\01_inspect_data.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\02_clean_and_explore.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\03_distribution_fitting.R
& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" scripts\04_reliability_analysis.R
```

## 9. Viva Questions and Answers

1. **Why is the Normal model limited?** Durations are positive and extremely right-skewed, whereas a Normal model is symmetric and allows negative values.
2. **What does chi-square goodness-of-fit test?** It compares observed class frequencies with expected frequencies under a stated distribution.
3. **Why subtract parameters in the degrees of freedom?** Parameters estimated from the same data use information that would otherwise be free for comparison.
4. **What does S(60) mean?** It is the probability an outage lasts longer than 60 minutes.
5. **What does an increasing Weibull resolution hazard mean here?** Among outages still unresolved, the instantaneous rate of resolution increases with elapsed duration.
6. **Why is availability not reported?** Uptime/exposure and time-between-failure information are not available in this outage-duration dataset.

## References

1. atlarge-research. *cloud-uptime-archive*. https://github.com/atlarge-research/cloud-uptime-archive
2. VIT BMAT202L syllabus: Modules 1, 4, 6, and 7.
