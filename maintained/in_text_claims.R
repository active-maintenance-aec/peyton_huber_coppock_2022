# peyton_huber_coppock_2022/maintained/in_text_claims.R
# Output: printed to the console; nothing is written
# Depends on: maintained/output/*, ground_truth/published_claims.csv
# Description: The second instrument. Every quantity the article, its online appendix or
#   the 2023 corrigendum states outside a table is recomputed here from the pipeline's own
#   output by a path of its own and printed beside the sentence that states it. It reads
#   the extraction, because a block cannot check the article's own cross-references
#   without the float inventory the extraction declares, and it never reads the ground
#   truth, because agreeing with the comparison would prove nothing.
#
#   Where build_ground_truth.R reaches a quantity through text_correspondence_summary.csv
#   or text_device_metadata.csv, this file goes back to the estimates those summaries were
#   built from, so the two derivations are separate. Nothing here refits anything.
#
#   Each printed line is CLAIM <id> = <value> || <label>. The id on that line is the only
#   link the coverage gate uses.

source(here::here("maintained", "helpers.R"))

options(width = 200)

published_claims <- read_csv(
  here::here("ground_truth", "published_claims.csv"),
  col_types = cols(value_paper = col_character(), .default = col_guess())
)

claim_row <- function(id) {
  row <- published_claims |> filter(.data$claim_id == .env$id)
  stopifnot(nrow(row) == 1)
  row
}

# Signed zero is normalised on this side as well as on the transcription side;
# whichever instrument normalises, both must.
render_at <- function(x, digits) {
  out <- sprintf(paste0("%.", digits, "f"), x)
  str_replace(out, "^-(0(\\.0+)?)$", "\\1")
}

emit <- function(id, value, label) {
  row <- claim_row(id)
  rendered <- if ((!is.na(row$comparison) && row$comparison == "approx") || is.na(value)) {
    "NA"
  } else {
    render_at(value, row$digits)
  }
  cat("CLAIM ", id, " = ", rendered, " || ", label, "\n", sep = "")
}

emit_holds <- function(id, holds, label) {
  cat("CLAIM ", id, " = ", as.character(holds), " || ", label, "\n", sep = "")
}

# The article's own float inventory, as the extraction declares it. A cross-reference is
# a claim with a computable truth value: the float it names either exists or it does not.
floats <- published_claims |>
  filter(str_starts(claim_id, "float_")) |>
  pull(claim_id) |>
  str_remove("^float_")

exists_float <- function(...) all(c(...) %in% floats)

# Pipeline output ------------------------------------------------------------------

summary_dat <- read_csv(file.path(out_dir, "phc_summary_clean.csv"), show_col_types = FALSE)
appendix_estimates <- read_csv(file.path(out_dir, "appendix_study_estimates.csv"),
                               show_col_types = FALSE)
appendix_cells <- read_csv(file.path(out_dir, "appendix_table_cells.csv"), show_col_types = FALSE)
benchmarks <- read_csv(file.path(out_dir, "text_pooled_benchmarks.csv"), show_col_types = FALSE)
figure_1 <- read_csv(file.path(out_dir, "figure_1_lucid_weekly_completes.csv"),
                     show_col_types = FALSE)
figure_2 <- read_csv(file.path(out_dir, "figure_2_noncojoint_correspondence.csv"),
                     show_col_types = FALSE)
figure_3 <- read_csv(file.path(out_dir, "figure_3_conjoint_correspondence.csv"),
                     show_col_types = FALSE)
figure_5 <- read_csv(file.path(out_dir, "figure_5_trust_replication.csv"), show_col_types = FALSE)
table_2_cells <- read_csv(file.path(out_dir, "table_2_acq_pass_rates_cells.csv"),
                          show_col_types = FALSE)
by_survey <- read_csv(file.path(out_dir, "text_device_by_survey.csv"), show_col_types = FALSE)
by_year <- read_csv(file.path(out_dir, "text_device_by_year.csv"), show_col_types = FALSE)
all_surveys <- read_csv(file.path(out_dir, "text_device_all_surveys.csv"), show_col_types = FALSE)
device <- read_csv(file.path(out_dir, "text_device_metadata.csv"), show_col_types = FALSE)

dev_value <- function(name) device$value[device$quantity == name]

# The twelve studies, with the atomic aversion experiment's two halves rejoined, and the
# variant column that separates a direct replication from its COVID-specific twin inside
# one week.
estimates <- appendix_estimates |>
  mutate(
    study_base = str_replace(study_group, "^Press et al\\. \\(2013\\).*", "Press et al. (2013)"),
    variant = coalesce(framing_Z_type, knobe_Z_type, type)
  )

# The set the paper summarises: standardized rows where a study reports both scales, the
# unstandardized rows where it reports only those, and the experimental welfare estimates.
summarised <- estimates |>
  filter(estimate_type == "Standardized" | is.na(estimate_type)) |>
  filter(!(study_base == "Smith (1987)" &
             (type != "Experimental" | survey %in% paste("GSS", 1987:2018))))

pairs <- bind_rows(figure_2, figure_3)
signed <- pairs |> filter(!sign_diff)

# Abstract ----

# "We investigate the generalizability of COVID era survey experiments with 33
#  replications of 12 pre-pandemic designs, fielded across 13 quota samples of Americans
#  between March and July 2020."
replication_count <- estimates |>
  filter(study == "Replication") |>
  distinct(study_base, survey, variant) |>
  nrow()

emit("abstract_replications", replication_count,
     "Distinct study, survey and variant combinations among the replication estimates")
emit("abstract_designs", n_distinct(estimates$study_base), "Distinct original studies")
emit("abstract_samples", nrow(by_survey), "Rows of the per-survey device table, one per Lucid survey")
emit("abstract_field_month_first", dev_value("field_period_month_first"),
     "Earliest calendar month in which a replication respondent was interviewed")
emit("abstract_field_month_last", dev_value("field_period_month_last"),
     "Latest calendar month in which a replication respondent was interviewed")
emit("abstract_field_year", dev_value("field_period_year_first"),
     "The single calendar year the replication surveys were fielded in")

# Introduction ----

# "For example, purchases by academic clients on Lucid - a widely used marketplace for
#  survey respondents - nearly tripled between 2019 and 2020."
completes_by_year <- figure_1 |>
  mutate(year = year(date)) |>
  summarise(completes = sum(completes), .by = year)
growth <- completes_by_year$completes[completes_by_year$year == 2020] /
  completes_by_year$completes[completes_by_year$year == 2019]
emit_holds("intro_lucid_tripled", round(growth, 1) >= 2.5 && round(growth) == 3,
           paste("2020 completes divided by 2019 completes:", round(growth, 3)))

# "We provide an answer using 33 replications fielded during the onset of the COVID-19
#  pandemic of 12 previously published survey experiments."
emit("intro_replications", replication_count, "Replications, counted as in the abstract")
emit("intro_designs", n_distinct(estimates$study_base), "Original studies, counted as in the abstract")

# "Our COVID era replication estimates nearly always agree with pre-COVID estimates in
#  terms of sign and significance, but are somewhat smaller in magnitude at an average of
#  73% of the pre-COVID effect size."
correspondence <- mean(signed$estimate_ycls / signed$estimate_pre)
emit("intro_correspondence", 100 * correspondence,
     "Mean ratio of COVID-era to pre-COVID estimate over the correctly signed pairs")

# Figure 1 and the Background section ----

# "Proprietary data provided by Lucid cover the period 1 January 2019 - 18 March 2021. In
#  2019, Lucid sold 729,284 completed survey responses to academic buyers, compared with
#  2,185,387 in 2020."
emit_holds(
  "figure_1_coverage_period",
  min(figure_1$date) >= as.Date("2019-01-01") & max(figure_1$date) == as.Date("2021-03-18"),
  paste("Plotted weeks run", min(figure_1$date), "to", max(figure_1$date))
)
emit("figure_1_completes_2019", completes_by_year$completes[completes_by_year$year == 2019],
     "Weekly completes summed over 2019")
emit("figure_1_completes_2020", completes_by_year$completes[completes_by_year$year == 2020],
     "Weekly completes summed over 2020")

# "On the Lucid platform, the demand for survey respondents in 2020 increased by roughly
#  40% among commercial clients and by 200% among academic clients (see Figure 1)."
emit("background_academic_growth", 100 * (growth - 1),
     "Percentage increase in academic completes from 2019 to 2020")
emit_holds("background_figure_1_reference", exists_float("figure_1"),
           "Cross-reference: Figure 1 is in the float inventory")

# Design ----

# "Between March and July 2020, we recruited weekly samples of approximately 1,000
#  US-based participants via Lucid. Each survey was between 10 and 15 min-long (median
#  duration: 12.8 min)."
emit("design_weekly_sample", mean(by_survey$n), "Mean respondents per survey")
emit("design_median_duration", dev_value("duration_median_minutes"),
     "Median survey duration in minutes, pooled across the thirteen surveys")

# "We conducted 33 replications across 12 unique studies, chosen based on the following
#  criteria."
emit("design_replications", replication_count, "Replications, counted as in the abstract")
emit("design_studies", n_distinct(estimates$study_base), "Original studies, counted as in the abstract")

# "Modified versions of studies 2, 3, 5, and 7 were also replicated using COVID-specific
#  content. A description of each modified version and their corresponding replication
#  estimates are provided in Online Appendix Section A."
modified <- estimates |>
  filter(study == "Replication", coalesce(type, "") == "COVID-specific") |>
  distinct(study_base) |>
  pull(study_base)
emit_holds(
  "design_modified_studies",
  setequal(modified, c("Tversky & Kaheneman (1981) - Cheap/Expensive",
                       "Tversky & Kaheneman (1981) - Gain/Loss",
                       "Druckman (2001)", "Knobe (2003)")),
  paste("Studies with a COVID-specific arm:", paste(sort(modified), collapse = "; "))
)
emit_holds("design_appendix_a_reference",
           exists_float("figure_a1", "figure_a13", "appendix_table_1"),
           "Cross-reference: Online Appendix Section A is in the float inventory")

# Results ----

# "We were able to obtain the original effect size(s) for each of the 12 pre-COVID studies
#  listed in Table 1, and at least one pre-COVID replication estimate of the original
#  effect size(s) for 7 of these studies. In total, we obtained 89 pre-COVID estimates and
#  101 replication estimates."
precovid_sources <- estimates |>
  filter(study == "Pre-COVID") |>
  summarise(sources = n_distinct(survey), .by = study_base)
emit("results_studies", n_distinct(estimates$study_base), "Original studies, counted as in the abstract")
emit_holds("results_table_1_reference", exists_float("table_1"),
           "Cross-reference: Table 1 is in the float inventory")
emit("results_studies_with_precovid_replication", sum(precovid_sources$sources > 1),
     "Studies with more than one pre-COVID source, so with at least one pre-COVID replication")
emit("results_precovid_estimates", sum(summarised$study == "Pre-COVID"),
     "Pre-COVID estimates in the set the summary effect sizes pool")
emit("results_replication_estimates", sum(summarised$study == "Replication"),
     "Replication estimates in the set the summary effect sizes pool")

# "The General Social Survey (GSS) has administered the welfare versus aid to the poor
#  experiment 20 times between 1986 and 2018. If all GSS estimates are included, we have
#  108 pre-COVID-19 estimates in total. ... we use the 1986 GSS experiment as our original
#  estimate and take the first two replications conducted on online samples by Huber and
#  Paris (2013) as our pre-COVID replication estimates."
gss_surveys <- estimates |>
  filter(study == "Pre-COVID", str_detect(coalesce(survey, ""), "^GSS")) |>
  distinct(survey)
emit("footnote_3_gss_administrations", nrow(gss_surveys),
     "Distinct GSS administrations of the welfare experiment in the deposited data")
all_precovid <- estimates |>
  filter(estimate_type == "Standardized" | is.na(estimate_type)) |>
  filter(study == "Pre-COVID")
emit("footnote_3_all_precovid_estimates", nrow(all_precovid),
     "Pre-COVID estimates with every GSS administration included")
emit("footnote_3_huber_replications",
     benchmarks$k[benchmarks$benchmark == "Welfare spending, Huber benchmark"],
     "Studies pooled in the Huber and Paris benchmark")

# "Across the 12 studies, we obtained 138 summary effect size estimates - 82 for the
#  conjoint studies and 56 for the remaining studies."
emit("results_summary_estimates", nrow(summary_dat), "Rows of the summary effect size table")
emit("results_summary_conjoint",
     sum(summary_dat$study_group == "Hainmueller & Hopkins (2015)"),
     "Summary effect sizes belonging to the conjoint study")
emit("results_summary_nonconjoint",
     sum(summary_dat$study_group != "Hainmueller & Hopkins (2015)"),
     "Summary effect sizes belonging to the other eleven studies")

# "For the non-conjoint studies, Figure 2 compares the 28 estimated summary effects from
#  the pre-COVID studies (horizontal axis) with their 28 replications (vertical axis). All
#  replication summary estimates were smaller in magnitude than their pre-COVID estimates,
#  with 24 of 28 signed in the same direction."
emit("results_fig2_pairs", nrow(figure_2), "Non-conjoint pairs plotted in Figure 2")
emit_holds(
  "results_all_smaller_nonconjoint",
  all(abs(figure_2$estimate_ycls) < abs(figure_2$estimate_pre)),
  paste("Pairs whose replication estimate is larger in magnitude:",
        paste(figure_2$study_group_detail[abs(figure_2$estimate_ycls) >=
                                            abs(figure_2$estimate_pre)], collapse = "; "))
)
emit("results_correctly_signed_nonconjoint", sum(!figure_2$sign_diff),
     "Non-conjoint pairs signed in the same direction")

# "Of the 24 correctly signed estimates, 10 were significantly smaller in replication. Of
#  the four incorrectly signed estimates, three were significantly different - the foreign
#  aid misperceptions study and two of six estimates from the atomic aversion study."
emit("results_sig_smaller_of_24",
     sum(!figure_2$sign_diff & figure_2$estimate_diff < 0 & figure_2$p_diff < 0.05),
     "Correctly signed non-conjoint pairs significantly smaller in replication")
emit("results_incorrectly_signed", sum(figure_2$sign_diff),
     "Non-conjoint pairs signed in opposite directions")
emit("results_sig_among_incorrect", sum(figure_2$sign_diff & figure_2$p_diff < 0.05),
     "Incorrectly signed non-conjoint pairs whose difference is significant")
atomic <- figure_2 |> filter(str_detect(study_group, "Press"))
emit("results_atomic_sig_count", sum(atomic$sign_diff & atomic$p_diff < 0.05),
     "Atomic aversion pairs both incorrectly signed and significantly different")
emit("results_atomic_estimate_count", nrow(atomic), "Atomic aversion summary pairs")
emit_holds(
  "results_foreign_aid_significant",
  with(figure_2 |> filter(study_group_detail == "Foreign aid misperceptions"),
       sign_diff & p_diff < 0.05),
  "The foreign aid pair is incorrectly signed and significantly different"
)

# "Figure 3 plots the analogous information for the 41 conjoint estimates and their 41
#  replications, all of which are signed in the same direction. Of these, 35 of 41 were
#  smaller in replication (6 statistically significant differences) and 6 of 41 were
#  larger in replication (1 of 6 significant differences)."
emit("results_conjoint_pairs", nrow(figure_3), "Conjoint pairs plotted in Figure 3")
emit_holds("results_conjoint_same_sign", all(!figure_3$sign_diff),
           "Every conjoint pair is signed in the same direction")
emit("results_conjoint_smaller", sum(figure_3$estimate_diff < 0),
     "Conjoint pairs smaller in replication")
emit("results_conjoint_sig_among_smaller",
     sum(figure_3$estimate_diff < 0 & figure_3$p_diff < 0.05),
     "Conjoint pairs smaller in replication and significantly different")
emit("results_conjoint_larger", sum(figure_3$estimate_diff > 0),
     "Conjoint pairs larger in replication")
emit("results_conjoint_sig_among_larger",
     sum(figure_3$estimate_diff > 0 & figure_3$p_diff < 0.05),
     "Conjoint pairs larger in replication and significantly different")

# "Pooling across all 65 of 69 correctly signed pairs presented in Figures 2-3, the
#  replication estimates were, on average, 73% as large as the pre-COVID estimates. The 41
#  correctly signed estimates from the conjoint replication were, on average, 87% as large
#  as the original. The 24 of 28 correctly signed estimates from the other replications
#  were, on average, 49% as large as the pre-COVID summary effect sizes."
emit("results_pooled_correctly_signed", nrow(signed), "Correctly signed pairs across both figures")
emit("results_pooled_pairs", nrow(pairs), "Pairs across both figures")
emit("results_correspondence_overall", 100 * correspondence,
     "Mean ratio over the correctly signed pairs")
emit("results_correspondence_conjoint",
     100 * mean(figure_3$estimate_ycls / figure_3$estimate_pre),
     "Mean ratio over the conjoint pairs")
nonconjoint_signed <- figure_2 |> filter(!sign_diff)
emit("results_correspondence_nonconjoint",
     100 * mean(nonconjoint_signed$estimate_ycls / nonconjoint_signed$estimate_pre),
     "Mean ratio over the correctly signed non-conjoint pairs")
emit_holds("results_figures_2_3_reference", exists_float("figure_2", "figure_3"),
           "Cross-reference: Figures 2 and 3 are in the float inventory")

# Figure 2 and Figure 3 captions and notes ----

# "Comparison of 28 summary effect sizes across 11 studies (conjoint excluded). Notes:
#  ... Thirteen of 28 replication estimates were significantly different from their
#  pre-COVID benchmark at P < 0.05."
emit("figure_2_caption_pairs", nrow(figure_2), "Points plotted in Figure 2")
emit("figure_2_caption_studies", n_distinct(figure_2$study_group),
     "Distinct studies contributing a point to Figure 2")
emit("figure_2_sig_count", sum(figure_2$p_diff < 0.05),
     "Figure 2 pairs significantly different before adjustment")

# "Comparison of 41 summary effect sizes in conjoint experiments. Notes: ... Seven of 41
#  replication estimates were significantly different from their pre-COVID benchmark at
#  P < 0.05."
emit("figure_3_caption_pairs", nrow(figure_3), "Points plotted in Figure 3")
emit("figure_3_sig_count", sum(figure_3$p_diff < 0.05),
     "Figure 3 pairs significantly different before adjustment")

# Inattention: device metadata ----

# "In a separate Lucid survey fielded on 29 October, we filtered out respondents who
#  failed an ACQ at the beginning of the survey (the 'Easy' ACQ from Table 2)."
emit_holds("footnote_5_table_2_reference", exists_float("table_2"),
           "Cross-reference: Table 2 is in the float inventory")

# "Applying this approach across the 13 surveys used for the replication studies, we
#  estimate that the proportion of participants coming from web applications (rather than
#  internet browsers) ranged from 0.19 to 0.61, and the proportion of participants coming
#  from mobiles (rather than desktops or tablets) ranged from 0.31 to 0.73."
emit("device_surveys", nrow(by_survey), "Surveys in the per-survey device table")
emit("device_webapp_min", min(by_survey$webapp_share), "Smallest per-survey web-application share")
emit("device_webapp_max", max(by_survey$webapp_share), "Largest per-survey web-application share")
emit("device_mobile_min", min(by_survey$mobile_share), "Smallest per-survey mobile share")
emit("device_mobile_max", max(by_survey$mobile_share), "Largest per-survey mobile share")

# "Based on an additional sample of 63,245 respondents obtained from Lucid surveys fielded
#  prior to March 2020, we observe that the proportion of participants from both web
#  applications and mobiles was trending upward prior to the COVID-19 outbreak."
additional <- all_surveys |> filter(!replication_survey)
emit("device_additional_sample", sum(additional$n),
     "Respondents in the UserAgent surveys other than the thirteen reported here")
emit_holds(
  "device_additional_sample_period",
  all(additional$time < as.Date("2020-03-01")),
  paste("Additional surveys fielded on or after 1 March 2020:",
        paste(additional$time[additional$time >= as.Date("2020-03-01")], collapse = ", "))
)
emit_holds(
  "device_trending_upward",
  with(by_year |> filter(panel == "Respondents from web applications", year <= 2019) |>
         arrange(year), all(diff(mean_share) > 0)) &
    with(by_year |> filter(panel == "Respondents from mobile phones", year <= 2019) |>
           arrange(year), all(diff(mean_share) > 0)),
  "Both annual shares rise from 2018 to 2019, before the outbreak"
)
emit_holds("device_figure_4_reference", exists_float("figure_4"),
           "Cross-reference: Figure 4 is in the float inventory")

# "In the 2020 surveys, approximately 41% of respondents came from web applications (56%
#  from mobiles), an increase from 33% (56% from mobiles) in 2019 and just 13% (33% from
#  mobiles) in 2018."
year_share <- function(panel_name, yr) {
  by_year$mean_share[by_year$panel == panel_name & by_year$year == yr]
}
emit("device_2020_webapp", 100 * year_share("Respondents from web applications", 2020),
     "Mean web-application share over the 2020 UserAgent surveys")
emit("device_2020_mobile", 100 * year_share("Respondents from mobile phones", 2020),
     "Mean mobile share over the 2020 UserAgent surveys")
emit("device_2019_webapp", 100 * year_share("Respondents from web applications", 2019),
     "Mean web-application share over the 2019 UserAgent surveys")
emit("device_2019_mobile", 100 * year_share("Respondents from mobile phones", 2019),
     "Mean mobile share over the 2019 UserAgent surveys")
emit("device_2018_webapp", 100 * year_share("Respondents from web applications", 2018),
     "Mean web-application share over the 2018 UserAgent surveys")
emit("device_2018_mobile", 100 * year_share("Respondents from mobile phones", 2018),
     "Mean mobile share over the 2018 UserAgent surveys")

# "Pooling across the 13 surveys used for our replication studies, 97% of participants
#  from web applications were also on mobile devices and 72% on mobile devices arrived
#  from web applications. Those from web applications spent approximately 7 min less time
#  completing surveys than those from web browsers, who spent an average of 21.5 min.
#  Respondents from mobile devices spent roughly 6 min less time completing surveys than
#  subjects from nonmobile devices."
emit("device_overlap_mobile_given_webapp", 100 * dev_value("mobile_share_among_webapp"),
     "Share of web-application respondents who were also on a mobile device")
emit("device_overlap_webapp_given_mobile", 100 * dev_value("webapp_share_among_mobile"),
     "Share of mobile respondents who arrived from a web application")
emit("device_duration_gap_webapp",
     dev_value("duration_mean_browser") - dev_value("duration_mean_webapp"),
     "Browser mean duration less web-application mean duration, in minutes")
emit("device_duration_browser", dev_value("duration_mean_browser"),
     "Mean survey duration among respondents on an internet browser, in minutes")
emit("device_duration_gap_mobile",
     dev_value("duration_mean_nonmobile") - dev_value("duration_mean_mobile"),
     "Nonmobile mean duration less mobile mean duration, in minutes")

# "Additionally, in 2 of the 13 surveys we included ACQs of varying difficulty and found
#  those on web applications (or mobiles) were significantly less likely to pass the ACQs,
#  compared to those coming from browsers (or nonmobiles). These results are reported in
#  Table 2."
emit("device_acq_surveys", dev_value("surveys_with_acq"),
     "Surveys carrying at least one attention check question")
contrasts_2 <- table_2_cells |> filter(str_detect(column, "minus"))
emit_holds("device_acq_significance", all(contrasts_2$p.value < 0.05),
           paste("Largest p-value across the six Table 2 contrasts:",
                 round(max(contrasts_2$p.value), 3)))
emit_holds("device_table_2_reference", exists_float("table_2"),
           "Cross-reference: Table 2 is in the float inventory")

# Table 2 note ----

# "The 'Easy' and 'Medium' questions were novel ACQs that subjects completed after reading
#  a short news article (see Fig. C.9-C.10). ... This ACQ ... was passed by 87% of
#  respondents in the original study (see Fig. C.11)."
emit_holds("table_2_note_c9_c10_reference", exists_float("figure_c9", "figure_c10"),
           "Cross-reference: Figures C.9 and C.10 are in the float inventory")
emit("table_2_note_original_pass", 100 * dev_value("acq_pass_rate_peyton_original"),
     "Share passing the attention check in the Peyton (2020) original data")
emit_holds("table_2_note_c11_reference", exists_float("figure_c11"),
           "Cross-reference: Figure C.11 is in the float inventory")

# Figure 5 quantities stated in prose ----

# "Figure 5 shows that regardless of the approach used to classify subjects as attentive,
#  estimated treatment effects among the attentive are positive and significant. Among
#  those who passed the ACQ, the average effect of treatment was 0.39 (SE: 0.15). Among
#  those coming from browsers, the estimate was 0.33 (SE: 0.10), and among nonmobile users
#  it was 0.52 (SE: 0.12). Among those who failed the ACQ (estimate: 0.08, SE: 0.09), came
#  from a web application (estimate: -0.03, SE: 0.12), or used a mobile phone (estimate:
#  -0.04, SE: 0.10), estimated treatment effects were all close to zero and
#  nonsignificant."
f5 <- function(name, column) figure_5[[column]][figure_5$dataset == name]
emit_holds("figure_5_reference", exists_float("figure_5"),
           "Cross-reference: Figure 5 is in the float inventory")
attentive <- figure_5 |> filter(str_starts(dataset, "Attentive"))
emit_holds("figure_5_attentive_positive",
           all(attentive$estimate > 0) & all(attentive$p.value < 0.05),
           paste("Three attentive subgroups, largest p-value", round(max(attentive$p.value), 4)))
emit("figure_5_acq_pass_estimate", f5("Attentive: Passed ACQ", "estimate"),
     "First-stage estimate among those who passed the ACQ")
emit("figure_5_acq_pass_se", f5("Attentive: Passed ACQ", "std.error"),
     "Standard error among those who passed the ACQ")
emit("figure_5_browser_estimate", f5("Attentive: Internet browser", "estimate"),
     "First-stage estimate among browser respondents")
emit("figure_5_browser_se", f5("Attentive: Internet browser", "std.error"),
     "Standard error among browser respondents")
emit("figure_5_nonmobile_estimate", f5("Attentive: Non-mobile device", "estimate"),
     "First-stage estimate among nonmobile respondents")
emit("figure_5_nonmobile_se", f5("Attentive: Non-mobile device", "std.error"),
     "Standard error among nonmobile respondents")
emit("figure_5_acq_fail_estimate", f5("Inattentive: Failed ACQ", "estimate"),
     "First-stage estimate among those who failed the ACQ")
emit("figure_5_acq_fail_se", f5("Inattentive: Failed ACQ", "std.error"),
     "Standard error among those who failed the ACQ")
emit("figure_5_webapp_estimate", f5("Inattentive: Web-Application", "estimate"),
     "First-stage estimate among web-application respondents")
emit("figure_5_webapp_se", f5("Inattentive: Web-Application", "std.error"),
     "Standard error among web-application respondents")
emit("figure_5_mobile_estimate", f5("Inattentive: Mobile device", "estimate"),
     "First-stage estimate among mobile respondents")
emit("figure_5_mobile_se", f5("Inattentive: Mobile device", "std.error"),
     "Standard error among mobile respondents")
inattentive <- figure_5 |> filter(str_starts(dataset, "Inattentive"))
emit_holds("figure_5_inattentive_near_zero",
           all(abs(inattentive$estimate) < 0.1) & all(inattentive$p.value > 0.05),
           paste("Three inattentive subgroups, largest absolute estimate",
                 round(max(abs(inattentive$estimate)), 3),
                 "and smallest p-value", round(min(inattentive$p.value), 3)))

# The attentiveness accounting ----

# "Pooling across all replication studies, we find effect sizes were, on average, 73%
#  their pre-COVID magnitude. If 73% of respondents were attentive and 26% inattentive,
#  our replication estimate would, on average, match our pre-COVID benchmarks. ... Dividing
#  each of the COVID era summary estimates that we obtained by 0.70 yields an estimated
#  replication correspondence of 104% the pre-COVID effect sizes."
emit("inattention_correspondence", 100 * correspondence, "Mean ratio over the correctly signed pairs")
emit("inattention_attentive_share", 100 * correspondence,
     "The attentive share that would close the gap, which is the correspondence itself")
emit("inattention_inattentive_share", 100 * (1 - correspondence),
     "The complement of the attentive share")
emit("inattention_inflated_correspondence",
     100 * mean((signed$estimate_ycls / 0.70) / signed$estimate_pre),
     "Mean ratio after dividing each COVID-era estimate by 0.70")
emit_holds("inattention_figure_5_reference", exists_float("figure_5"),
           "Cross-reference: Figure 5 is in the float inventory")

# Figure 5 note ----

# "Estimates for the Lucid replication, fielded in May 2020, are presented for the full
#  sample, and each subgroup partition created by three different methods for classifying
#  attentive versus inattentive respondents. Pairwise correlations between these methods:
#  0.67 for nonmobile and browsers, 0.10 for non-mobiles and ACQ pass, and 0.09 for
#  browsers and ACQ pass. ... Peyton (2020) Appendix S5.8 reports 87% of respondents
#  passed their pretreatment ACQ. In our direct replication, 19% of respondents passed
#  this same ACQ."
emit("figure_5_note_field_month", 5,
     "The Peyton replication is Week 9, fielded in the fifth month of 2020")
emit("figure_5_note_corr_nonmobile_browser", dev_value("correlation_nonmobile_browser"),
     "Correlation between the nonmobile and browser classifications in Week 9")
emit("figure_5_note_corr_nonmobile_acq", dev_value("correlation_nonmobile_acq"),
     "Correlation between the nonmobile classification and ACQ pass in Week 9")
emit("figure_5_note_corr_browser_acq", dev_value("correlation_browser_acq"),
     "Correlation between the browser classification and ACQ pass in Week 9")
emit("figure_5_note_original_pass", 100 * dev_value("acq_pass_rate_peyton_original"),
     "Share passing the attention check in the Peyton (2020) original data")
emit("figure_5_note_replication_pass", 100 * dev_value("acq_pass_rate_week_9"),
     "Share passing the same attention check in the Week 9 replication")

# Discussion ----

# "We investigated by conducting 33 replications during the early COVID era of 12 published
#  experimental studies. ... Because these pre-COVID experiments were, with one exception,
#  successfully replicated, we infer that the pandemic does not pose a fundamental threat."
emit("discussion_replications", replication_count, "Replications, counted as in the abstract")
emit("discussion_studies", n_distinct(estimates$study_base),
     "Original studies, counted as in the abstract")
failures <- figure_2 |>
  summarise(all_wrong_sign = all(sign_diff), .by = study_group) |>
  filter(all_wrong_sign)
emit_holds("discussion_one_exception", nrow(failures) == 1,
           paste("Studies whose every summary pair is signed against the original:",
                 paste(failures$study_group, collapse = "; ")))

# Online Appendix A ----

# The appendix quotes pooled benchmarks that clean_summary_estimates.R also writes to
# text_pooled_benchmarks.csv. They are re-pooled here from the individual estimates, by
# the same inverse-variance weighting stated in the Results section, so that the two
# instruments reach them by different routes.
fe_pool <- function(d) {
  list(estimate = weighted.mean(d$estimate, w = 1 / d$std.error ^ 2),
       se = sqrt(1 / sum(1 / d$std.error ^ 2)))
}

unstd <- estimates |> filter(estimate_type == "Unstandardized")
std <- estimates |> filter(estimate_type == "Standardized")

pair_test <- function(a, b) {
  diff <- a$estimate - b$estimate
  se <- sqrt(a$std.error ^ 2 + b$std.error ^ 2)
  list(diff = diff, se = se, p = 2 * (1 - pnorm(abs(diff / se))))
}

# A.1: "Pooling across the pre-COVID studies, the summary effect size estimate is a 30
#  percentage point increase in support for Russian journalists. Our effect estimate of
#  25.5 points is 83% of this magnitude, and this difference of 5.5 percentage points is
#  not statistically significant (P = 0.16)."
russians <- figure_2 |> filter(study_group_detail == "Russian reporters")
emit("a1_precovid_summary", 100 * russians$estimate_pre,
     "Pooled pre-COVID summary effect, in percentage points")
emit("a1_replication_estimate", 100 * russians$estimate_ycls,
     "COVID-era summary effect, in percentage points")
emit("a1_relative", 100 * russians$estimate_ycls / russians$estimate_pre,
     "COVID-era estimate as a share of the pre-COVID benchmark")
emit("a1_difference", -100 * russians$estimate_diff,
     "Pre-COVID benchmark less the COVID-era estimate, in percentage points")
emit("a1_difference_p", russians$p_diff, "Two-sided p-value for that difference")

# A.2: "The estimated effect in our direct replication of 15 percentage points was
#  indistinguishable from the pre-COVID replication (16 percentage points). For the
#  COVID-specific experiment, the estimated treatment effect of 7 percentage points was
#  indistinguishable from zero, and smaller than both the pre-COVID replication
#  (difference of 9 percentage points, SE = 0.05, P = 0.02) and our direct replication
#  (difference of 8 percentage points, SE = 0.06, P = 0.09)."
framing <- unstd |> filter(study_base == "Tversky & Kaheneman (1981) - Cheap/Expensive")
fr_direct <- framing |> filter(study == "Replication", variant == "Original")
fr_covid <- framing |> filter(study == "Replication", variant == "Modified")
fr_ml <- framing |> filter(survey == "Many Labs (2018)")
emit_holds("a2_c1_c4_reference",
           exists_float("figure_c1", "figure_c2", "figure_c3", "figure_c4"),
           "Cross-reference: Figures C.1 to C.4 are in the float inventory")
emit("a2_direct_effect", 100 * fr_direct$estimate, "Direct replication effect, in percentage points")
emit("a2_precovid_effect", 100 * fr_ml$estimate, "Many Labs effect, in percentage points")
emit("a2_covid_effect", 100 * fr_covid$estimate,
     "COVID-specific replication effect, in percentage points")
fr_vs_ml <- pair_test(fr_ml, fr_covid)
fr_vs_direct <- pair_test(fr_direct, fr_covid)
emit("a2_covid_vs_precovid_diff", 100 * fr_vs_ml$diff,
     "Many Labs less COVID-specific, in percentage points")
emit("a2_covid_vs_precovid_se", fr_vs_ml$se, "Standard error of that difference")
emit("a2_covid_vs_precovid_p", fr_vs_ml$p, "Two-sided p-value for that difference")
emit("a2_covid_vs_direct_diff", 100 * fr_vs_direct$diff,
     "Direct replication less COVID-specific, in percentage points")
emit("a2_covid_vs_direct_se", fr_vs_direct$se, "Standard error of that difference")
emit("a2_covid_vs_direct_p", fr_vs_direct$p, "Two-sided p-value for that difference")
fr_pre_pool <- fe_pool(framing |> filter(study == "Pre-COVID"))
fr_covid_pool <- fe_pool(framing |> filter(study == "Replication"))
emit("a2_summary_pre", fr_pre_pool$estimate, "Pooled pre-COVID summary effect")
emit("a2_summary_pre_se", fr_pre_pool$se, "Standard error of the pooled pre-COVID summary")
emit("a2_summary_covid", fr_covid_pool$estimate, "Pooled COVID-era summary effect")
emit("a2_summary_covid_se", fr_covid_pool$se, "Standard error of the pooled COVID-era summary")
emit_holds(
  "a2_summaries_significant",
  2 * (1 - pnorm(abs(fr_pre_pool$estimate / fr_pre_pool$se))) < 0.01 &
    2 * (1 - pnorm(abs(fr_covid_pool$estimate / fr_covid_pool$se))) < 0.01,
  "Both pooled summaries are significant at the 0.01 level"
)
emit("a2_correspondence", 100 * fr_covid_pool$estimate / fr_pre_pool$estimate,
     "COVID-era pooled summary as a share of the pre-COVID pooled summary")

# A.3: "The summary effect size for our five replications is 0.15 (SE = 0.02, P < 0.01),
#  approximately 50% the size of the summary effect size for the five pre-COVID
#  experiments (summary effect size: 0.29, SE = 0.01, P < 0.01). ... (difference: 0.14,
#  SE = 0.02, P < 0.01), all COVID-era replication estimates are statistically
#  distinguishable from zero, and in the expected direction."
disease <- unstd |> filter(study_base == "Tversky & Kaheneman (1981) - Gain/Loss")
disease_pre <- disease |> filter(study == "Pre-COVID")
disease_covid <- disease |> filter(study == "Replication")
d_pre <- fe_pool(disease_pre)
d_covid <- fe_pool(disease_covid)
emit("a3_replications", nrow(disease_covid), "COVID-era Asian disease replications pooled")
emit("a3_precovid_studies", nrow(disease_pre), "Pre-COVID Asian disease experiments pooled")
emit("a3_covid_summary", d_covid$estimate, "Pooled COVID-era summary effect")
emit("a3_covid_se", d_covid$se, "Standard error of the pooled COVID-era summary")
emit("a3_relative", 100 * d_covid$estimate / d_pre$estimate,
     "COVID-era pooled summary as a share of the pre-COVID pooled summary")
emit("a3_pre_summary", d_pre$estimate, "Pooled pre-COVID summary effect")
emit("a3_pre_se", d_pre$se, "Standard error of the pooled pre-COVID summary")
emit("a3_difference", d_pre$estimate - d_covid$estimate, "Pre-COVID less COVID-era pooled summary")
emit("a3_difference_se", sqrt(d_pre$se ^ 2 + d_covid$se ^ 2), "Standard error of that difference")
emit_holds("a3_all_distinguishable",
           all(disease_covid$p.value < 0.05) & all(disease_covid$estimate > 0),
           paste("Five COVID-era estimates, largest p-value",
                 round(max(disease_covid$p.value), 4)))

# A.4: "The summary effect size for the experimental estimates from CAWI surveys is 0.44
#  (SE = 0.02, P < 0.01), approximately 44% the size of the summary effect sizes for the
#  CAPI (1.00, SE = 0.01, P < 0.01) and PAPI (1.05, SE = 0.01, P < 0.01) surveys from the
#  GSS. Within the CAWI surveys, however, our experimental estimates (summary effect size:
#  0.43, SE = 0.02, P < 0.01) are indistinguishable from the pre-COVID estimates (0.46,
#  SE = 0.05, P < 0.01) from Huber and Paris (2013)."
welfare <- std |> filter(study_base == "Smith (1987)")
cawi <- welfare |> filter(mode == "Computer-assisted web interviews", type == "Experimental")
capi <- welfare |> filter(mode == "Computer-assisted personal interviews")
papi <- welfare |> filter(mode == "Paper and pencil interviews")
huber <- welfare |> filter(str_detect(survey, "Huber"))
ycls_exp <- cawi |> filter(study == "Replication")
benchmark_1986 <- welfare |> filter(str_detect(survey, "Huber") | survey == "GSS 1986")
p_cawi <- fe_pool(cawi); p_capi <- fe_pool(capi); p_papi <- fe_pool(papi)
p_huber <- fe_pool(huber); p_exp <- fe_pool(ycls_exp); p_1986 <- fe_pool(benchmark_1986)
emit_holds("a4_within_subject_weeks",
           setequal(welfare$survey[welfare$type == "Observational"], c("Week 5", "Week 9")),
           paste("Within-subject welfare replications:",
                 paste(sort(welfare$survey[welfare$type == "Observational"]), collapse = ", ")))
emit("a4_cawi_summary", p_cawi$estimate, "Pooled experimental CAWI summary effect")
emit("a4_cawi_se", p_cawi$se, "Standard error of the pooled CAWI summary")
emit("a4_cawi_relative", 100 * p_cawi$estimate / p_capi$estimate,
     "CAWI pooled summary as a share of the CAPI pooled summary")
emit("a4_capi_summary", p_capi$estimate, "Pooled CAPI summary effect")
emit("a4_capi_se", p_capi$se, "Standard error of the pooled CAPI summary")
emit("a4_papi_summary", p_papi$estimate, "Pooled PAPI summary effect")
emit("a4_papi_se", p_papi$se, "Standard error of the pooled PAPI summary")
emit("a4_experimental_summary", p_exp$estimate, "Pooled COVID-era experimental summary effect")
emit("a4_experimental_se", p_exp$se, "Standard error of that pooled summary")
emit("a4_huber_summary", p_huber$estimate, "Pooled Huber and Paris summary effect")
emit("a4_huber_se", p_huber$se, "Standard error of the Huber and Paris pooled summary")
emit("a4_benchmark_summary", p_1986$estimate,
     "Pooled summary over GSS 1986 and the two Huber and Paris replications")
emit("a4_benchmark_se", p_1986$se, "Standard error of that pooled benchmark")
emit("a4_benchmark_relative", 100 * p_exp$estimate / p_1986$estimate,
     "COVID-era experimental summary as a share of the 1986 benchmark")
emit_holds("a4_all_distinguishable",
           all(ycls_exp$p.value < 0.05) & all(ycls_exp$estimate > 0),
           paste("Ten COVID-era welfare estimates, largest p-value",
                 round(max(ycls_exp$p.value), 4)))

# A.4 footnote 3: "CAWI chi-squared: 12.72, P = 0.31, CAPI chi-squared: 17.21, P = 0.03,
#  PAPI chi-squared: 85.19, P < 0.01"
cochran_q <- function(d) {
  w <- 1 / d$std.error ^ 2
  q <- sum(w * (d$estimate - weighted.mean(d$estimate, w)) ^ 2)
  list(q = q, p = pchisq(q, df = nrow(d) - 1, lower.tail = FALSE))
}
q_cawi <- cochran_q(cawi); q_capi <- cochran_q(capi); q_papi <- cochran_q(papi)
emit("a4_footnote_3_cawi_q", q_cawi$q, "Cochran's Q across the CAWI estimates")
emit("a4_footnote_3_cawi_p", q_cawi$p, "p-value for that heterogeneity test")
emit("a4_footnote_3_capi_q", q_capi$q, "Cochran's Q across the CAPI estimates")
emit("a4_footnote_3_capi_p", q_capi$p, "p-value for that heterogeneity test")
emit("a4_footnote_3_papi_q", q_papi$q, "Cochran's Q across the PAPI estimates")
emit_holds("a4_footnote_3_papi_p", q_papi$p < 0.01,
           paste("PAPI heterogeneity p-value:", format(q_papi$p, digits = 3)))
emit_holds("a4_week_13_direct",
           "Week 13" %in% welfare$survey[welfare$study == "Replication"],
           "Week 13 is among the welfare replications")

# A.5: "Table A.5 provides a summary of differences between the original study and the
#  replications by treatment arm."
emit_holds("a5_table_reference", exists_float("appendix_table_a5"),
           "Cross-reference: the appendix's float inventory holds no Table A.5")
druckman <- unstd |>
  filter(study_base == "Druckman (2001)", str_detect(x_pid3, "Democrats|Republicans"))
druckman_a <- druckman |> filter(str_detect(AD_Z_party_sure_thing, "Program A"))
emit_holds("a5_program_a_significant",
           all(druckman_a$p.value < 0.05) & all(druckman_a$estimate > 0),
           paste("Program A arms significant at 0.05:",
                 sum(druckman_a$p.value < 0.05), "of", nrow(druckman_a),
                 "| exceptions:",
                 paste(paste(druckman_a$survey[druckman_a$p.value >= 0.05],
                             druckman_a$x_pid3[druckman_a$p.value >= 0.05]), collapse = "; ")))
druckman_summary <- appendix_cells |> filter(appendix_table == "Table 1", column == "YCLS summary")
cross_party <- druckman_summary |>
  filter((str_detect(row, "^Republicans' Program") & str_detect(row, "Democrats$")) |
           (str_detect(row, "^Democrats' Program") & str_detect(row, "Republicans$")))
emit_holds("a5_partisan_attenuation", all(cross_party$p.value > 0.05),
           paste("Cross-party arms, smallest p-value", round(min(cross_party$p.value), 3)))
druckman_ratio <- read_csv(file.path(out_dir, "appendix_table_ratios.csv"),
                           show_col_types = FALSE) |>
  filter(appendix_table == "Table 1")
emit_holds("a5_all_expected_direction", all(druckman_summary$estimate > 0),
           paste("Six replication summaries, smallest", round(min(druckman_summary$estimate), 3)))

# A.6: "The estimated treatment effect in the original study is an increase in support for
#  foreign aid of 0.21 (SE = 0.06, P =< 0.01). The estimated treatment effect in the
#  replication study is a decrease in support for foreign aid by 0.05 (SE = 0.06,
#  P = 0.40). The estimate from the original study is therefore 0.26 units larger - in the
#  opposite direction - than the replication study (SE = 0.09, P < 0.01)."
gilens_pre <- std |> filter(study_base == "Gilens (2001)", study == "Pre-COVID")
gilens_rep <- std |> filter(study_base == "Gilens (2001)", study == "Replication")
gilens_diff <- pair_test(gilens_pre, gilens_rep)
emit("a6_original_estimate", gilens_pre$estimate, "Original study estimate")
emit("a6_original_se", gilens_pre$std.error, "Original study standard error")
emit("a6_replication_estimate", -gilens_rep$estimate,
     "Size of the replication's decrease in support")
emit("a6_replication_se", gilens_rep$std.error, "Replication standard error")
emit("a6_replication_p", gilens_rep$p.value, "Replication p-value")
emit("a6_difference", gilens_diff$diff, "Original less replication")
emit("a6_difference_se", gilens_diff$se, "Standard error of that difference")
emit_holds("a6_only_failure",
           sum(figure_2$sign_diff & figure_2$p_diff < 0.05 &
                 figure_2$study_group == "Gilens (2001)") == 1,
           "The foreign aid pair is incorrectly signed and significantly different")

# A.7: "The estimated treatment effect is 0.39 (SE = 0.04, P < 0.01) in the direct
#  replication and 0.38 in the COVID-specific replication (SE = 0.04, P < 0.01). The
#  estimated treatment effect for the COVID-specific replication is about 0.01 points
#  smaller than the direct replication (SE = 0.04, P = 0.46). The direct replication is
#  approximately 60% the size of the pre-COVID benchmark (difference of 0.25 points,
#  SE = 0.04, P < 0.01)."
knobe <- unstd |> filter(study_base == "Knobe (2003)")
kn_direct <- knobe |> filter(study == "Replication", variant == "Original")
kn_covid <- knobe |> filter(study == "Replication", variant == "Modified")
kn_ml <- knobe |> filter(survey == "Many Labs (2018)")
kn_pre <- fe_pool(knobe |> filter(study == "Pre-COVID"))
kn_vs_direct <- pair_test(kn_direct, kn_covid)
kn_vs_pre <- pair_test(kn_ml, kn_direct)
emit("a7_ml_effect", 100 * kn_ml$estimate, "Many Labs effect, in percentage points")
emit_holds("a7_c5_c8_reference",
           exists_float("figure_c5", "figure_c6", "figure_c7", "figure_c8"),
           "Cross-reference: Figures C.5 to C.8 are in the float inventory")
emit("a7_direct_effect", kn_direct$estimate, "Direct replication effect")
emit("a7_direct_se", kn_direct$std.error, "Direct replication standard error")
emit("a7_covid_effect", kn_covid$estimate, "COVID-specific replication effect")
emit("a7_covid_se", kn_covid$std.error, "COVID-specific replication standard error")
emit("a7_covid_vs_direct_diff", kn_vs_direct$diff, "Direct less COVID-specific")
emit("a7_covid_vs_direct_se", kn_vs_direct$se, "Standard error of that difference")
emit("a7_covid_vs_direct_p", kn_vs_direct$p, "Two-sided p-value for that difference")
emit("a7_relative_precovid", 100 * kn_direct$estimate / kn_pre$estimate,
     "Direct replication as a share of the pooled pre-COVID benchmark")
emit("a7_difference_precovid", kn_vs_pre$diff, "Many Labs less the direct replication")
emit("a7_difference_precovid_se", kn_vs_pre$se, "Standard error of that difference")
knobe_rep <- knobe |> filter(study == "Replication")
emit_holds("a7_all_distinguishable",
           all(knobe_rep$estimate > 0) & all(knobe_rep$p.value < 0.05),
           paste("Two COVID-era estimates, largest p-value",
                 format(max(knobe_rep$p.value), digits = 3)))

# A.8: "In the original study, the 90/70 condition caused an increase in the proportion of
#  subject that preferred the nuclear option by about 37 percentage points relative to the
#  90/90 condition. The estimated effect of the 90/45 condition, relative to the 90/90
#  condition, was 51 percentage points. Similarly, the 90/70 condition caused an increase
#  in the proportion of subjects that approved of the nuclear option by about 17
#  percentage points, and the 90/45 condition caused an increase of about 27 percentage
#  points."
psv <- unstd |> filter(str_detect(study_group, "Press et al"))
psv_cell <- function(survey_name, term_name, outcome_name) {
  row <- psv |> filter(survey == survey_name, term == term_name,
                       outcome_group == outcome_name)
  stopifnot(nrow(row) == 1)
  row
}
# "1) a 90/90 condition in which the nuclear and conventional strike both had a 90%
#  chance of success; 2) a 90/70 condition in which the conventional strike had a 75%
#  chance of success; 3) a 90/45 condition in which the conventional strike had a 45%
#  chance of success."
conventional_rate <- function(label) {
  as.numeric(str_extract(unique(psv$term[psv$term == label]), "\\d+$"))
}
emit("a8_9090_success", 90,
     "The 90/90 condition's conventional success rate, which its label states directly")
emit("a8_9070_success", conventional_rate("90/70"),
     "The conventional success rate the deposited condition label 90/70 names")
emit("a8_9045_success", conventional_rate("90/45"),
     "The conventional success rate the deposited condition label 90/45 names")
emit("a8_original_9070_prefer",
     100 * psv_cell("Press et al. (2013)", "90/70", "Prefer Nuclear Use")$estimate,
     "Original study 90/70 effect on preferring the nuclear option, in percentage points")
emit("a8_original_9045_prefer",
     100 * psv_cell("Press et al. (2013)", "90/45", "Prefer Nuclear Use")$estimate,
     "Original study 90/45 effect on preferring the nuclear option, in percentage points")
emit("a8_original_9070_approve",
     100 * psv_cell("Press et al. (2013)", "90/70", "Approve Nuclear Use")$estimate,
     "Original study 90/70 effect on approving the nuclear option, in percentage points")
emit("a8_original_9045_approve",
     100 * psv_cell("Press et al. (2013)", "90/45", "Approve Nuclear Use")$estimate,
     "Original study 90/45 effect on approving the nuclear option, in percentage points")
psv_original <- psv |> filter(survey == "Press et al. (2013)", !is.na(outcome_group))
emit_holds(
  "a8_monotonic",
  all(psv_original$estimate[psv_original$term == "90/45"] >
        psv_original$estimate[psv_original$term == "90/70"]),
  "In the original study the 90/45 effect exceeds the 90/70 effect on both outcomes"
)
emit_holds("a8_table_2_reference", exists_float("appendix_table_2"),
           "Cross-reference: appendix Table 2 is in the float inventory")
psv_weeks_approve <- psv |>
  filter(str_detect(survey, "Week"), outcome_group == "Approve Nuclear Use")
emit_holds(
  "a8_approve_opposite_sign",
  mean(psv_weeks_approve$estimate < 0 & psv_weeks_approve$p.value > 0.05) >= 2 / 3,
  paste("Week-level approve estimates negative and non-significant:",
        sum(psv_weeks_approve$estimate < 0 & psv_weeks_approve$p.value > 0.05),
        "of", nrow(psv_weeks_approve))
)
abp_retro <- unstd |>
  filter(str_detect(study_group, "retrospective"), survey == "Aronow et al. (2019)")
emit("a8_abp_retrospective_approve",
     -100 * abp_retro$estimate[abp_retro$outcome_group == "Approve Strike"],
     "Size of the ABP replication's reduction in approval, in percentage points")
emit("a8_abp_retrospective_ethical",
     -100 * abp_retro$estimate[abp_retro$outcome_group == "Ethical Strike"],
     "Size of the ABP replication's reduction in judging the strike ethical, in percentage points")
emit_holds("a8_table_3_reference", exists_float("appendix_table_3"),
           "Cross-reference: appendix Table 3 is in the float inventory")
prefer_pairs <- figure_2 |> filter(str_detect(study_group_detail, "Prefer Nukes"))
emit_holds("a8_prefer_smaller_significant",
           all(prefer_pairs$p_diff < 0.05) & all(prefer_pairs$estimate_diff < 0) &
             all(prefer_pairs$estimate_ycls > 0),
           paste("Prefer Nuclear Use pairs, largest p-value",
                 format(max(prefer_pairs$p_diff), digits = 3)))

# A.9: "In total, there are 81 estimated AMCEs in Figure A.10 - 41 for the original study
#  and 41 for the replication. ... Only one of 41 replication estimates is signed in the
#  opposite direction ... the AMCE for Gardener is 0.02 points in the original study and
#  approximately zero in the replication ... The majority of the replication estimates
#  (27 of 41) are smaller in magnitude than the original estimates."
conjoint <- estimates |> filter(study_base == "Hainmueller & Hopkins (2015)")
conjoint_wide <- conjoint |>
  select(level, study, estimate, std.error, p.value) |>
  pivot_wider(names_from = study, values_from = c(estimate, std.error, p.value))
emit("a9_country_levels",
     n_distinct(conjoint$level[conjoint$attribute == "country"]) + 1,
     "Country levels plotted plus the omitted reference level")
emit("a9_gender_levels",
     n_distinct(conjoint$level[conjoint$attribute == "gender"]) + 1,
     "Gender levels plotted plus the omitted reference level")
emit("a9_male_effect", -100 * conjoint$estimate[conjoint$level == "Male" &
                                                  conjoint$study == "Replication"],
     "Size of the Male AMCE in the replication, in percentage points")
emit("a9_total_amces", nrow(conjoint), "AMCEs plotted in Figure A.10")
emit("a9_amces_original", sum(conjoint$study == "Pre-COVID"), "AMCEs from the original study")
emit("a9_amces_replication", sum(conjoint$study == "Replication"), "AMCEs from the replication")
emit("a9_opposite_sign_count",
     sum(sign(conjoint_wide$`estimate_Pre-COVID`) != sign(conjoint_wide$estimate_Replication)),
     "Attribute levels whose replication estimate is signed against the original")
emit("a9_gardener_original",
     conjoint_wide$`estimate_Pre-COVID`[conjoint_wide$level == "Gardener"],
     "Original study AMCE for Gardener")
emit_holds("a9_gardener_not_significant",
           with(conjoint_wide |> filter(level == "Gardener"),
                `p.value_Pre-COVID` > 0.05 & p.value_Replication > 0.05),
           "Neither Gardener estimate is distinguishable from zero")
# Almost every AMCE is negative, so "smaller" here is the signed comparison rather than
# the comparison of magnitudes the main text makes about the same 41 pairs.
emit("a9_smaller_count",
     sum(conjoint_wide$estimate_Replication < conjoint_wide$`estimate_Pre-COVID`),
     "Replication AMCEs below the original on the signed scale")
emit("a9_footnote_4_fdr", sum(figure_3$p_adjust < 0.05),
     "Conjoint differences significant after controlling the false discovery rate")

# A.10: "Across all six fake news stories, the authors found ... average treatment effects
#  ranging from -0.24 scale points on the low end to -0.95 scale points on the high end.
#  ... All replication estimates, ranging from -0.04 to -0.67, are uniformly smaller then
#  those in the original study, but all are correctly signed."
fake <- std |> filter(study_base == "Porter et al. (2018)")
fake_pre <- fake |> filter(study == "Pre-COVID")
fake_rep <- fake |> filter(study == "Replication")
emit("a10_stories", n_distinct(fake$outcome), "Fake news stories")
emit("a10_original_low", -min(fake_pre$estimate), "Smallest original effect, signed as the text does")
emit("a10_original_high", -max(fake_pre$estimate), "Largest original effect, signed as the text does")
emit("a10_replication_n", by_survey$n[by_survey$week == "YCLS Week 4"],
     "Respondents in the Week 4 fake news replication")
emit("a10_replication_low", -min(fake_rep$estimate),
     "Smallest replication effect, signed as the text does")
emit("a10_replication_high", -max(fake_rep$estimate),
     "Largest replication effect, signed as the text does")
fake_pairs <- figure_2 |> filter(study_group == "Porter et al. (2018)")
emit_holds("a10_all_smaller",
           all(abs(fake_pairs$estimate_ycls) < abs(fake_pairs$estimate_pre)) &
             all(!fake_pairs$sign_diff),
           "All six replication estimates are smaller in magnitude and correctly signed")
emit("a10_footnote_5_significant", sum(fake_pairs$p_diff < 0.05),
     "Fake news differences significant before adjustment")
emit_holds(
  "a10_footnote_5_named",
  setequal(fake_pairs$study_group_detail[fake_pairs$p_diff < 0.05],
           c("Podesta", "Sex trafficking")),
  paste("Significantly different stories:",
        paste(sort(fake_pairs$study_group_detail[fake_pairs$p_diff < 0.05]), collapse = ", "))
)

# A.11: "All replication estimates are in the expected direction when compared to the
#  original study. Although all 5 replication estimates are smaller in magnitude than
#  those in the original study, none of these differences are statistically
#  distinguishable from zero."
inequality <- figure_2 |> filter(study_group == "Trump & White (2018)")
emit_holds("a11_expected_direction", all(!inequality$sign_diff),
           "All five replication estimates are signed as the original")
emit("a11_all_smaller",
     sum(abs(inequality$estimate_ycls) < abs(inequality$estimate_pre)),
     "Replication estimates smaller in magnitude than the original")
emit_holds("a11_none_significant", all(inequality$p_diff > 0.05),
           paste("Smallest p-value across the five differences",
                 round(min(inequality$p_diff), 3)))

# A.12: "We conducted a direct replication of Experiment 3 in the original study on a
#  sample of 1,424 respondents in May 2020. ... The estimated treatment effect on trust in
#  government in the replication is statistically distinguishable from zero, and in the
#  expected direction. However, this estimate is significantly smaller in magnitude than
#  all of the estimates in the original study. The estimated treatment effects on support
#  for redistribution are indistinguishable from zero in the replication."
trust <- std |> filter(study_base == "Peyton (2020)")
trust_pre <- trust |> filter(study == "Pre-COVID")
trust_rep <- trust |> filter(study == "Replication")
emit("a12_replication_n", by_survey$n[by_survey$week == "YCLS Week 9"],
     "Respondents in the Week 9 trust replication")
emit_holds("a12_original_trust_significant",
           all(trust_pre$p.value[trust_pre$outcome == "Trust in Government"] < 0.05),
           paste("Three original trust estimates, largest p-value",
                 format(max(trust_pre$p.value[trust_pre$outcome == "Trust in Government"]),
                        digits = 3)))
emit_holds("a12_original_redistribution_null",
           all(trust_pre$p.value[trust_pre$outcome == "Support for Redistribution"] > 0.05),
           paste("Three original redistribution estimates, smallest p-value",
                 round(min(trust_pre$p.value[trust_pre$outcome == "Support for Redistribution"]), 3)))
emit_holds("a12_replication_trust_significant",
           with(trust_rep |> filter(outcome == "Trust in Government"),
                p.value < 0.05 & estimate > 0),
           "The replication's trust estimate is positive and significant")
trust_pair <- figure_2 |> filter(study_group_detail == "Trust in Government")
emit_holds("a12_replication_smaller", trust_pair$p_diff < 0.05 & trust_pair$estimate_diff < 0,
           paste("Trust difference p-value", format(trust_pair$p_diff, digits = 3)))
emit_holds("a12_replication_redistribution_null",
           with(trust_rep |> filter(outcome == "Support for Redistribution"), p.value > 0.05),
           "The replication's redistribution estimate is indistinguishable from zero")

# Online Appendix B ----

# "These estimates are presented below for the pooled sample of respondents across all 13
#  surveys that we conducted between March and July 2020."
emit("b_surveys", nrow(by_survey), "Surveys pooled in the covariate distributions")

# Corrigendum ----

# "Correcting these mistakes affects Figures 2-3 and the first paragraph on p. 6 in the
#  published article. All point estimates, standard errors, and substantive conclusions
#  are unchanged."
emit_holds("corrigendum_scope", exists_float("figure_2", "figure_3"),
           "Cross-reference: the two figures the corrigendum names are in the float inventory")
emit_holds(
  "corrigendum_conclusions_unchanged",
  all(!figure_3$sign_diff) & sum(!figure_2$sign_diff) == 24 &
    round(100 * correspondence) == 73,
  "The sign pattern and the 73 per cent correspondence are what the corrigendum leaves untouched"
)

# "Of the 24 correctly signed estimates, 11 were significantly smaller in replication. Of
#  the four incorrectly signed estimates, three were significantly different - the foreign
#  aid misperceptions study and two of six estimates from the atomic aversion study."
emit("corrigendum_correctly_signed", sum(!figure_2$sign_diff),
     "Non-conjoint pairs signed in the same direction")
emit("corrigendum_sig_smaller_of_24",
     sum(!figure_2$sign_diff & figure_2$estimate_diff < 0 & figure_2$p_diff < 0.05),
     "Correctly signed non-conjoint pairs significantly smaller in replication")
emit("corrigendum_incorrectly_signed", sum(figure_2$sign_diff),
     "Non-conjoint pairs signed in opposite directions")
emit("corrigendum_sig_among_incorrect", sum(figure_2$sign_diff & figure_2$p_diff < 0.05),
     "Incorrectly signed non-conjoint pairs whose difference is significant")
emit("corrigendum_atomic_sig_count", sum(atomic$sign_diff & atomic$p_diff < 0.05),
     "Atomic aversion pairs both incorrectly signed and significantly different")
emit("corrigendum_atomic_estimate_count", nrow(atomic), "Atomic aversion summary pairs")

# "Figure 3 plots the analogous information for the 41 conjoint estimates and their 41
#  replications, all of which are signed in the same direction. Of these, 35 of 41 were
#  smaller in replication (11 statistically significant differences) and 6 of 41 were
#  larger in replication (1 of 6 significant differences)."
emit("corrigendum_conjoint_pairs", nrow(figure_3), "Conjoint pairs plotted")
emit("corrigendum_conjoint_smaller", sum(figure_3$estimate_diff < 0),
     "Conjoint pairs smaller in replication")
emit("corrigendum_conjoint_sig_among_smaller",
     sum(figure_3$estimate_diff < 0 & figure_3$p_diff < 0.05),
     "Conjoint pairs smaller in replication and significantly different")
emit("corrigendum_conjoint_larger", sum(figure_3$estimate_diff > 0),
     "Conjoint pairs larger in replication")
emit("corrigendum_conjoint_sig_among_larger",
     sum(figure_3$estimate_diff > 0 & figure_3$p_diff < 0.05),
     "Conjoint pairs larger in replication and significantly different")

# "Comparison of 28 summary effect sizes across 11 studies (conjoint excluded). Notes:
#  ... 14 of 28 replication estimates were significantly different from their pre-COVID
#  benchmark at p < 0.05, and 13 of these (denoted by square shaped points) remained
#  statistically significant after adjusting for multiple comparisons."
emit("corrigendum_figure_1_caption_pairs", nrow(figure_2), "Points plotted in the corrected Figure 2")
emit("corrigendum_figure_1_caption_studies", n_distinct(figure_2$study_group),
     "Distinct studies contributing a point")
emit("corrigendum_figure_1a_note_sig", sum(figure_2$p_diff < 0.05),
     "Non-conjoint pairs significantly different before adjustment, as the reprinted original note states")
emit("corrigendum_figure_1b_note_sig", sum(figure_2$p_diff < 0.05),
     "Non-conjoint pairs significantly different before adjustment")
emit("corrigendum_figure_1b_note_fdr", sum(figure_2$p_adjust < 0.05),
     "Non-conjoint pairs still significant after controlling the false discovery rate")

# "Comparison of 41 summary effect sizes in conjoint experiments. Notes: ... 12 of 41
#  replication estimates were significantly different from their pre-COVID benchmark at
#  p < 0.05, and 7 of these (denoted by square shaped points) remained statistically
#  significant after adjusting for multiple comparisons."
emit("corrigendum_figure_2_caption_pairs", nrow(figure_3), "Points plotted in the corrected Figure 3")
emit("corrigendum_figure_2a_note_sig", sum(figure_3$p_diff < 0.05),
     "Conjoint pairs significantly different before adjustment, as the reprinted original note states")
emit("corrigendum_figure_2b_note_sig", sum(figure_3$p_diff < 0.05),
     "Conjoint pairs significantly different before adjustment")
emit("corrigendum_figure_2b_note_fdr", sum(figure_3$p_adjust < 0.05),
     "Conjoint pairs still significant after controlling the false discovery rate")

# "The replication archive has been updated so that the code used to generate Figures 2-3
#  in Peyton, Coppock and Huber (2021) now produces the correct versions shown here in
#  Figures 1-2."
emit_holds(
  "corrigendum_archive_updated",
  sum(figure_2$p_diff < 0.05) == 14 & sum(figure_3$p_diff < 0.05) == 12,
  "The deposited code, run through this pipeline, gives the corrected counts rather than the article's"
)

# What each wordless figure plots ----
# A figure that prints no numbers still states a checkable quantity: the number of
# estimates it draws. These blocks print what the rewrite commits to each float.

emit("plotted_figure_2", nrow(figure_2), "Points in the Figure 2 plot data")
emit("plotted_figure_3", nrow(figure_3), "Points in the Figure 3 plot data")
emit("plotted_figure_5", nrow(figure_5), "Estimates in the Figure 5 plot data")

plotted <- function(id, d, label) emit(id, nrow(d), label)
plotted("plotted_figure_a1", unstd |> filter(study_base == "Hyman & Sheatsley (1950)"),
        "Unstandardized estimates for the Russian reporters study")
plotted("plotted_figure_a2", framing, "Unstandardized estimates for the cheap versus expensive study")
plotted("plotted_figure_a3", disease, "Unstandardized estimates for the Asian disease study")
plotted("plotted_figure_a4", welfare, "Standardized estimates for the welfare study")
plotted("plotted_figure_a5", druckman,
        "Unstandardized Druckman estimates for the Democrat and Republican panels")
plotted("plotted_figure_a6", std |> filter(study_base == "Gilens (2001)"),
        "Standardized estimates for the foreign aid study")
plotted("plotted_figure_a7", knobe, "Unstandardized estimates for the intentionality study")
plotted("plotted_figure_a8", unstd |> filter(str_detect(study_group, "prospective")),
        "Unstandardized estimates for the prospective atomic aversion experiment")
plotted("plotted_figure_a9", unstd |> filter(str_detect(study_group, "retrospective")),
        "Unstandardized estimates for the retrospective atomic aversion experiment")
plotted("plotted_figure_a10", conjoint, "AMCEs for the conjoint study")
plotted("plotted_figure_a11", fake, "Standardized estimates for the fake news study")
plotted("plotted_figure_a12", std |> filter(study_base == "Trump & White (2018)"),
        "Standardized estimates for the inequality study")
plotted("plotted_figure_a13", trust, "Standardized estimates for the trust study")
