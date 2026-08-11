# peyton_huber_coppock_2022/ground_truth/build_ground_truth.R
# Output: ground_truth/peyton_huber_coppock_2022_ground_truth.csv,
#   ground_truth/float_coverage.csv
# Depends on: maintained/output/ (run run_all.R first), maintained/in_text_claims.R,
#   ground_truth/published_claims.csv, ground_truth/archive_values.csv
# Description: Assemble the comparison table, then run the coverage gate over the second
#   instrument. value_paper is the number the article, its online appendix or the 2023
#   corrigendum prints, carried as the string that page carries, and it comes only from
#   those documents: the prose values are transcribed into published_claims.csv and the
#   146 float cells are transcribed below from the typeset pages. value_script is read out
#   of ground_truth/archive_values.csv, which extract_archive_values.R writes by running
#   the deposited code. value_rewrite is read out of maintained/output/. No published
#   number is an input to any computation here or in maintained/.

library(here)
library(tidyverse)

here::i_am("ground_truth/build_ground_truth.R")

options(width = 200)

paper_id <- "peyton_huber_coppock_2022"

out <- function(f) read_csv(here::here("maintained", "output", f), show_col_types = FALSE)

# The extraction -------------------------------------------------------------------
# published_claims.csv is the exhaustive numeric-token extraction from the article, the
# online appendix and the corrigendum. It governs coverage for both instruments and is
# the single home of the per-claim precision, so neither file can name a different one.

published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(value_paper = col_character(), .default = col_guess())
)

# Rendering and comparison ----------------------------------------------------------

normalise_printed <- function(x) {
  x |>
    str_replace_all("−", "-") |>
    str_remove_all(",") |>
    str_replace("^(-?)\\.", "\\10")
}

render_at <- function(x, digits) {
  rendered <- sprintf(paste0("%.", digits, "f"), x)
  str_replace(rendered, "^-(0(\\.0+)?)$", "\\1")
}

agrees <- function(value, value_paper, digits) {
  target <- suppressWarnings(as.numeric(normalise_printed(value_paper)))
  d <- if_else(is.na(digits), 0L, as.integer(digits))
  case_when(
    is.na(value) | is.na(target) | is.na(digits) ~ NA_real_,
    render_at(value, d) == normalise_printed(value_paper) ~ 1,
    abs(round(value, d) - target) < 1e-9 * pmax(1, abs(target)) ~ 1,
    .default = 0
  )
}

# Checks that depend only on the extraction ----------------------------------------
# These run before anything consumes it, so a wrong precision trips its own check rather
# than the value comparison downstream.

stopifnot(
  !any(duplicated(published_claims$claim_id)),
  all(nzchar(published_claims$claim_id)),
  all(published_claims$claim_type %in%
        c("pipeline", "descriptive", "definitional", "structural", "transcribed")),
  all(published_claims$needs_block %in% c(TRUE, FALSE)),
  all(is.na(published_claims$comparison) |
        published_claims$comparison %in% c("==", "<", ">", "<=", ">=", "approx")),
  all(published_claims$needs_block[
    published_claims$claim_type %in% c("pipeline", "descriptive")])
)

# A stored value_paper that does not survive a round trip through its own recorded
# precision means digits is wrong about the precision even where it is right about the
# value, which numeric equality would pass.
round_trips <- function(value_paper, digits) {
  numeric_rows <- !is.na(value_paper) & !is.na(digits) &
    str_detect(value_paper, "^-?\\d+(\\.\\d+)?$")
  bad <- numeric_rows &
    (value_paper != normalise_printed(value_paper) |
       render_at(suppressWarnings(as.numeric(value_paper)), digits) != value_paper)
  if (any(bad, na.rm = TRUE)) {
    print(tibble(value_paper = value_paper[which(bad)], digits = digits[which(bad)]))
    stop("A transcribed value does not survive a round trip through its own precision.")
  }
  invisible(NULL)
}

round_trips(published_claims$value_paper, published_claims$digits)

prose_digits <- function(id) {
  d <- published_claims$digits[match(id, published_claims$claim_id)]
  stopifnot(!any(is.na(d)))
  d
}

# The rewrite ----------------------------------------------------------------------

correspondence <- out("text_correspondence_summary.csv")
device <- out("text_device_metadata.csv")
by_year <- out("text_device_by_year.csv")
all_surveys <- out("text_device_all_surveys.csv")
benchmarks <- out("text_pooled_benchmarks.csv")
summary_dat <- out("phc_summary_clean.csv")
appendix_estimates <- out("appendix_study_estimates.csv")
appendix_cells_rewrite <- out("appendix_table_cells.csv")
appendix_ratios_rewrite <- out("appendix_table_ratios.csv")
table_2_rewrite <- out("table_2_acq_pass_rates_cells.csv")
figure_1_rewrite <- out("figure_1_lucid_weekly_completes.csv")
figure_2_rewrite <- out("figure_2_noncojoint_correspondence.csv")
figure_3_rewrite <- out("figure_3_conjoint_correspondence.csv")
figure_4_rewrite <- out("figure_4_meta_trends.csv")
figure_5_rewrite <- out("figure_5_trust_replication.csv")

corr <- function(name) correspondence$value[correspondence$quantity == name]
dev_value <- function(name) device$value[device$quantity == name]
bench <- function(name, column) benchmarks[[column]][benchmarks$benchmark == name]

# The deposit's own answer ------------------------------------------------------------

archive_values <- read_csv(here::here("ground_truth", "archive_values.csv"),
                           show_col_types = FALSE)
stopifnot(!any(duplicated(archive_values$label)))
script <- function(label) {
  value <- archive_values$value[archive_values$label == label]
  if (length(value) == 0) NA_real_ else value
}

# Prose rows --------------------------------------------------------------------------
# One row per extraction claim that has a value on both sides, plus the descriptive rows
# whose verdict comes from the second instrument's own computation rather than from a
# number. The rewrite value is computed here by a route of its own; the claims file
# reaches the same quantities from the study-level estimates instead.

f2 <- figure_2_rewrite
f3 <- figure_3_rewrite
both <- bind_rows(f2, f3)
f5 <- function(name, column) figure_5_rewrite[[column]][figure_5_rewrite$dataset == name]
completes_2019 <- sum(figure_1_rewrite$completes[year(figure_1_rewrite$date) == 2019])
completes_2020 <- sum(figure_1_rewrite$completes[year(figure_1_rewrite$date) == 2020])
year_share <- function(panel_name, yr) {
  by_year$mean_share[by_year$panel == panel_name & by_year$year == yr]
}
ae <- appendix_estimates |>
  mutate(study_base = str_replace(study_group, "^Press et al\\. \\(2013\\).*",
                                  "Press et al. (2013)"),
         variant = coalesce(framing_Z_type, knobe_Z_type, type))

by_survey <- out("text_device_by_survey.csv")

# Counts the article states in prose, computed from the study-level estimates rather
# than typed. The claims file reaches the same numbers through its own filters.
summarised <- ae |>
  filter(estimate_type == "Standardized" | is.na(estimate_type)) |>
  filter(!(study_base == "Smith (1987)" &
             (type != "Experimental" | survey %in% paste("GSS", 1987:2018))))
replication_count <- ae |>
  filter(study == "Replication") |>
  distinct(study_base, survey, variant) |>
  nrow()
study_count <- n_distinct(ae$study_base)
precovid_sources <- ae |>
  filter(study == "Pre-COVID") |>
  summarise(sources = n_distinct(survey), .by = study_base)
conjoint_ae <- ae |> filter(study_base == "Hainmueller & Hopkins (2015)")
conjoint_wide <- conjoint_ae |>
  select(level, study, estimate) |>
  pivot_wider(names_from = study, values_from = estimate)
psv_terms <- unique(ae$term[str_detect(coalesce(ae$term, ""), "^90/")])
week_n <- function(w) by_survey$n[by_survey$week == w]
week_month <- function(w) month(all_surveys$time[all_surveys$n == week_n(w)])

# The three pairwise comparisons the appendix reports between two of its own arms.
one_row <- function(d) { stopifnot(nrow(d) == 1); d }
fr_direct <- one_row(ae |> filter(study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive",
                                  estimate_type == "Unstandardized",
                                  framing_Z_type == "Original", study == "Replication"))
fr_covid <- one_row(ae |> filter(study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive",
                                 estimate_type == "Unstandardized", framing_Z_type == "Modified"))
fr_ml <- one_row(ae |> filter(study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive",
                              estimate_type == "Unstandardized", survey == "Many Labs (2018)"))
kn_direct <- one_row(ae |> filter(study_base == "Knobe (2003)", estimate_type == "Unstandardized",
                                  knobe_Z_type == "Original", study == "Replication"))
kn_covid <- one_row(ae |> filter(study_base == "Knobe (2003)", estimate_type == "Unstandardized",
                                 knobe_Z_type == "Modified"))
kn_ml <- one_row(ae |> filter(study_base == "Knobe (2003)", estimate_type == "Unstandardized",
                              survey == "Many Labs (2018)"))
gilens_pre <- one_row(ae |> filter(study_base == "Gilens (2001)", study == "Pre-COVID"))
gilens_rep <- one_row(ae |> filter(study_base == "Gilens (2001)", study == "Replication"))
diff_of <- function(a, b, part) {
  d <- a$estimate - b$estimate
  se <- sqrt(a$std.error ^ 2 + b$std.error ^ 2)
  switch(part, diff = d, se = se, p = 2 * (1 - pnorm(abs(d / se))))
}
knobe_pre_pool <- weighted.mean(c(kn_ml$estimate, ae$estimate[ae$study_base == "Knobe (2003)" &
                                    ae$estimate_type == "Unstandardized" &
                                    ae$survey == "Knobe (2003)"]),
                                w = 1 / c(kn_ml$std.error, ae$std.error[ae$study_base == "Knobe (2003)" &
                                    ae$estimate_type == "Unstandardized" &
                                    ae$survey == "Knobe (2003)"]) ^ 2)

ae_cell <- function(group, survey_name, outcome, kind = "estimate", type_name = NA,
                    term_name = NA) {
  rows <- ae |> filter(study_base == group, survey == survey_name)
  if (!is.na(outcome)) rows <- rows |> filter(outcome_group == outcome)
  if (!is.na(type_name)) rows <- rows |> filter(estimate_type == type_name)
  if (!is.na(term_name)) rows <- rows |> filter(term == term_name)
  stopifnot(nrow(rows) == 1)
  rows[[kind]]
}
russians <- f2 |> filter(study_group_detail == "Russian reporters")

prose <- tribble(
  ~claim_id,                                   ~value_rewrite,                        ~value_script,
  "abstract_replications",                     replication_count,                                    NA_real_,
  "abstract_designs",                          study_count,                                    NA_real_,
  "abstract_samples",                          dev_value("surveys"),                  NA_real_,
  "abstract_field_month_first",                dev_value("field_period_month_first"), NA_real_,
  "abstract_field_month_last",                 dev_value("field_period_month_last"),  NA_real_,
  "abstract_field_year",                       dev_value("field_period_year_first"),  NA_real_,
  "intro_replications",                        replication_count,                                    NA_real_,
  "intro_designs",                             study_count,                                    NA_real_,
  "intro_correspondence",                      100 * corr("avg_pct_precovid_overall"),
                                               100 * script("correspondence_overall"),
  "figure_1_completes_2019",                   completes_2019,                        NA_real_,
  "figure_1_completes_2020",                   completes_2020,                        NA_real_,
  "background_academic_growth",                100 * (completes_2020 / completes_2019 - 1), NA_real_,
  "design_weekly_sample",                      dev_value("respondents") / dev_value("surveys"), NA_real_,
  "design_median_duration",                    dev_value("duration_median_minutes"),  NA_real_,
  "design_replications",                       replication_count,                                    NA_real_,
  "design_studies",                            study_count,                                    NA_real_,
  "results_studies",                           study_count,                                    NA_real_,
  "results_studies_with_precovid_replication", sum(precovid_sources$sources > 1),                                     NA_real_,
  "results_precovid_estimates",                sum(summarised$study == "Pre-COVID"),                                    NA_real_,
  "results_replication_estimates",             sum(summarised$study == "Replication"),                                   NA_real_,
  "footnote_3_gss_administrations",            n_distinct(ae$survey[ae$study == "Pre-COVID" & str_starts(coalesce(ae$survey, ""), "GSS")]),                                    NA_real_,
  "footnote_3_all_precovid_estimates",         sum(ae$study == "Pre-COVID" & (ae$estimate_type == "Standardized" | is.na(ae$estimate_type))),                                   NA_real_,
  "footnote_3_huber_replications",             bench("Welfare spending, Huber benchmark", "k"), NA_real_,
  "results_summary_estimates",                 nrow(summary_dat),                     script("summary_estimates_total"),
  "results_summary_conjoint",                  sum(summary_dat$study_group == "Hainmueller & Hopkins (2015)"),
                                               script("summary_estimates_conjoint"),
  "results_summary_nonconjoint",               sum(summary_dat$study_group != "Hainmueller & Hopkins (2015)"),
                                               script("summary_estimates_nonconjoint"),
  "results_fig2_pairs",                        corr("nonconjoint_pairs"),             script("pairs_nonconjoint"),
  "results_correctly_signed_nonconjoint",      corr("nonconjoint_correctly_signed"),  script("nonconjoint_correctly_signed"),
  "results_sig_smaller_of_24",                 corr("nonconjoint_sig_smaller_correctly_signed"),
                                               script("nonconjoint_sig_smaller_correctly_signed"),
  "results_incorrectly_signed",                sum(f2$sign_diff),                     script("nonconjoint_incorrectly_signed"),
  "results_sig_among_incorrect",               corr("nonconjoint_sig_among_incorrectly_signed"),
                                               script("nonconjoint_sig_among_incorrectly_signed"),
  "results_atomic_sig_count",                  sum(str_detect(f2$study_group, "Press") & f2$sign_diff & f2$p_diff < 0.05), NA_real_,
  "results_atomic_estimate_count",             sum(str_detect(f2$study_group, "Press")), NA_real_,
  "results_conjoint_pairs",                    corr("conjoint_pairs"),                script("pairs_conjoint"),
  "results_conjoint_smaller",                  corr("conjoint_smaller"),              script("conjoint_smaller"),
  "results_conjoint_sig_among_smaller",        corr("conjoint_sig_among_smaller"),    script("conjoint_sig_among_smaller"),
  "results_conjoint_larger",                   corr("conjoint_larger"),               script("conjoint_larger"),
  "results_conjoint_sig_among_larger",         corr("conjoint_sig_among_larger"),     script("conjoint_sig_among_larger"),
  "results_pooled_correctly_signed",           corr("correctly_signed_total"),        script("pairs_correctly_signed"),
  "results_pooled_pairs",                      corr("total_pairs"),                   script("pairs_total"),
  "results_correspondence_overall",            100 * corr("avg_pct_precovid_overall"), 100 * script("correspondence_overall"),
  "results_correspondence_conjoint",           100 * corr("avg_pct_precovid_conjoint"), 100 * script("correspondence_conjoint"),
  "results_correspondence_nonconjoint",        100 * corr("avg_pct_precovid_nonconjoint"), 100 * script("correspondence_nonconjoint"),
  "figure_2_caption_pairs",                    nrow(f2),                              script("pairs_nonconjoint"),
  "figure_2_caption_studies",                  n_distinct(f2$study_group),            NA_real_,
  "figure_2_sig_count",                        corr("nonconjoint_sig_unadjusted"),    script("nonconjoint_sig_unadjusted"),
  "figure_3_caption_pairs",                    nrow(f3),                              script("pairs_conjoint"),
  "figure_3_sig_count",                        corr("conjoint_sig_unadjusted"),       script("conjoint_sig_unadjusted"),
  "device_surveys",                            dev_value("surveys"),                  NA_real_,
  "device_webapp_min",                         dev_value("webapp_share_min"),         NA_real_,
  "device_webapp_max",                         dev_value("webapp_share_max"),         NA_real_,
  "device_mobile_min",                         dev_value("mobile_share_min"),         NA_real_,
  "device_mobile_max",                         dev_value("mobile_share_max"),         NA_real_,
  "device_additional_sample",                  dev_value("respondents_outside_replication_surveys"), NA_real_,
  "device_2020_webapp",                        100 * year_share("Respondents from web applications", 2020), NA_real_,
  "device_2020_mobile",                        100 * year_share("Respondents from mobile phones", 2020), NA_real_,
  "device_2019_webapp",                        100 * year_share("Respondents from web applications", 2019), NA_real_,
  "device_2019_mobile",                        100 * year_share("Respondents from mobile phones", 2019), NA_real_,
  "device_2018_webapp",                        100 * year_share("Respondents from web applications", 2018), NA_real_,
  "device_2018_mobile",                        100 * year_share("Respondents from mobile phones", 2018), NA_real_,
  "device_overlap_mobile_given_webapp",        100 * dev_value("mobile_share_among_webapp"), NA_real_,
  "device_overlap_webapp_given_mobile",        100 * dev_value("webapp_share_among_mobile"), NA_real_,
  "device_duration_gap_webapp",                dev_value("duration_mean_browser") - dev_value("duration_mean_webapp"), NA_real_,
  "device_duration_browser",                   dev_value("duration_mean_browser"),    NA_real_,
  "device_duration_gap_mobile",                dev_value("duration_mean_nonmobile") - dev_value("duration_mean_mobile"), NA_real_,
  "device_acq_surveys",                        dev_value("surveys_with_acq"),         NA_real_,
  "table_2_note_original_pass",                100 * dev_value("acq_pass_rate_peyton_original"), NA_real_,
  "figure_5_acq_pass_estimate",                f5("Attentive: Passed ACQ", "estimate"), script("figure_5_attentive_passed_acq_estimate"),
  "figure_5_acq_pass_se",                      f5("Attentive: Passed ACQ", "std.error"), script("figure_5_attentive_passed_acq_se"),
  "figure_5_browser_estimate",                 f5("Attentive: Internet browser", "estimate"), script("figure_5_attentive_internet_browser_estimate"),
  "figure_5_browser_se",                       f5("Attentive: Internet browser", "std.error"), script("figure_5_attentive_internet_browser_se"),
  "figure_5_nonmobile_estimate",               f5("Attentive: Non-mobile device", "estimate"), script("figure_5_attentive_non_mobile_device_estimate"),
  "figure_5_nonmobile_se",                     f5("Attentive: Non-mobile device", "std.error"), script("figure_5_attentive_non_mobile_device_se"),
  "figure_5_acq_fail_estimate",                f5("Inattentive: Failed ACQ", "estimate"), script("figure_5_inattentive_failed_acq_estimate"),
  "figure_5_acq_fail_se",                      f5("Inattentive: Failed ACQ", "std.error"), script("figure_5_inattentive_failed_acq_se"),
  "figure_5_webapp_estimate",                  f5("Inattentive: Web-Application", "estimate"), script("figure_5_inattentive_web_application_estimate"),
  "figure_5_webapp_se",                        f5("Inattentive: Web-Application", "std.error"), script("figure_5_inattentive_web_application_se"),
  "figure_5_mobile_estimate",                  f5("Inattentive: Mobile device", "estimate"), script("figure_5_inattentive_mobile_device_estimate"),
  "figure_5_mobile_se",                        f5("Inattentive: Mobile device", "std.error"), script("figure_5_inattentive_mobile_device_se"),
  "inattention_correspondence",                100 * corr("avg_pct_precovid_overall"), 100 * script("correspondence_overall"),
  "inattention_attentive_share",               100 * corr("avg_pct_precovid_overall"), 100 * script("correspondence_overall"),
  "inattention_inattentive_share",             100 * (1 - corr("avg_pct_precovid_overall")), 100 * (1 - script("correspondence_overall")),
  "inattention_inflated_correspondence",       100 * corr("inflated_aronow_overall"), 100 * script("correspondence_inflated"),
  "figure_5_note_field_month",                 week_month("YCLS Week 9"),                                     NA_real_,
  "figure_5_note_corr_nonmobile_browser",      dev_value("correlation_nonmobile_browser"), NA_real_,
  "figure_5_note_corr_nonmobile_acq",          dev_value("correlation_nonmobile_acq"), NA_real_,
  "figure_5_note_corr_browser_acq",            dev_value("correlation_browser_acq"),  NA_real_,
  "figure_5_note_original_pass",               100 * dev_value("acq_pass_rate_peyton_original"), NA_real_,
  "figure_5_note_replication_pass",            100 * dev_value("acq_pass_rate_week_9"), NA_real_,
  "discussion_replications",                   replication_count,                                    NA_real_,
  "discussion_studies",                        study_count,                                    NA_real_,
  "a1_precovid_summary",                       100 * russians$estimate_pre,           100 * script("summary_russian_reporters_pre_estimate"),
  "a1_replication_estimate",                   100 * russians$estimate_ycls,          100 * script("summary_russian_reporters_ycls_estimate"),
  "a1_relative",                               100 * russians$estimate_ycls / russians$estimate_pre, NA_real_,
  "a1_difference",                             -100 * russians$estimate_diff,         NA_real_,
  "a1_difference_p",                           russians$p_diff,                       NA_real_,
  "a2_direct_effect",                          100 * ae$estimate[ae$study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive" & ae$estimate_type == "Unstandardized" & ae$framing_Z_type == "Original" & ae$study == "Replication"], NA_real_,
  "a2_precovid_effect",                        100 * ae_cell("Tversky & Kaheneman (1981) - Cheap/Expensive", "Many Labs (2018)", NA, "estimate", "Unstandardized", NA), NA_real_,
  "a2_covid_effect",                           100 * ae$estimate[ae$study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive" & ae$estimate_type == "Unstandardized" & ae$framing_Z_type == "Modified"], NA_real_,
  "a2_summary_pre",                            bench("Question framing, pre-COVID", "fe_est"), script("benchmark_framing_pre_estimate"),
  "a2_summary_pre_se",                         bench("Question framing, pre-COVID", "fe_se"), script("benchmark_framing_pre_se"),
  "a2_summary_covid",                          bench("Question framing, COVID era", "fe_est"), script("benchmark_framing_covid_estimate"),
  "a2_summary_covid_se",                       bench("Question framing, COVID era", "fe_se"), script("benchmark_framing_covid_se"),
  "a2_covid_vs_precovid_diff",                 100 * diff_of(fr_ml, fr_covid, "diff"), NA_real_,
  "a2_covid_vs_precovid_se",                   diff_of(fr_ml, fr_covid, "se"), NA_real_,
  "a2_covid_vs_precovid_p",                    diff_of(fr_ml, fr_covid, "p"), NA_real_,
  "a2_covid_vs_direct_diff",                   100 * diff_of(fr_direct, fr_covid, "diff"), NA_real_,
  "a2_covid_vs_direct_se",                     diff_of(fr_direct, fr_covid, "se"), NA_real_,
  "a2_covid_vs_direct_p",                      diff_of(fr_direct, fr_covid, "p"), NA_real_,
  "a6_difference",                             diff_of(gilens_pre, gilens_rep, "diff"), NA_real_,
  "a6_difference_se",                          diff_of(gilens_pre, gilens_rep, "se"), NA_real_,
  "a7_direct_effect",                          kn_direct$estimate, NA_real_,
  "a7_direct_se",                              kn_direct$std.error, NA_real_,
  "a7_covid_effect",                           kn_covid$estimate, NA_real_,
  "a7_covid_se",                               kn_covid$std.error, NA_real_,
  "a7_covid_vs_direct_diff",                   diff_of(kn_direct, kn_covid, "diff"), NA_real_,
  "a7_covid_vs_direct_se",                     diff_of(kn_direct, kn_covid, "se"), NA_real_,
  "a7_covid_vs_direct_p",                      diff_of(kn_direct, kn_covid, "p"), NA_real_,
  "a7_relative_precovid",                      100 * kn_direct$estimate / knobe_pre_pool, NA_real_,
  "a7_difference_precovid",                    diff_of(kn_ml, kn_direct, "diff"), NA_real_,
  "a7_difference_precovid_se",                 diff_of(kn_ml, kn_direct, "se"), NA_real_,
  "a9_male_effect",                            -100 * conjoint_wide$Replication[conjoint_wide$level == "Male"], NA_real_,
  "a2_correspondence",                         100 * bench("Question framing, COVID era", "fe_est") / bench("Question framing, pre-COVID", "fe_est"), NA_real_,
  "a3_replications",                           bench("Asian disease, COVID era", "k"), NA_real_,
  "a3_precovid_studies",                       bench("Asian disease, pre-COVID", "k"), NA_real_,
  "a3_covid_summary",                          bench("Asian disease, COVID era", "fe_est"), script("benchmark_disease_covid_estimate"),
  "a3_covid_se",                               bench("Asian disease, COVID era", "fe_se"), script("benchmark_disease_covid_se"),
  "a3_relative",                               100 * bench("Asian disease, COVID era", "fe_est") / bench("Asian disease, pre-COVID", "fe_est"), NA_real_,
  "a3_pre_summary",                            bench("Asian disease, pre-COVID", "fe_est"), script("benchmark_disease_pre_estimate"),
  "a3_pre_se",                                 bench("Asian disease, pre-COVID", "fe_se"), script("benchmark_disease_pre_se"),
  "a3_difference",                             bench("Asian disease, pre-COVID", "fe_est") - bench("Asian disease, COVID era", "fe_est"), NA_real_,
  "a3_difference_se",                          sqrt(bench("Asian disease, pre-COVID", "fe_se") ^ 2 + bench("Asian disease, COVID era", "fe_se") ^ 2), NA_real_,
  "a4_cawi_summary",                           bench("Welfare spending, COVID-era web interviews", "fe_est"), script("benchmark_welfare_cawi_estimate"),
  "a4_cawi_se",                                bench("Welfare spending, COVID-era web interviews", "fe_se"), script("benchmark_welfare_cawi_se"),
  "a4_cawi_relative",                          100 * bench("Welfare spending, COVID-era web interviews", "fe_est") / bench("Welfare spending, GSS in-person", "fe_est"), NA_real_,
  "a4_capi_summary",                           bench("Welfare spending, GSS in-person", "fe_est"), script("benchmark_welfare_capi_estimate"),
  "a4_capi_se",                                bench("Welfare spending, GSS in-person", "fe_se"), script("benchmark_welfare_capi_se"),
  "a4_papi_summary",                           bench("Welfare spending, GSS paper and pencil", "fe_est"), script("benchmark_welfare_papi_estimate"),
  "a4_papi_se",                                bench("Welfare spending, GSS paper and pencil", "fe_se"), script("benchmark_welfare_papi_se"),
  "a4_experimental_summary",                   bench("Welfare spending, COVID-era experimental", "fe_est"), script("benchmark_welfare_experimental_estimate"),
  "a4_experimental_se",                        bench("Welfare spending, COVID-era experimental", "fe_se"), script("benchmark_welfare_experimental_se"),
  "a4_huber_summary",                          bench("Welfare spending, Huber benchmark", "fe_est"), script("benchmark_welfare_huber_estimate"),
  "a4_huber_se",                               bench("Welfare spending, Huber benchmark", "fe_se"), script("benchmark_welfare_huber_se"),
  "a4_benchmark_summary",                      bench("Welfare spending, Huber and GSS 1986", "fe_est"), script("benchmark_welfare_1986_estimate"),
  "a4_benchmark_se",                           bench("Welfare spending, Huber and GSS 1986", "fe_se"), script("benchmark_welfare_1986_se"),
  "a4_benchmark_relative",                     100 * bench("Welfare spending, COVID-era experimental", "fe_est") / bench("Welfare spending, Huber and GSS 1986", "fe_est"), NA_real_,
  "a4_footnote_3_cawi_q",                      bench("Welfare spending, COVID-era web interviews", "q_stat"), NA_real_,
  "a4_footnote_3_cawi_p",                      bench("Welfare spending, COVID-era web interviews", "q_p"), NA_real_,
  "a4_footnote_3_capi_q",                      bench("Welfare spending, GSS in-person", "q_stat"), NA_real_,
  "a4_footnote_3_capi_p",                      bench("Welfare spending, GSS in-person", "q_p"), NA_real_,
  "a4_footnote_3_papi_q",                      bench("Welfare spending, GSS paper and pencil", "q_stat"), NA_real_,
  "a6_original_estimate",                      ae_cell("Gilens (2001)", "Gilens (2001)", NA, "estimate", "Standardized", NA), NA_real_,
  "a6_original_se",                            ae_cell("Gilens (2001)", "Gilens (2001)", NA, "std.error", "Standardized", NA), NA_real_,
  "a6_replication_estimate",                   -ae_cell("Gilens (2001)", "Week 3", NA, "estimate", "Standardized", NA), NA_real_,
  "a6_replication_se",                         ae_cell("Gilens (2001)", "Week 3", NA, "std.error", "Standardized", NA), NA_real_,
  "a6_replication_p",                          ae_cell("Gilens (2001)", "Week 3", NA, "p.value", "Standardized", NA), NA_real_,
  "a7_ml_effect",                              100 * ae_cell("Knobe (2003)", "Many Labs (2018)", NA, "estimate", "Unstandardized", NA), NA_real_,
  "a8_9090_success",                           unique(as.numeric(str_extract(psv_terms, "^\\d+"))),                                    NA_real_,
  "a8_9070_success",                           as.numeric(str_extract(psv_terms[psv_terms == "90/70"], "\\d+$")),                                    NA_real_,
  "a8_9045_success",                           as.numeric(str_extract(psv_terms[psv_terms == "90/45"], "\\d+$")),                                    NA_real_,
  "a8_original_9070_prefer",                   100 * script("appendix_table_2_90_70_prefer_nuclear_use_press_et_al_2013__estimate"), 100 * script("appendix_table_2_90_70_prefer_nuclear_use_press_et_al_2013__estimate"),
  "a8_original_9045_prefer",                   100 * script("appendix_table_2_90_45_prefer_nuclear_use_press_et_al_2013__estimate"), 100 * script("appendix_table_2_90_45_prefer_nuclear_use_press_et_al_2013__estimate"),
  "a8_original_9070_approve",                  100 * script("appendix_table_2_90_70_approve_nuclear_use_press_et_al_2013__estimate"), 100 * script("appendix_table_2_90_70_approve_nuclear_use_press_et_al_2013__estimate"),
  "a8_original_9045_approve",                  100 * script("appendix_table_2_90_45_approve_nuclear_use_press_et_al_2013__estimate"), 100 * script("appendix_table_2_90_45_approve_nuclear_use_press_et_al_2013__estimate"),
  "a8_abp_retrospective_approve",              -100 * script("appendix_table_3_approve_strike_aronow_et_al_2019__estimate"), -100 * script("appendix_table_3_approve_strike_aronow_et_al_2019__estimate"),
  "a8_abp_retrospective_ethical",              -100 * script("appendix_table_3_ethical_strike_aronow_et_al_2019__estimate"), -100 * script("appendix_table_3_ethical_strike_aronow_et_al_2019__estimate"),
  "a9_country_levels",                         n_distinct(conjoint_ae$level[conjoint_ae$attribute == "country"]) + 1,                                    NA_real_,
  "a9_gender_levels",                          n_distinct(conjoint_ae$level[conjoint_ae$attribute == "gender"]) + 1,                                     NA_real_,
  "a9_total_amces",                            sum(ae$study_base == "Hainmueller & Hopkins (2015)"), NA_real_,
  "a9_amces_original",                         sum(ae$study_base == "Hainmueller & Hopkins (2015)" & ae$study == "Pre-COVID"), NA_real_,
  "a9_amces_replication",                      sum(ae$study_base == "Hainmueller & Hopkins (2015)" & ae$study == "Replication"), NA_real_,
  "a9_opposite_sign_count",                    sum(sign(conjoint_wide$Replication) != sign(conjoint_wide$`Pre-COVID`)),                                     NA_real_,
  "a9_gardener_original",                      ae$estimate[ae$study_base == "Hainmueller & Hopkins (2015)" & ae$level == "Gardener" & ae$study == "Pre-COVID"], NA_real_,
  "a9_smaller_count",                          sum(conjoint_wide$Replication < conjoint_wide$`Pre-COVID`),                                    NA_real_,
  "a9_footnote_4_fdr",                         corr("conjoint_sig_fdr"),              script("conjoint_sig_fdr"),
  "a10_stories",                               n_distinct(ae$outcome[ae$study_base == "Porter et al. (2018)"]), NA_real_,
  "a10_original_low",                          -min(ae$estimate[ae$study_base == "Porter et al. (2018)" & ae$study == "Pre-COVID"]), NA_real_,
  "a10_original_high",                         -max(ae$estimate[ae$study_base == "Porter et al. (2018)" & ae$study == "Pre-COVID"]), NA_real_,
  "a10_replication_n",                         week_n("YCLS Week 4"),                                  NA_real_,
  "a10_replication_low",                       -min(ae$estimate[ae$study_base == "Porter et al. (2018)" & ae$study == "Replication"]), NA_real_,
  "a10_replication_high",                      -max(ae$estimate[ae$study_base == "Porter et al. (2018)" & ae$study == "Replication"]), NA_real_,
  "a10_footnote_5_significant",                sum(str_detect(f2$study_group, "Porter") & f2$p_diff < 0.05), NA_real_,
  "a11_all_smaller",                           sum(str_detect(f2$study_group, "Trump") & abs(f2$estimate_ycls) < abs(f2$estimate_pre)), NA_real_,
  "a12_replication_n",                         week_n("YCLS Week 9"),                                  NA_real_,
  "b_surveys",                                 dev_value("surveys"),                  NA_real_,
  "corrigendum_correctly_signed",              corr("nonconjoint_correctly_signed"),  script("nonconjoint_correctly_signed"),
  "corrigendum_sig_smaller_of_24",             corr("nonconjoint_sig_smaller_correctly_signed"), script("nonconjoint_sig_smaller_correctly_signed"),
  "corrigendum_incorrectly_signed",            sum(f2$sign_diff),                     script("nonconjoint_incorrectly_signed"),
  "corrigendum_sig_among_incorrect",           corr("nonconjoint_sig_among_incorrectly_signed"), script("nonconjoint_sig_among_incorrectly_signed"),
  "corrigendum_atomic_sig_count",              sum(str_detect(f2$study_group, "Press") & f2$sign_diff & f2$p_diff < 0.05), NA_real_,
  "corrigendum_atomic_estimate_count",         sum(str_detect(f2$study_group, "Press")), NA_real_,
  "corrigendum_conjoint_pairs",                corr("conjoint_pairs"),                script("pairs_conjoint"),
  "corrigendum_conjoint_smaller",              corr("conjoint_smaller"),              script("conjoint_smaller"),
  "corrigendum_conjoint_sig_among_smaller",    corr("conjoint_sig_among_smaller"),    script("conjoint_sig_among_smaller"),
  "corrigendum_conjoint_larger",               corr("conjoint_larger"),               script("conjoint_larger"),
  "corrigendum_conjoint_sig_among_larger",     corr("conjoint_sig_among_larger"),     script("conjoint_sig_among_larger"),
  "corrigendum_figure_1_caption_pairs",        nrow(f2),                              script("pairs_nonconjoint"),
  "corrigendum_figure_1_caption_studies",      n_distinct(f2$study_group),            NA_real_,
  "corrigendum_figure_1a_note_sig",            corr("nonconjoint_sig_unadjusted"),    script("nonconjoint_sig_unadjusted"),
  "corrigendum_figure_1b_note_sig",            corr("nonconjoint_sig_unadjusted"),    script("nonconjoint_sig_unadjusted"),
  "corrigendum_figure_1b_note_fdr",            corr("nonconjoint_sig_fdr"),           script("nonconjoint_sig_fdr"),
  "corrigendum_figure_2_caption_pairs",        nrow(f3),                              script("pairs_conjoint"),
  "corrigendum_figure_2a_note_sig",            corr("conjoint_sig_unadjusted"),       script("conjoint_sig_unadjusted"),
  "corrigendum_figure_2b_note_sig",            corr("conjoint_sig_unadjusted"),       script("conjoint_sig_unadjusted"),
  "corrigendum_figure_2b_note_fdr",            corr("conjoint_sig_fdr"),              script("conjoint_sig_fdr")
)

# Descriptive rows ---------------------------------------------------------------------
# A descriptive claim has no printed number, so its verdict is computed rather than
# compared. Each is evaluated here from the pipeline's output, and the claims file
# evaluates it again from the study-level estimates.

floats <- published_claims |>
  filter(str_starts(claim_id, "float_")) |>
  pull(claim_id) |>
  str_remove("^float_")
has_float <- function(...) all(c(...) %in% floats)

porter <- f2 |> filter(str_detect(study_group, "Porter"))
trump_white <- f2 |> filter(str_detect(study_group, "Trump"))
peyton_pairs <- f2 |> filter(str_detect(study_group, "Peyton"))
druckman_cells <- appendix_cells_rewrite |>
  filter(appendix_table == "Table 1", column == "YCLS summary")
druckman_raw <- ae |>
  filter(study_base == "Druckman (2001)", estimate_type == "Unstandardized",
         str_detect(x_pid3, "Democrats|Republicans"))
knobe_rep <- ae |> filter(study_base == "Knobe (2003)", estimate_type == "Unstandardized",
                          study == "Replication")
disease_rep <- ae |> filter(study_base == "Tversky & Kaheneman (1981) - Gain/Loss",
                            estimate_type == "Unstandardized", study == "Replication")
welfare_rep <- ae |> filter(study_base == "Smith (1987)", study == "Replication",
                            type == "Experimental")
psv_original_rows <- ae |>
  filter(str_detect(study_group, "prospective"), estimate_type == "Unstandardized",
         survey == "Press et al. (2013)")
psv_week_approve <- ae |>
  filter(str_detect(study_group, "prospective"), estimate_type == "Unstandardized",
         str_detect(survey, "Week"), outcome_group == "Approve Nuclear Use")
trust_rows <- ae |> filter(study_base == "Peyton (2020)", estimate_type == "Standardized")
additional_surveys <- all_surveys |> filter(!replication_survey)
contrasts_2 <- table_2_rewrite |> filter(str_detect(column, "minus"))
attentive_5 <- figure_5_rewrite |> filter(str_starts(dataset, "Attentive"))
inattentive_5 <- figure_5_rewrite |> filter(str_starts(dataset, "Inattentive"))

descriptive <- tribble(
  ~claim_id,                            ~holds,
  "intro_lucid_tripled",                round(completes_2020 / completes_2019) == 3,
  "figure_1_coverage_period",           min(figure_1_rewrite$date) >= as.Date("2019-01-01") &
                                          max(figure_1_rewrite$date) == as.Date("2021-03-18"),
  "background_figure_1_reference",      has_float("figure_1"),
  "design_modified_studies",            n_distinct(ae$study_base[ae$study == "Replication" &
                                          coalesce(ae$type, "") == "COVID-specific"]) == 4,
  "design_appendix_a_reference",        has_float("figure_a1", "figure_a13", "appendix_table_1"),
  "results_table_1_reference",          has_float("table_1"),
  "results_all_smaller_nonconjoint",    all(abs(f2$estimate_ycls) < abs(f2$estimate_pre)),
  "results_foreign_aid_significant",    all(f2$sign_diff[f2$study_group_detail ==
                                          "Foreign aid misperceptions"] &
                                          f2$p_diff[f2$study_group_detail ==
                                          "Foreign aid misperceptions"] < 0.05),
  "results_conjoint_same_sign",         all(!f3$sign_diff),
  "results_figures_2_3_reference",      has_float("figure_2", "figure_3"),
  "footnote_5_table_2_reference",       has_float("table_2"),
  "device_additional_sample_period",    all(additional_surveys$time < as.Date("2020-03-01")),
  "device_trending_upward",             year_share("Respondents from web applications", 2019) >
                                          year_share("Respondents from web applications", 2018) &
                                          year_share("Respondents from mobile phones", 2019) >
                                          year_share("Respondents from mobile phones", 2018),
  "device_figure_4_reference",          has_float("figure_4"),
  "device_acq_significance",            all(contrasts_2$p.value < 0.05),
  "device_table_2_reference",           has_float("table_2"),
  "table_2_note_c9_c10_reference",      has_float("figure_c9", "figure_c10"),
  "table_2_note_c11_reference",         has_float("figure_c11"),
  "figure_5_reference",                 has_float("figure_5"),
  "figure_5_attentive_positive",        all(attentive_5$estimate > 0) & all(attentive_5$p.value < 0.05),
  "figure_5_inattentive_near_zero",     all(abs(inattentive_5$estimate) < 0.1) &
                                          all(inattentive_5$p.value > 0.05),
  "inattention_figure_5_reference",     has_float("figure_5"),
  "discussion_one_exception",           sum(f2 |> summarise(all_wrong = all(sign_diff),
                                          .by = study_group) |> pull(all_wrong)) == 1,
  "a2_c1_c4_reference",                 has_float("figure_c1", "figure_c2", "figure_c3", "figure_c4"),
  "a2_summaries_significant",           2 * (1 - pnorm(abs(bench("Question framing, pre-COVID", "fe_est") /
                                          bench("Question framing, pre-COVID", "fe_se")))) < 0.01 &
                                          2 * (1 - pnorm(abs(bench("Question framing, COVID era", "fe_est") /
                                          bench("Question framing, COVID era", "fe_se")))) < 0.01,
  "a3_all_distinguishable",             all(disease_rep$p.value < 0.05) & all(disease_rep$estimate > 0),
  "a4_within_subject_weeks",            setequal(ae$survey[ae$study_base == "Smith (1987)" &
                                          coalesce(ae$type, "") == "Observational"],
                                          c("Week 5", "Week 9")),
  "a4_all_distinguishable",             all(welfare_rep$p.value < 0.05) & all(welfare_rep$estimate > 0),
  "a4_footnote_3_papi_p",               bench("Welfare spending, GSS paper and pencil", "q_p") < 0.01,
  "a4_week_13_direct",                  "Week 13" %in% welfare_rep$survey,
  "a5_table_reference",                 has_float("appendix_table_a5"),
  "a5_program_a_significant",           all(druckman_raw$p.value[str_detect(
                                          druckman_raw$AD_Z_party_sure_thing, "Program A")] < 0.05),
  "a5_partisan_attenuation",            all(druckman_cells$p.value[
                                          str_detect(druckman_cells$row, "^Republicans' Program \\| Democrats$") |
                                          str_detect(druckman_cells$row, "^Democrats' Program \\| Republicans$")] > 0.05),
  "a5_all_expected_direction",          all(druckman_cells$estimate > 0),
  "a6_only_failure",                    sum(f2$sign_diff & f2$p_diff < 0.05 &
                                          f2$study_group == "Gilens (2001)") == 1,
  "a7_c5_c8_reference",                 has_float("figure_c5", "figure_c6", "figure_c7", "figure_c8"),
  "a7_all_distinguishable",             all(knobe_rep$estimate > 0) & all(knobe_rep$p.value < 0.05),
  "a8_monotonic",                       all(psv_original_rows$estimate[psv_original_rows$term == "90/45"] >
                                          psv_original_rows$estimate[psv_original_rows$term == "90/70"]),
  "a8_table_2_reference",               has_float("appendix_table_2"),
  "a8_approve_opposite_sign",           mean(psv_week_approve$estimate < 0 &
                                          psv_week_approve$p.value > 0.05) >= 2 / 3,
  "a8_table_3_reference",               has_float("appendix_table_3"),
  "a8_prefer_smaller_significant",      all(f2$p_diff[str_detect(f2$study_group_detail, "Prefer Nukes")] < 0.05) &
                                          all(f2$estimate_diff[str_detect(f2$study_group_detail, "Prefer Nukes")] < 0) &
                                          all(f2$estimate_ycls[str_detect(f2$study_group_detail, "Prefer Nukes")] > 0),
  "a9_gardener_not_significant",        all(conjoint_ae$p.value[conjoint_ae$level == "Gardener"] > 0.05),
  "a10_all_smaller",                    all(abs(porter$estimate_ycls) < abs(porter$estimate_pre)) &
                                          all(!porter$sign_diff),
  "a10_footnote_5_named",               setequal(porter$study_group_detail[porter$p_diff < 0.05],
                                          c("Podesta", "Sex trafficking")),
  "a11_expected_direction",             all(!trump_white$sign_diff),
  "a11_none_significant",               all(trump_white$p_diff > 0.05),
  "a12_original_trust_significant",     all(trust_rows$p.value[trust_rows$study == "Pre-COVID" &
                                          trust_rows$outcome == "Trust in Government"] < 0.05),
  "a12_original_redistribution_null",   all(trust_rows$p.value[trust_rows$study == "Pre-COVID" &
                                          trust_rows$outcome == "Support for Redistribution"] > 0.05),
  "a12_replication_trust_significant",  all(trust_rows$p.value[trust_rows$study == "Replication" &
                                          trust_rows$outcome == "Trust in Government"] < 0.05),
  "a12_replication_smaller",            all(peyton_pairs$p_diff[peyton_pairs$study_group_detail ==
                                          "Trust in Government"] < 0.05),
  "a12_replication_redistribution_null", all(trust_rows$p.value[trust_rows$study == "Replication" &
                                          trust_rows$outcome == "Support for Redistribution"] > 0.05),
  "corrigendum_scope",                  has_float("figure_2", "figure_3"),
  "corrigendum_conclusions_unchanged",  all(!f3$sign_diff) & sum(!f2$sign_diff) == 24 &
                                          round(100 * corr("avg_pct_precovid_overall")) == 73,
  "corrigendum_archive_updated",        corr("nonconjoint_sig_unadjusted") == 14 &
                                          corr("conjoint_sig_unadjusted") == 12
)

# Plotted counts -------------------------------------------------------------------------
# A figure that prints no numbers still states how many estimates it draws.

plotted_count <- function(d) nrow(d)
plotted <- tribble(
  ~claim_id,             ~value_rewrite,
  "plotted_figure_2",    nrow(f2),
  "plotted_figure_3",    nrow(f3),
  "plotted_figure_5",    nrow(figure_5_rewrite),
  "plotted_figure_a1",   sum(ae$study_base == "Hyman & Sheatsley (1950)" & ae$estimate_type == "Unstandardized"),
  "plotted_figure_a2",   sum(ae$study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive" & ae$estimate_type == "Unstandardized"),
  "plotted_figure_a3",   sum(ae$study_base == "Tversky & Kaheneman (1981) - Gain/Loss" & ae$estimate_type == "Unstandardized"),
  "plotted_figure_a4",   sum(ae$study_base == "Smith (1987)" & ae$estimate_type == "Standardized"),
  "plotted_figure_a5",   nrow(druckman_raw),
  "plotted_figure_a6",   sum(ae$study_base == "Gilens (2001)" & ae$estimate_type == "Standardized"),
  "plotted_figure_a7",   sum(ae$study_base == "Knobe (2003)" & ae$estimate_type == "Unstandardized"),
  "plotted_figure_a8",   sum(str_detect(ae$study_group, "prospective") & ae$estimate_type == "Unstandardized"),
  "plotted_figure_a9",   sum(str_detect(ae$study_group, "retrospective") & ae$estimate_type == "Unstandardized"),
  "plotted_figure_a10",  nrow(conjoint_ae),
  "plotted_figure_a11",  sum(ae$study_base == "Porter et al. (2018)" & ae$estimate_type == "Standardized"),
  "plotted_figure_a12",  sum(ae$study_base == "Trump & White (2018)" & ae$estimate_type == "Standardized"),
  "plotted_figure_a13",  nrow(trust_rows)
)

# Float cells ----------------------------------------------------------------------------
# The 146 cells of Table 2 and of the appendix's three tables, transcribed from the typeset
# pages. These are not extraction rows, so their precision is the transcribed string's own,
# checked by the round trip below.

slugify <- function(x) str_replace_all(str_to_lower(x), "[^a-z0-9]+", "_")

table_2_paper <- tribble(
  ~level,   ~column,                  ~estimate, ~se,
  "Easy",   "Browser",                "0.66",    "0.02",
  "Easy",   "Web-App",                "0.55",    "0.02",
  "Easy",   "Browser minus Web-App",  "0.11",    "0.03",
  "Easy",   "Nonmobile",              "0.63",    "0.02",
  "Easy",   "Mobile",                 "0.58",    "0.02",
  "Easy",   "Nonmobile minus Mobile", "0.05",    "0.03",
  "Medium", "Browser",                "0.53",    "0.02",
  "Medium", "Web-App",                "0.37",    "0.02",
  "Medium", "Browser minus Web-App",  "0.16",    "0.03",
  "Medium", "Nonmobile",              "0.50",    "0.02",
  "Medium", "Mobile",                 "0.42",    "0.02",
  "Medium", "Nonmobile minus Mobile", "0.08",    "0.03",
  "Hard",   "Browser",                "0.22",    "0.02",
  "Hard",   "Web-App",                "0.15",    "0.01",
  "Hard",   "Browser minus Web-App",  "0.07",    "0.02",
  "Hard",   "Nonmobile",              "0.24",    "0.02",
  "Hard",   "Mobile",                 "0.16",    "0.01",
  "Hard",   "Nonmobile minus Mobile", "0.08",    "0.02"
)

table_2_script_key <- c(
  "Browser" = "browser", "Web-App" = "webapp", "Nonmobile" = "nonmobile",
  "Mobile" = "mobile", "Browser minus Web-App" = "browser_webapp",
  "Nonmobile minus Mobile" = "nonmobile_mobile"
)

table_2_rows <- table_2_paper |>
  pivot_longer(c(estimate, se), names_to = "part", values_to = "value_paper") |>
  left_join(
    table_2_rewrite |>
      pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value_rewrite") |>
      mutate(part = if_else(part == "estimate", "estimate", "se")),
    by = c("level", "column", "part")
  ) |>
  mutate(
    claim_id = paste0("table_2_", str_to_lower(level), "_",
                      table_2_script_key[column], "_", part),
    value_script = map_dbl(claim_id, script),
    table_figure = "Table 2",
    claim = paste("Table 2,", level, "ACQ,", column, part)
  ) |>
  select(claim_id, table_figure, claim, value_paper, value_rewrite, value_script)

stopifnot(nrow(table_2_rows) == 36, !any(is.na(table_2_rows$value_rewrite)))

appendix_paper <- tribble(
  ~appendix_table, ~row,                                 ~column,               ~estimate, ~se,
  "Table 1", "Program A | Democrats",                    "YCLS summary",        "0.15",  "0.04",
  "Table 1", "Program A | Democrats",                    "Druckman (2001)",     "0.46",  "0.11",
  "Table 1", "Program A | Democrats",                    "Difference",          "-0.31", "0.12",
  "Table 1", "Program A | Republicans",                  "YCLS summary",        "0.20",  "0.05",
  "Table 1", "Program A | Republicans",                  "Druckman (2001)",     "0.41",  "0.15",
  "Table 1", "Program A | Republicans",                  "Difference",          "-0.22", "0.15",
  "Table 1", "Democrats' Program | Democrats",           "YCLS summary",        "0.11",  "0.03",
  "Table 1", "Democrats' Program | Democrats",           "Druckman (2001)",     "0.21",  "0.11",
  "Table 1", "Democrats' Program | Democrats",           "Difference",          "-0.11", "0.12",
  "Table 1", "Democrats' Program | Republicans",         "YCLS summary",        "0.06",  "0.04",
  "Table 1", "Democrats' Program | Republicans",         "Druckman (2001)",     "0.04",  "0.13",
  "Table 1", "Democrats' Program | Republicans",         "Difference",          "0.02",  "0.14",
  "Table 1", "Republicans' Program | Democrats",         "YCLS summary",        "0.05",  "0.04",
  "Table 1", "Republicans' Program | Democrats",         "Druckman (2001)",     "0.15",  "0.10",
  "Table 1", "Republicans' Program | Democrats",         "Difference",          "-0.09", "0.10",
  "Table 1", "Republicans' Program | Republicans",       "YCLS summary",        "0.10",  "0.03",
  "Table 1", "Republicans' Program | Republicans",       "Druckman (2001)",     "0.06",  "0.14",
  "Table 1", "Republicans' Program | Republicans",       "Difference",          "0.04",  "0.14",
  "Table 2", "90/70 | Prefer Nuclear Use",               "YCLS summary",        "0.08",  "0.02",
  "Table 2", "90/70 | Prefer Nuclear Use",               "Press et al. (2013)", "0.30",  "0.05",
  "Table 2", "90/70 | Prefer Nuclear Use",               "psv_diff",            "-0.22", "0.06",
  "Table 2", "90/70 | Prefer Nuclear Use",               "Aronow et al. (2019)","0.37",  "0.03",
  "Table 2", "90/70 | Prefer Nuclear Use",               "abp_diff",            "-0.29", "0.04",
  "Table 2", "90/45 | Prefer Nuclear Use",               "YCLS summary",        "0.13",  "0.03",
  "Table 2", "90/45 | Prefer Nuclear Use",               "Press et al. (2013)", "0.48",  "0.05",
  "Table 2", "90/45 | Prefer Nuclear Use",               "psv_diff",            "-0.35", "0.06",
  "Table 2", "90/45 | Prefer Nuclear Use",               "Aronow et al. (2019)","0.51",  "0.03",
  "Table 2", "90/45 | Prefer Nuclear Use",               "abp_diff",            "-0.39", "0.04",
  "Table 2", "90/70 | Approve Nuclear Use",              "YCLS summary",        "-0.04", "0.03",
  "Table 2", "90/70 | Approve Nuclear Use",              "Press et al. (2013)", "0.05",  "0.06",
  "Table 2", "90/70 | Approve Nuclear Use",              "psv_diff",            "-0.09", "0.07",
  "Table 2", "90/70 | Approve Nuclear Use",              "Aronow et al. (2019)","0.17",  "0.03",
  "Table 2", "90/70 | Approve Nuclear Use",              "abp_diff",            "-0.21", "0.04",
  "Table 2", "90/45 | Approve Nuclear Use",              "YCLS summary",        "-0.05", "0.03",
  "Table 2", "90/45 | Approve Nuclear Use",              "Press et al. (2013)", "0.28",  "0.05",
  "Table 2", "90/45 | Approve Nuclear Use",              "psv_diff",            "-0.32", "0.06",
  "Table 2", "90/45 | Approve Nuclear Use",              "Aronow et al. (2019)","0.27",  "0.03",
  "Table 2", "90/45 | Approve Nuclear Use",              "abp_diff",            "-0.32", "0.04",
  "Table 3", "Approve Strike",                           "YCLS summary",        "-0.06", "0.03",
  "Table 3", "Approve Strike",                           "Press et al. (2013)", "-0.07", "0.05",
  "Table 3", "Approve Strike",                           "psv_diff",            "0.00",  "0.06",
  "Table 3", "Approve Strike",                           "Aronow et al. (2019)","-0.12", "0.03",
  "Table 3", "Approve Strike",                           "abp_diff",            "0.06",  "0.04",
  "Table 3", "Ethical Strike",                           "YCLS summary",        "-0.04", "0.03",
  "Table 3", "Ethical Strike",                           "Press et al. (2013)", "-0.06", "0.06",
  "Table 3", "Ethical Strike",                           "psv_diff",            "0.02",  "0.06",
  "Table 3", "Ethical Strike",                           "Aronow et al. (2019)","-0.13", "0.03",
  "Table 3", "Ethical Strike",                           "abp_diff",            "0.09",  "0.04"
)

appendix_ratio_paper <- tribble(
  ~appendix_table, ~row,                           ~column,     ~value_paper,
  "Table 1", "Program A | Democrats",              "Ratio",     "0.32",
  "Table 1", "Program A | Republicans",            "Ratio",     "0.47",
  "Table 1", "Democrats' Program | Democrats",     "Ratio",     "0.50",
  "Table 1", "Democrats' Program | Republicans",   "Ratio",     "1.66",
  "Table 1", "Republicans' Program | Democrats",   "Ratio",     "0.35",
  "Table 1", "Republicans' Program | Republicans", "Ratio",     "1.70",
  "Table 2", "90/70 | Prefer Nuclear Use",         "psv_ratio", "0.27",
  "Table 2", "90/70 | Prefer Nuclear Use",         "abp_ratio", "0.21",
  "Table 2", "90/45 | Prefer Nuclear Use",         "psv_ratio", "0.27",
  "Table 2", "90/45 | Prefer Nuclear Use",         "abp_ratio", "0.25",
  "Table 3", "Approve Strike",                     "psv_ratio", "0.95",
  "Table 3", "Approve Strike",                     "abp_ratio", "0.53",
  "Table 3", "Ethical Strike",                     "psv_ratio", "0.64",
  "Table 3", "Ethical Strike",                     "abp_ratio", "0.28",
  "Table 2", "90/70 | Approve Nuclear Use",        "psv_ratio", "-",
  "Table 2", "90/70 | Approve Nuclear Use",        "abp_ratio", "-",
  "Table 2", "90/45 | Approve Nuclear Use",        "psv_ratio", "-",
  "Table 2", "90/45 | Approve Nuclear Use",        "abp_ratio", "-"
)

appendix_slug <- function(appendix_table, row, column) {
  paste0("appendix_", slugify(appendix_table), "_",
         slugify(paste(str_replace(row, " \\| ", " "), column)))
}

appendix_rows <- appendix_paper |>
  pivot_longer(c(estimate, se), names_to = "part", values_to = "value_paper") |>
  left_join(
    appendix_cells_rewrite |>
      select(appendix_table, row, column, estimate, std.error) |>
      pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value_rewrite") |>
      mutate(part = if_else(part == "estimate", "estimate", "se")),
    by = c("appendix_table", "row", "column", "part")
  ) |>
  mutate(
    claim_id = paste0(appendix_slug(appendix_table, row, column), "_", part),
    value_script = map_dbl(claim_id, script),
    table_figure = paste("Appendix", appendix_table),
    claim = paste("Appendix", appendix_table, "|", row, "|", column, part)
  ) |>
  select(claim_id, table_figure, claim, value_paper, value_rewrite, value_script)

appendix_ratio_all <- appendix_ratio_paper |>
  left_join(appendix_ratios_rewrite |> select(appendix_table, row, column, value_rewrite = ratio),
            by = c("appendix_table", "row", "column")) |>
  mutate(
    claim_id = paste0(appendix_slug(appendix_table, row,
                                    if_else(column == "Ratio", "", column)),
                      if_else(column == "Ratio", "ratio", "")),
    claim_id = str_replace(claim_id, "__+", "_"),
    claim_id = str_remove(claim_id, "_$"),
    value_script = map_dbl(claim_id, script),
    table_figure = paste("Appendix", appendix_table),
    claim = paste("Appendix", appendix_table, "|", row, "|", column)
  ) |>
  select(claim_id, table_figure, claim, value_paper, value_rewrite, value_script)

# Four relative sizes are printed as a dash rather than a number, because the note says a
# relative size is not calculated where the replication estimate is signed against the
# comparison. The dash is a claim about the sign, so those rows carry a verdict rather
# than a value.
appendix_ratio_rows <- appendix_ratio_all |> filter(value_paper != "-")
appendix_dash_rows <- appendix_ratio_all |>
  filter(value_paper == "-") |>
  mutate(holds = value_rewrite < 0, digits = NA_integer_,
         value_rewrite = NA_real_, value_script = NA_real_)

float_rows <- bind_rows(table_2_rows, appendix_rows, appendix_ratio_rows) |>
  mutate(digits = if_else(str_detect(value_paper, "\\."),
                          nchar(str_remove(value_paper, "^.*\\.")), 0L))

stopifnot(nrow(float_rows) == 146, nrow(appendix_dash_rows) == 4,
          !any(is.na(float_rows$value_rewrite)),
          !any(is.na(float_rows$value_script)))

# A transcribed float cell must survive a round trip through its own precision, which is
# the check that makes the transcribed string carry the precision for these rows.
round_trips(float_rows$value_paper, float_rows$digits)

# Both directions of the join, so a published cell with no counterpart and a rewrite cell
# nothing compares against are each caught.
stopifnot(
  nrow(anti_join(table_2_paper |>
                   pivot_longer(c(estimate, se), names_to = "part"),
                 table_2_rewrite |>
                   pivot_longer(c(estimate, std.error), names_to = "part") |>
                   mutate(part = if_else(part == "estimate", "estimate", "se")),
                 by = c("level", "column", "part"))) == 0,
  nrow(anti_join(table_2_rewrite |>
                   pivot_longer(c(estimate, std.error), names_to = "part") |>
                   mutate(part = if_else(part == "estimate", "estimate", "se")),
                 table_2_paper |>
                   pivot_longer(c(estimate, se), names_to = "part"),
                 by = c("level", "column", "part"))) == 0,
  nrow(anti_join(appendix_paper, appendix_cells_rewrite,
                 by = c("appendix_table", "row", "column"))) == 0,
  nrow(anti_join(appendix_cells_rewrite, appendix_paper,
                 by = c("appendix_table", "row", "column"))) == 0,
  nrow(anti_join(appendix_ratio_paper, appendix_ratios_rewrite,
                 by = c("appendix_table", "row", "column"))) == 0,
  nrow(anti_join(appendix_ratios_rewrite, appendix_ratio_paper,
                 by = c("appendix_table", "row", "column"))) == 0
)

# Assembly ---------------------------------------------------------------------------------

extraction <- published_claims |>
  select(claim_id, location, claim_type, value_paper, digits, comparison, claim)

prose_rows <- prose |>
  left_join(extraction, by = "claim_id") |>
  mutate(table_figure = location) |>
  select(claim_id, table_figure, claim, value_paper, digits, comparison,
         value_rewrite, value_script)

plotted_rows <- plotted |>
  left_join(extraction, by = "claim_id") |>
  mutate(table_figure = "Float inventory", value_script = NA_real_) |>
  select(claim_id, table_figure, claim, value_paper, digits, comparison,
         value_rewrite, value_script)

descriptive_rows <- descriptive |>
  left_join(extraction, by = "claim_id") |>
  mutate(table_figure = location, value_rewrite = NA_real_, value_script = NA_real_) |>
  select(claim_id, table_figure, claim, value_paper, digits, comparison,
         value_rewrite, value_script, holds)

# Every extraction row requiring a block must reach the ground truth, and nothing may
# reach it that the extraction does not declare.
declared <- published_claims |> filter(needs_block) |> pull(claim_id)
carried <- c(prose_rows$claim_id, plotted_rows$claim_id, descriptive_rows$claim_id)
if (!setequal(declared, carried)) {
  print(list(missing_from_ground_truth = setdiff(declared, carried),
             not_declared = setdiff(carried, declared)))
  stop("The ground truth and the extraction disagree about which claims need a row.")
}

ground_truth <- bind_rows(
  prose_rows |> mutate(holds = NA),
  plotted_rows |> mutate(holds = NA),
  descriptive_rows,
  float_rows |> mutate(comparison = "==", holds = NA),
  appendix_dash_rows |> mutate(comparison = "==")
) |>
  mutate(
    paper_id = paper_id,
    match = if_else(comparison == "approx", NA_real_, agrees(value_script, value_paper, digits)),
    match_rewrite = if_else(comparison == "approx", NA_real_,
                            agrees(value_rewrite, value_paper, digits))
  )

stopifnot(!any(duplicated(ground_truth$claim_id)))

# The locus, named at each site --------------------------------------------------------------
# Every adverse row carries a cause. The two float rules are stated once and applied by a
# filter rather than defaulted; the prose causes are named claim by claim.

locus_table <- tribble(
  ~claim_id, ~defect_locus, ~locus_note,
  "design_median_duration", "paper_internal", "The median completion time is 12.883 minutes, which is 12.9 at the stated precision and 12.8 only if truncated",
  "results_replication_estimates", "unresolved", "The deposit's own set of pooled estimates holds 102 replication estimates against the article's 101; the 89 pre-COVID estimates in the same sentence reproduce exactly",
  "results_all_smaller_nonconjoint", "paper_internal", "Twenty-seven of the 28 non-conjoint replication estimates are smaller in magnitude; the redistribution pair is not, because its pre-COVID summary is essentially zero",
  "results_sig_smaller_of_24", "paper_internal", "Corrected to 11 by the 2023 corrigendum, which the deposit and the rewrite both give",
  "results_conjoint_sig_among_smaller", "paper_internal", "Corrected to 11 by the 2023 corrigendum, which the deposit and the rewrite both give",
  "results_correspondence_nonconjoint", "paper_internal", "The mean ratio over the 24 correctly signed non-conjoint pairs is 0.4833, which is 48 per cent; the overall 73 and the conjoint 87 in the same paragraph both reproduce",
  "figure_2_sig_count", "paper_internal", "Corrected to 14 before adjustment and 13 after by the 2023 corrigendum",
  "figure_3_sig_count", "paper_internal", "Corrected to 12 before adjustment and 7 after by the 2023 corrigendum",
  "device_additional_sample_period", "paper_internal", "The 63,245 respondents are those in the 25 UserAgent surveys other than the thirteen reported here, two of which were fielded in May and June 2020",
  "device_2019_webapp", "paper_internal", "The mean over the seventeen 2019 surveys is 33.8 per cent, which is 34 at the stated precision; the 2018 and 2020 figures in the same sentence reproduce exactly under the same derivation",
  "device_2019_mobile", "paper_internal", "The mean over the seventeen 2019 surveys is 57.6 per cent; the sentence prints the same 56 per cent it gives for 2020, which does reproduce",
  "device_overlap_webapp_given_mobile", "unresolved", "Of the 9,754 mobile respondents, 7,268 arrived from a web application, which is 75 per cent; the 97 per cent in the same sentence reproduces exactly",
  "device_duration_browser", "paper_internal", "Browser respondents averaged 21.0 minutes; 21.5 is the nonmobile average, which the next sentence uses",
  "device_acq_significance", "paper_internal", "Five of the six contrasts in Table 2 are significant; the Easy check's nonmobile-versus-mobile contrast is not, and Table 2 prints it without an asterisk",
  "inattention_inattentive_share", "paper_internal", "The correspondence is 72.98 per cent, so the complement is 27 per cent",
  "a1_replication_estimate", "paper_internal", "The COVID-era summary effect is 25.39 points, and 25.4 is what the 83 per cent ratio in the same sentence implies",
  "a1_difference", "paper_internal", "The difference is 5.11 points, which is what the P = 0.16 in the same sentence implies",
  "a2_covid_vs_precovid_p", "paper_internal", "The two-sided p-value is 0.044; the published 0.02 is the one-tailed value",
  "a2_covid_vs_direct_p", "paper_internal", "The two-sided p-value is 0.183; the published 0.09 is the one-tailed value",
  "a4_capi_summary", "paper_internal", "The pooled CAPI summary is 0.9943, which is 0.99 at the stated precision",
  "a5_table_reference", "paper_internal", "The appendix carries no Table A.5; the table this sentence points at is captioned Table 1",
  "a5_program_a_significant", "unresolved", "Seven of the eight plotted Program A estimates are distinguishable from zero; the sentence does not say whether it describes the plotted study-level estimates or the pooled summaries, and it holds for the summaries",
  "a7_covid_vs_direct_se", "paper_internal", "The standard error of that difference is 0.057; the published 0.04 is the standard error of the difference against the pre-COVID benchmark, given in the next sentence",
  "a7_covid_vs_direct_p", "paper_internal", "The two-sided p-value is 0.919; the published 0.46 is the one-tailed value",
  "a8_9070_success", "paper_internal", "The condition is labelled 90/70 throughout, and its two siblings are described at the rates their labels name",
  "a8_original_9070_prefer", "paper_internal", "The original study's estimate is 29.7 points; 37 is the Aronow, Baron and Pinson replication's, as appendix Table 2 prints",
  "a8_original_9045_prefer", "paper_internal", "The original study's estimate is 47.6 points; 51 is the Aronow, Baron and Pinson replication's",
  "a8_original_9070_approve", "paper_internal", "The original study's estimate is 5.1 points; 17 is the Aronow, Baron and Pinson replication's",
  "a8_original_9045_approve", "paper_internal", "The original study's estimate is 27.5 points; 27 is the Aronow, Baron and Pinson replication's",
  "a9_total_amces", "paper_internal", "41 for the original study and 41 for the replication is 82",
  "a10_footnote_5_significant", "paper_internal", "Four of the six differences are significant before adjustment and three after controlling the false discovery rate",
  "a10_footnote_5_named", "paper_internal", "The Scaramucci and Vermont stories are also significantly different before adjustment",
  "corrigendum_figure_1a_note_sig", "paper_internal", "The note reprinted above the corrigendum's original panel, superseded by the corrected panel on the same page",
  "corrigendum_figure_2a_note_sig", "paper_internal", "The note reprinted above the corrigendum's original panel, superseded by the corrected panel on the same page"
)

# Appendix Table 2's replication-summary column and everything derived from it: the
# deposited prospective block pools the COVID-era weeks without restricting them to the
# unstandardized estimates, so it counts each week twice on two different scales. Its
# three siblings in the same file all carry the filter, and the published table is what
# the filtered version gives.
prospective_cells <- appendix_rows$claim_id[str_starts(appendix_rows$claim_id, "appendix_table_2_")]
prospective_ratios <- appendix_ratio_rows$claim_id[
  str_starts(appendix_ratio_rows$claim_id, "appendix_table_2_")]

ground_truth <- ground_truth |>
  left_join(locus_table, by = "claim_id") |>
  mutate(
    adverse = (!is.na(match) & match == 0) | (!is.na(match_rewrite) & match_rewrite == 0) |
      (!is.na(holds) & !holds),
    defect_locus = case_when(
      !adverse ~ NA_character_,
      !is.na(defect_locus) ~ defect_locus,
      claim_id %in% c(prospective_cells, prospective_ratios) &
        !is.na(match) & match == 0 & !is.na(match_rewrite) & match_rewrite == 1 ~ "archive",
      str_starts(claim_id, "table_2_") ~ "archive",
      .default = NA_character_
    ),
    notes = case_when(
      !is.na(locus_note) ~ locus_note,
      adverse & defect_locus == "archive" &
        claim_id %in% c(prospective_cells, prospective_ratios) ~
        "The deposited prospective pooling omits the estimate-type filter its three siblings carry; the rewrite restores it and the published cell then reproduces",
      adverse & str_starts(claim_id, "table_2_") ~
        "The deposited script rounds each pass rate to three decimals before formatting to two, so 0.5449 is printed as 0.55; the rate itself is 0.54 at the published precision",
      .default = NA_character_
    )
  ) |>
  select(paper_id, claim_id, table_figure, claim, value_script, value_paper, digits,
         match, value_rewrite, match_rewrite, holds, defect_locus, notes)

# THE LOCUS RULE, in three states ------------------------------------------------------------
adverse <- with(ground_truth,
                (!is.na(match) & match == 0) | (!is.na(match_rewrite) & match_rewrite == 0) |
                  (!is.na(holds) & !holds))
clean <- with(ground_truth,
              !adverse & ((!is.na(match_rewrite) & match_rewrite == 1) |
                            (!is.na(holds) & holds)))

if (any(adverse & is.na(ground_truth$defect_locus))) {
  print(ground_truth |> filter(adverse & is.na(defect_locus)) |>
          select(claim_id, value_paper, value_script, value_rewrite, match, match_rewrite, holds),
        n = Inf)
  stop("An adverse row carries no defect_locus.")
}
if (any(clean & !is.na(ground_truth$defect_locus))) {
  print(ground_truth |> filter(clean & !is.na(defect_locus)) |>
          select(claim_id, value_paper, value_rewrite, match_rewrite, holds, defect_locus),
        n = Inf)
  stop("A clean match carries a defect_locus.")
}
stopifnot(all(is.na(ground_truth$defect_locus) |
                ground_truth$defect_locus %in%
                c("paper_internal", "archive", "environment", "rewrite", "unresolved")))

# The extraction against the ground truth -------------------------------------------------
reconcile <- published_claims |>
  filter(!is.na(value_paper)) |>
  select(claim_id, extraction = value_paper) |>
  inner_join(ground_truth |> select(claim_id, transcription = value_paper), by = "claim_id")

stopifnot(nrow(reconcile) == sum(!is.na(published_claims$value_paper) &
                                   published_claims$claim_id %in% ground_truth$claim_id))
if (!all(normalise_printed(reconcile$extraction) ==
           normalise_printed(reconcile$transcription))) {
  print(reconcile |> filter(normalise_printed(extraction) != normalise_printed(transcription)),
        n = Inf)
  stop("The extraction and the ground truth disagree about a published value.")
}

# Float coverage -----------------------------------------------------------------------------
# The extraction records how many numbers each published float prints; the ground truth
# records how many of them are covered and how many reproduce, and the plotted-count claim
# carries the wordless figures. Each float reads its own rows.

covered_for <- function(pattern) {
  rows <- ground_truth |> filter(str_detect(claim_id, pattern), !is.na(digits))
  tibble(covered = nrow(rows),
         reproduced_by_rewrite = sum(rows$match_rewrite, na.rm = TRUE),
         reproduced_by_archive = sum(rows$match, na.rm = TRUE))
}

plotted_for <- function(id) {
  row <- ground_truth |> filter(claim_id == id)
  if (nrow(row) == 0) return(tibble(plotted = NA_integer_, plotted_reproduced = NA_integer_))
  tibble(plotted = as.integer(row$value_paper),
         plotted_reproduced = as.integer(row$match_rewrite == 1) * as.integer(row$value_paper))
}

float_declared <- published_claims |>
  filter(str_starts(claim_id, "float_")) |>
  transmute(float = str_remove(claim_id, "^float_"),
            published_numbers = as.integer(value_paper))

float_coverage <- float_declared |>
  mutate(
    cells = map(float, \(f) {
      if (f == "table_2") covered_for("^table_2_(easy|medium|hard)_")
      else if (f == "appendix_table_1") covered_for("^appendix_table_1_")
      else if (f == "appendix_table_2") covered_for("^appendix_table_2_")
      else if (f == "appendix_table_3") covered_for("^appendix_table_3_")
      else tibble(covered = 0L, reproduced_by_rewrite = 0L, reproduced_by_archive = 0L)
    }),
    plot = map(float, \(f) plotted_for(paste0("plotted_", f)))
  ) |>
  unnest(c(cells, plot)) |>
  mutate(
    note = case_when(
      str_starts(float, "figure_b") ~
        "The rewrite does not compute the covariate distributions, so the plotted proportions have no counterpart",
      str_starts(float, "figure_c") ~
        "A screenshot of survey content, stating no estimated quantity",
      float == "table_1" ~
        "Prints no estimates; its study count and replication count are covered as prose claims",
      float %in% c("figure_1", "figure_4") ~
        "Prints no numbers on its face; the quantities it carries are covered as prose claims about its note and the text around it",
      str_starts(float, "corrigendum_figure") ~
        "Reprints an article figure in two panels; the counts in its notes are covered as prose claims",
      .default = NA_character_
    )
  )

stopifnot(nrow(float_coverage) == nrow(float_declared))
if (!all(float_coverage$covered == float_coverage$published_numbers)) {
  print(float_coverage |> filter(covered != published_numbers), n = Inf)
  stop("A float prints a different number of cells from the count the extraction declares.")
}

# The coverage gate ----------------------------------------------------------------------------
# The second instrument is read as a program, not as text: it is run, its output is captured,
# and the printed claim lines are counted. Its own environment, because both files
# necessarily read the same outputs and name objects for what they hold.

claims_output <- capture.output(
  source(here::here("maintained", "in_text_claims.R"), local = new.env(), echo = FALSE)
)

printed <- claims_output |>
  str_subset("^CLAIM ") |>
  str_match("^CLAIM ([^ ]+) = (.*?) \\|\\| (.*)$")
printed_claims <- tibble(claim_id = printed[, 2], printed_value = printed[, 3],
                         label = printed[, 4])

required <- published_claims |> filter(needs_block)

missing_blocks <- setdiff(required$claim_id, printed_claims$claim_id)
unknown_blocks <- setdiff(printed_claims$claim_id, published_claims$claim_id)
if (length(missing_blocks) > 0 || length(unknown_blocks) > 0) {
  print(list(missing = missing_blocks, unknown = unknown_blocks))
  stop("in_text_claims.R does not print exactly the claims the extraction requires.")
}
if (nrow(printed_claims) != nrow(required)) {
  print(printed_claims |> count(claim_id) |> filter(n > 1))
  stop("in_text_claims.R printed ", nrow(printed_claims), " claims against ",
       nrow(required), " extraction rows requiring a block.")
}

# Cross-instrument comparison. The two files reach the same claimed number by separate
# paths from the same pipeline outputs; where they disagree, one of them is wrong.
cross <- printed_claims |>
  left_join(ground_truth |> select(claim_id, value_rewrite, holds), by = "claim_id") |>
  left_join(published_claims |> select(claim_id, digits, comparison, claim_type),
            by = "claim_id") |>
  mutate(
    expected = pmap_chr(
      list(claim_type, holds, value_rewrite, digits, comparison),
      function(type, holds_value, value, digits, comparison) {
        if (!is.na(comparison) && comparison == "approx") return(NA_character_)
        if (type == "descriptive") return(as.character(holds_value))
        if (is.na(value) || is.na(digits)) return(NA_character_)
        render_at(value, digits)
      }
    ),
    agrees = is.na(expected) | printed_value == expected
  )

if (!all(cross$agrees)) {
  print(cross |> filter(!agrees) |> select(claim_id, printed_value, expected), n = Inf)
  stop("The two instruments disagree about a claimed value.")
}

# Write -----------------------------------------------------------------------------------------

# Errata spine gate ----
# errata.qmd names, for each published entry, the ground truth rows that entry corrects. An
# id that no longer exists is a typo or a renamed claim, and a dangling reference in a
# document whose whole purpose is correcting the record is worse than a build that refuses.
errata_path <- here::here("errata_entries.csv")
if (file.exists(errata_path)) {
  errata_ids <- read_csv(errata_path, show_col_types = FALSE) |>
    pull(claim_ids) |>
    str_split(";") |>
    unlist() |>
    str_trim()
  errata_ids <- errata_ids[!is.na(errata_ids) & errata_ids != ""]
  dangling_errata_ids <- setdiff(errata_ids, ground_truth$claim_id)
  if (length(dangling_errata_ids) > 0) {
    stop("errata_entries.csv lists claim ids absent from the ground truth: ",
         paste(dangling_errata_ids, collapse = ", "))
  }
  print(str_glue("Errata spine: {length(unique(errata_ids))} distinct claim ids listed, ",
                 "all present in the ground truth."))
}

write_csv(float_coverage, here::here("ground_truth", "float_coverage.csv"))
write_csv(ground_truth, here::here("ground_truth", paste0(paper_id, "_ground_truth.csv")))

print(paste("rows:", nrow(ground_truth),
            "| match = 1:", sum(ground_truth$match == 1, na.rm = TRUE),
            "| match = 0:", sum(ground_truth$match == 0, na.rm = TRUE),
            "| match = NA:", sum(is.na(ground_truth$match))))
print(paste("match_rewrite = 1:", sum(ground_truth$match_rewrite == 1, na.rm = TRUE),
            "| match_rewrite = 0:", sum(ground_truth$match_rewrite == 0, na.rm = TRUE),
            "| match_rewrite = NA:", sum(is.na(ground_truth$match_rewrite))))
print(ground_truth |> count(holds))
print(ground_truth |> filter(!is.na(defect_locus)) |> count(defect_locus))
print(ground_truth |> filter(match_rewrite == 0 | (!is.na(holds) & !holds)) |>
        select(table_figure, claim_id, value_paper, value_rewrite, holds, defect_locus),
      n = 100, width = 200)
print(paste(nrow(printed_claims), "claims printed by the second instrument against",
            nrow(required), "extraction rows requiring a block;",
            sum(float_coverage$published_numbers), "published float cells transcribed."))
