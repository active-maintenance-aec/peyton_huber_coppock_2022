# peyton_huber_coppock_2022/ground_truth/extract_archive_values.R
# Output: ground_truth/archive_values.csv
# Depends on: original/ (the deposited archive), maintained/helpers.R
# Description: The deposit's own answer, so that the ground truth's value_script column
#   is generated rather than typed. The deposited code is run end to end in a scratch
#   directory of symlinks, with the three repairs it needs to execute at all and with
#   nothing else changed, and the objects it leaves behind are written out.
#
#   The three repairs are exactly the ones the report describes: rmeta::meta.summaries()
#   is unavailable, lemon no longer re-exports position_dodgev(), and the final
#   summarise of appendix_section_a.R calls paste() on a column that varies within its
#   group, which dplyr now rejects and which stops the script before it writes the
#   summary effect sizes that manuscript.R reads. They are repairs to make the code run.
#   The analysis correction the maintained rewrite makes to the prospective atomic
#   aversion pooling is deliberately NOT applied here, because this file records what
#   the deposit produces, and the difference between the two is the finding.

library(here)
here::i_am("ground_truth/extract_archive_values.R")

source(here::here("maintained", "helpers.R"))

data_dir <- here::here("original")

# Scratch copy ----
# The deposited scripts address their data by bare relative path and write figures and
# .tex fragments beside them, so they run against symlinks in a temporary directory and
# original/ is left byte-identical to what download_original.R verified.
sandbox <- file.path(tempdir(), "archive_sandbox")
unlink(sandbox, recursive = TRUE)
dir.create(sandbox)
walk(
  list.files(data_dir, full.names = TRUE),
  \(f) file.symlink(f, file.path(sandbox, basename(f)))
)

position_dodgev <- function(height = 0.75, ...) position_dodge(width = height)

repair <- function(file) {
  lines <- read_lines(file.path(data_dir, file))
  lines <- str_replace_all(lines, fixed("rmeta::meta.summaries("), "meta_summaries_fe(")
  lines <- str_replace_all(lines, fixed("scales::label_number_si()"),
                           "scales::label_number(scale_cut = scales::cut_short_scale())")
  lines <- str_replace_all(lines, fixed("facet_row(~ name)"), "facet_wrap(~ name)")
  lines <- str_replace_all(lines, fixed("coord_capped_cart(bottom = \"none\")"),
                           "coord_cartesian()")
  lines <- str_replace_all(lines, fixed("study_group = paste(study_group)"),
                           "study_group = first(study_group)")
  paste(lines, collapse = "\n")
}

script_env <- environment()
withr::with_dir(sandbox, {
  pdf(NULL)
  eval(parse(text = repair("appendix_section_a.R")), envir = script_env)
  eval(parse(text = repair("manuscript.R")), envir = script_env)
  dev.off()
})

# Harvest ----
# One row per published quantity, keyed the way the ground truth keys it. Every value
# below is read off an object the deposited code built; none is typed.

cell <- function(label, value) tibble(label = label, value = as.numeric(value))

# Table 2. The deposit formats the cells to two decimals inside acq_summary, so the
# unrounded numbers are taken from the six per-level frames it built on the way.
acq_long <- bind_rows(
  bind_rows(app_easy_pass, app_medium_pass, app_hard_pass) |>
    ungroup() |>
    transmute(level, column = if_else(admin_browser == 1, "Browser", "Web-App"),
              estimate, std.error),
  bind_rows(mobile_easy_pass, mobile_medium_pass, mobile_hard_pass) |>
    ungroup() |>
    transmute(level, column = if_else(admin_nonmobile == 1, "Nonmobile", "Mobile"),
              estimate, std.error)
)

table_2_rows <- bind_rows(
  acq_long |> transmute(label = paste0("table_2_", tolower(level), "_",
                                       str_replace_all(tolower(column), "-", ""), "_estimate"),
                        value = estimate),
  acq_long |> transmute(label = paste0("table_2_", tolower(level), "_",
                                       str_replace_all(tolower(column), "-", ""), "_se"),
                        value = std.error)
)

table_2_diff_rows <- bind_rows(
  acq_long |>
    filter(column %in% c("Browser", "Web-App")) |>
    pivot_wider(names_from = column, values_from = c(estimate, std.error)) |>
    transmute(level, contrast = "browser_webapp",
              estimate = estimate_Browser - `estimate_Web-App`,
              std.error = sqrt(std.error_Browser ^ 2 + `std.error_Web-App` ^ 2)),
  acq_long |>
    filter(column %in% c("Nonmobile", "Mobile")) |>
    pivot_wider(names_from = column, values_from = c(estimate, std.error)) |>
    transmute(level, contrast = "nonmobile_mobile",
              estimate = estimate_Nonmobile - estimate_Mobile,
              std.error = sqrt(std.error_Nonmobile ^ 2 + std.error_Mobile ^ 2))
) |>
  pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value") |>
  transmute(label = paste0("table_2_", tolower(level), "_", contrast, "_",
                           if_else(part == "estimate", "estimate", "se")),
            value)

# Figure 5. gg_df is the deposit's own plot frame; its two heading rows carry no estimate.
figure_5_rows <- gg_df |>
  filter(!is.na(estimate)) |>
  mutate(slug = paste(dataset) |> str_to_lower() |> str_replace_all("[^a-z0-9]+", "_") |>
           str_remove("_$")) |>
  pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value") |>
  transmute(label = paste0("figure_5_", slug, "_",
                           if_else(part == "estimate", "estimate", "se")),
            value)

# The correspondence counts and shares, from the deposit's dat.
nonconj_archive <- dat |>
  filter(study_group != "Hainmueller & Hopkins (2015)") |>
  mutate(p_adjust = p.adjust(p_diff, method = "fdr"))
conj_archive <- dat |>
  filter(study_group == "Hainmueller & Hopkins (2015)") |>
  mutate(p_adjust = p.adjust(p_diff, method = "fdr"))
signed_archive <- dat |> filter(!sign_diff)

correspondence_rows <- bind_rows(
  cell("summary_estimates_total", nrow(summary_dat)),
  cell("summary_estimates_conjoint",
       sum(summary_dat$study_group == "Hainmueller & Hopkins (2015)")),
  cell("summary_estimates_nonconjoint",
       sum(summary_dat$study_group != "Hainmueller & Hopkins (2015)")),
  cell("pairs_total", nrow(dat)),
  cell("pairs_nonconjoint", nrow(nonconj_archive)),
  cell("pairs_conjoint", nrow(conj_archive)),
  cell("pairs_correctly_signed", nrow(signed_archive)),
  cell("nonconjoint_correctly_signed", sum(!nonconj_archive$sign_diff)),
  cell("nonconjoint_incorrectly_signed", sum(nonconj_archive$sign_diff)),
  cell("nonconjoint_sig_smaller_correctly_signed",
       sum(!nonconj_archive$sign_diff & nonconj_archive$estimate_diff < 0 &
             nonconj_archive$p_diff < 0.05)),
  cell("nonconjoint_sig_among_incorrectly_signed",
       sum(nonconj_archive$sign_diff & nonconj_archive$p_diff < 0.05)),
  cell("nonconjoint_sig_unadjusted", sum(nonconj_archive$p_diff < 0.05)),
  cell("nonconjoint_sig_fdr", sum(nonconj_archive$p_adjust < 0.05)),
  cell("conjoint_smaller", sum(conj_archive$estimate_diff < 0)),
  cell("conjoint_larger", sum(conj_archive$estimate_diff > 0)),
  cell("conjoint_sig_among_smaller",
       sum(conj_archive$estimate_diff < 0 & conj_archive$p_diff < 0.05)),
  cell("conjoint_sig_among_larger",
       sum(conj_archive$estimate_diff > 0 & conj_archive$p_diff < 0.05)),
  cell("conjoint_sig_unadjusted", sum(conj_archive$p_diff < 0.05)),
  cell("conjoint_sig_fdr", sum(conj_archive$p_adjust < 0.05)),
  cell("conjoint_correctly_signed", sum(!conj_archive$sign_diff)),
  cell("correspondence_overall", mean(signed_archive$estimate_ycls / signed_archive$estimate_pre)),
  cell("correspondence_conjoint",
       mean(signed_archive$estimate_ycls[signed_archive$conjoint == "Conjoint Estimates"] /
              signed_archive$estimate_pre[signed_archive$conjoint == "Conjoint Estimates"])),
  cell("correspondence_nonconjoint",
       mean(signed_archive$estimate_ycls[signed_archive$conjoint == "Non-Conjoint Estimates"] /
              signed_archive$estimate_pre[signed_archive$conjoint == "Non-Conjoint Estimates"])),
  cell("correspondence_inflated",
       mean((signed_archive$estimate_ycls / 0.70) / signed_archive$estimate_pre))
)

# The three appendix tables, unrounded, from the deposit's own long frames.
appendix_table_rows <- bind_rows(
  full_join(combined_estimates, combined_ses,
            by = c("AD_Z_party_sure_thing", "x_pid3", "survey")) |>
    transmute(label = paste0("appendix_table_1_",
                             str_replace_all(tolower(paste(AD_Z_party_sure_thing, x_pid3,
                                                           survey)), "[^a-z0-9]+", "_")),
              estimate, std.error),
  full_join(combined_prospective_estimates, combined_prospective_ses,
            by = c("Z_psv", "outcome_group", "survey")) |>
    transmute(label = paste0("appendix_table_2_",
                             str_replace_all(tolower(paste(Z_psv, outcome_group, survey)),
                                             "[^a-z0-9]+", "_")),
              estimate, std.error),
  full_join(combined_retrospective_estimates, combined_retrospective_ses,
            by = c("outcome_group", "survey")) |>
    transmute(label = paste0("appendix_table_3_",
                             str_replace_all(tolower(paste(outcome_group, survey)),
                                             "[^a-z0-9]+", "_")),
              estimate, std.error)
) |>
  pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value") |>
  transmute(label = paste0(label, "_", if_else(part == "estimate", "estimate", "se")), value)

appendix_ratio_rows <- bind_rows(
  combined_estimates |>
    distinct(AD_Z_party_sure_thing, x_pid3, Ratio) |>
    transmute(label = paste0("appendix_table_1_",
                             str_replace_all(tolower(paste(AD_Z_party_sure_thing, x_pid3)),
                                             "[^a-z0-9]+", "_"), "_ratio"),
              value = Ratio),
  combined_prospective_estimates |>
    distinct(Z_psv, outcome_group, psv_ratio, abp_ratio) |>
    pivot_longer(c(psv_ratio, abp_ratio), names_to = "part", values_to = "value") |>
    transmute(label = paste0("appendix_table_2_",
                             str_replace_all(tolower(paste(Z_psv, outcome_group)),
                                             "[^a-z0-9]+", "_"), "_", part),
              value),
  combined_retrospective_estimates |>
    distinct(outcome_group, psv_ratio, abp_ratio) |>
    pivot_longer(c(psv_ratio, abp_ratio), names_to = "part", values_to = "value") |>
    transmute(label = paste0("appendix_table_3_",
                             str_replace_all(tolower(outcome_group), "[^a-z0-9]+", "_"),
                             "_", part),
              value)
)

# The pooled benchmarks the appendix prose quotes, from the fifteen fits the deposit built.
benchmark_rows <- tribble(
  ~label,                              ~fit,
  "benchmark_russians_pre",            russians_benchmark,
  "benchmark_framing_pre",             framing_benchmark,
  "benchmark_framing_covid",           framing_ycls,
  "benchmark_disease_pre",             disease_benchmark,
  "benchmark_disease_covid",           disease_ycls,
  "benchmark_welfare_cawi",            ycls_cawi,
  "benchmark_welfare_capi",            gss_capi,
  "benchmark_welfare_papi",            gss_papi,
  "benchmark_welfare_experimental",    ycls_exp,
  "benchmark_welfare_huber",           huber_benchmark,
  "benchmark_welfare_1986",            ycls_benchmark,
  "benchmark_welfare_observational",   ycls_obs,
  "benchmark_druckman_pre",            druckman_benchmark,
  "benchmark_druckman_covid",          druckman_ycls,
  "benchmark_knobe_pre",               knobe_benchmark
) |>
  mutate(estimate = map_dbl(fit, "summary"), std.error = map_dbl(fit, "se.summary")) |>
  select(-fit) |>
  pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value") |>
  transmute(label = paste0(label, "_", if_else(part == "estimate", "estimate", "se")), value)

# The summary effect sizes behind Figures 2 and 3, one label per study-outcome pair.
summary_rows <- summary_dat |>
  ungroup() |>
  mutate(slug = paste(study_group_detail) |> str_to_lower() |>
           str_replace_all("[^a-z0-9]+", "_") |> str_remove("_$"),
         side = if_else(study == "YCLS summary", "ycls", "pre")) |>
  pivot_longer(c(estimate, std.error), names_to = "part", values_to = "value") |>
  transmute(label = paste0("summary_", slug, "_", side, "_",
                           if_else(part == "estimate", "estimate", "se")),
            value)

archive_values <- bind_rows(
  table_2_rows, table_2_diff_rows, figure_5_rows, correspondence_rows,
  appendix_table_rows, appendix_ratio_rows, benchmark_rows, summary_rows
) |>
  ungroup() |>
  select(label, value) |>
  arrange(label)

stopifnot(!any(duplicated(archive_values$label)))

write_csv(archive_values, here::here("ground_truth", "archive_values.csv"))

print(paste(nrow(archive_values), "values recovered from the deposited code."))
