# peyton_huber_coppock_2022/maintained/clean_summary_estimates.R
# Output: maintained/output/phc_summary_clean.rds, maintained/output/phc_summary_clean.csv,
#   maintained/output/appendix_study_estimates.csv,
#   maintained/output/appendix_table_cells.csv,
#   maintained/output/appendix_table_ratios.csv,
#   maintained/output/text_pooled_benchmarks.csv
# Depends on: original/appendix_section_a.R and the twelve study datasets it reads; helpers.R
# Description: Rebuilds the 138 summary effect sizes that Figures 2 and 3 compare. The
#   deposited appendix_section_a.R computes them in 3,010 lines, of which only the final
#   summarise is broken, so this script runs the deposited code up to that point and then
#   applies the fixed version rather than reimplementing 3,010 lines of study-by-study
#   estimation. Three substitutions are made to the sourced text, all listed below.
#
#   This script needs network access: the deposited code downloads the two ManyLabs 2
#   datasets from GitHub at runtime.

source(here::here("maintained", "helpers.R"))

# Sandbox for the deposited code ----
# appendix_section_a.R addresses its data files by bare relative path and writes five
# appendix .tex fragments and several PDFs beside them. Running it with original/ as the
# working directory would leave those artifacts inside the deposit, so instead it runs in
# a temporary directory of symlinks to the deposit: reads resolve, writes land in tempdir,
# and original/ stays byte-identical to what download_original.R verified.
sandbox <- file.path(tempdir(), "appendix_sandbox")
unlink(sandbox, recursive = TRUE)
dir.create(sandbox)
walk(
  list.files(data_dir, full.names = TRUE),
  \(f) file.symlink(f, file.path(sandbox, basename(f)))
)

# Substitutions applied to the sourced text ----
# rmeta::meta.summaries() becomes meta_summaries_fe(), the metafor::rma(method = "FE")
# equivalent defined in helpers.R. It is the same inverse-variance fixed-effect estimator
# from a package that is still maintained, and it is the only edit made to the text itself.
appendix_lines <- read_lines(file.path(data_dir, "appendix_section_a.R"))
appendix_lines <- str_replace_all(
  appendix_lines[1:2958],
  fixed("rmeta::meta.summaries("),
  "meta_summaries_fe("
)

# The prospective atomic aversion block pools the COVID-era weeks without restricting
# them to the unstandardized estimates, so the precision-weighted mean runs over each
# week twice, once on the percentage-point scale and once on Glass's delta scale. Its
# two neighbours in the same table (the original study and the ABP replication) and
# the whole retrospective block four hundred lines below are written the same way with
# the filter present, and the published appendix Table 2 is what the filtered version
# gives. The missing clause is restored here; it is the one analysis correction the
# rewrite makes and it moves twenty of that table's cells.
prospective_filter <- which(appendix_lines == '  filter(str_detect(survey, "Week")) %>% ')
stopifnot(length(prospective_filter) == 1)
appendix_lines[prospective_filter] <-
  '  filter(str_detect(survey, "Week"), estimate_type == "Unstandardized") %>% '

# position_dodgev() came from ggstance, which ggplot2 superseded once position_dodge
# learned to dodge along a discrete axis. lemon re-exported it when this archive was
# deposited and no longer does, so the deposited code needs the equivalent supplied here.
# It affects only the appendix figures drawn into the sandbox.
position_dodgev <- function(height = 0.75, ...) position_dodge(width = height)

# envir is passed explicitly so the objects the deposited code creates land in this
# script's environment rather than in a frame belonging to with_dir().
script_env <- environment()
withr::with_dir(
  sandbox,
  eval(parse(text = paste(appendix_lines, collapse = "\n")), envir = script_env)
)

# Individual study estimates ----
# Every estimate the thirteen appendix Section A figures plot, and every cell of the
# three appendix tables, comes from these thirteen per-study objects. The deposited
# code binds them together and then keeps only the standardized rows, which is right
# for the summary effect sizes and wrong for the appendix, whose atomic aversion
# figures and tables are on the percentage-point scale. They are bound here without
# that filter so the appendix has something to be compared against.
appendix_estimates <- bind_rows(
  `Hyman & Sheatsley (1950)`                     = est_study_1,
  `Tversky & Kaheneman (1981) - Cheap/Expensive` = est_study_2,
  `Tversky & Kaheneman (1981) - Gain/Loss`       = est_study_3,
  `Smith (1987)`                                 = est_study_4,
  `Druckman (2001)`                              = est_study_5,
  `Gilens (2001)`                                = est_study_6,
  `Knobe (2003)`                                 = est_study_7,
  `Press et al. (2013) - prospective`            = est_study_8a,
  `Press et al. (2013) - retrospective`          = est_study_8b,
  `Hainmueller & Hopkins (2015)`                 = est_study_9,
  `Porter et al. (2018)`                         = est_study_10,
  `Trump & White (2018)`                         = est_study_11,
  `Peyton (2020)`                                = est_study_12,
  .id = "study_group"
) |>
  ungroup() |>
  mutate(across(where(is.factor), as.character))

write_csv(appendix_estimates, file.path(out_dir, "appendix_study_estimates.csv"))

# Appendix tables ----
# The appendix prints three tables, captioned Table 1 in Section A.5 and Tables 2 and 3
# in Section A.8. The deposited code builds each as a pair of long frames, one of
# estimates and one of standard errors, and then formats them to two decimals. Both
# halves of each pair are joined and written unrounded here, so a published cell is
# compared against the number behind it rather than against a re-rounded reprint.
appendix_table_cells <- bind_rows(
  `Table 1` = full_join(combined_estimates, combined_ses,
                        by = c("AD_Z_party_sure_thing", "x_pid3", "survey")) |>
    transmute(row = paste(AD_Z_party_sure_thing, x_pid3, sep = " | "),
              column = survey, estimate, std.error),
  `Table 2` = full_join(combined_prospective_estimates, combined_prospective_ses,
                        by = c("Z_psv", "outcome_group", "survey")) |>
    transmute(row = paste(Z_psv, outcome_group, sep = " | "),
              column = survey, estimate, std.error),
  `Table 3` = full_join(combined_retrospective_estimates, combined_retrospective_ses,
                        by = c("outcome_group", "survey")) |>
    transmute(row = outcome_group, column = survey, estimate, std.error),
  .id = "appendix_table"
) |>
  mutate(p.value = 2 * (1 - pnorm(abs(estimate / std.error)))) |>
  arrange(appendix_table, row, column)

write_csv(appendix_table_cells, file.path(out_dir, "appendix_table_cells.csv"))

appendix_table_ratios <- bind_rows(
  `Table 1` = combined_estimates |>
    distinct(AD_Z_party_sure_thing, x_pid3, Ratio) |>
    transmute(row = paste(AD_Z_party_sure_thing, x_pid3, sep = " | "),
              column = "Ratio", ratio = Ratio),
  `Table 2` = combined_prospective_estimates |>
    distinct(Z_psv, outcome_group, psv_ratio, abp_ratio) |>
    pivot_longer(c(psv_ratio, abp_ratio), names_to = "column", values_to = "ratio") |>
    transmute(row = paste(Z_psv, outcome_group, sep = " | "), column, ratio),
  `Table 3` = combined_retrospective_estimates |>
    distinct(outcome_group, psv_ratio, abp_ratio) |>
    pivot_longer(c(psv_ratio, abp_ratio), names_to = "column", values_to = "ratio") |>
    transmute(row = outcome_group, column, ratio),
  .id = "appendix_table"
) |>
  arrange(appendix_table, row, column)

write_csv(appendix_table_ratios, file.path(out_dir, "appendix_table_ratios.csv"))

# Summary effect sizes ----
# The deposited script ends with study_group = paste(study_group) inside a group where
# study_group varies. paste() silently collapses the values into one space-separated
# string, which dplyr 1.1+ rejects. first(study_group) is what the surrounding code
# assumes and is the only change made here.
summary_dat <- combined_dat |>
  ungroup() |>
  mutate(
    estimate = case_when(
      str_detect(outcome, "psv_retrospective") ~ -1 * estimate,
      str_detect(study_group, "Hainmueller|Trump") ~ if_else(estimate < 0, estimate * (-1), estimate),
      TRUE ~ estimate
    ),
    conf.low = case_when(
      str_detect(outcome, "psv_retrospective") ~ -1 * conf.high,
      str_detect(study_group, "Hainmueller|Trump") ~ if_else(estimate < 0, conf.high * (-1), conf.low),
      TRUE ~ conf.low
    ),
    conf.high = case_when(
      str_detect(outcome, "psv_retrospective") ~ -1 * conf.low,
      str_detect(study_group, "Hainmueller|Trump") ~ if_else(estimate < 0, conf.low * (-1), conf.high),
      TRUE ~ conf.high
    )
  ) |>
  group_by(study_group_detail, study) |>
  summarise(
    estimate    = weighted.mean(estimate, w = 1 / (std.error) ^ 2),
    std.error   = sqrt(1 / sum(1 / (std.error) ^ 2)),
    study_group = first(study_group),
    .groups     = "drop"
  ) |>
  mutate(
    conf.low  = estimate - 1.96 * std.error,
    conf.high = estimate + 1.96 * std.error,
    statistic = estimate / std.error,
    p.value   = 2 * (1 - pnorm(abs(statistic))),
    study     = if_else(study == "Replication", "YCLS summary", "Pre-COVID summary")
  ) |>
  distinct()

write_rds(summary_dat, file.path(out_dir, "phc_summary_clean.rds"))
write_csv(summary_dat, file.path(out_dir, "phc_summary_clean.csv"))

# Pooled benchmarks ----
# The fifteen pooled quantities the sourced code computes are the only places the
# fixed-effect substitution bites, so they are written out. The published article uses the
# fixed-effect column. The random-effects column is an addition, not a correction: it is
# what metafor gives for free once the same data are in hand, and it shows how much of the
# apparent precision of each benchmark rests on assuming the pooled studies share one true
# effect. tau2 is the REML estimate of between-study variance and i2 the share of total
# variance attributable to it.
benchmark_fits <- tribble(
  ~benchmark,                                    ~fit,
  "Russian reporters, pre-COVID",                russians_benchmark$fit,
  "Question framing, pre-COVID",                 framing_benchmark$fit,
  "Question framing, COVID era",                 framing_ycls$fit,
  "Asian disease, pre-COVID",                    disease_benchmark$fit,
  "Asian disease, COVID era",                    disease_ycls$fit,
  "Welfare spending, COVID-era web interviews",  ycls_cawi$fit,
  "Welfare spending, GSS in-person",             gss_capi$fit,
  "Welfare spending, GSS paper and pencil",      gss_papi$fit,
  "Welfare spending, COVID-era experimental",    ycls_exp$fit,
  "Welfare spending, Huber benchmark",           huber_benchmark$fit,
  "Welfare spending, Huber and GSS 1986",        ycls_benchmark$fit,
  "Welfare spending, COVID-era observational",   ycls_obs$fit,
  "Issue framing, pre-COVID",                    druckman_benchmark$fit,
  "Issue framing, COVID era",                    druckman_ycls$fit,
  "Intentional side effects, pre-COVID",         knobe_benchmark$fit
)

pooled_benchmarks <- benchmark_fits |>
  mutate(
    reml = map(fit, \(f) metafor::rma(yi = f$yi, vi = f$vi, method = "REML")),
    k        = map_int(fit, \(f) f$k),
    fe_est   = map_dbl(fit, \(f) unname(f$beta[1, 1])),
    fe_se    = map_dbl(fit, \(f) f$se),
    reml_est = map_dbl(reml, \(f) unname(f$beta[1, 1])),
    reml_se  = map_dbl(reml, \(f) f$se),
    tau2     = map_dbl(reml, \(f) f$tau2),
    i2       = map_dbl(reml, \(f) f$I2),
    q_stat   = map_dbl(fit, \(f) f$QE),
    q_p      = map_dbl(fit, \(f) f$QEp)
  ) |>
  select(benchmark, k, fe_est, fe_se, reml_est, reml_se, tau2, i2, q_stat, q_p)

write_csv(pooled_benchmarks, file.path(out_dir, "text_pooled_benchmarks.csv"))

# Checks ----
check_clean <- tibble(
  check = c("Summary effect size rows", "Study-outcome groups", "Pooled benchmarks",
            "Individual study estimates"),
  value = c(nrow(summary_dat), n_distinct(summary_dat$study_group_detail),
            nrow(pooled_benchmarks), nrow(appendix_estimates))
)

print(check_clean)
print(pooled_benchmarks, n = nrow(pooled_benchmarks))
