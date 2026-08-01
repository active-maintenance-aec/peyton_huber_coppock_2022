# peyton_huber_coppock_2022 — text_correspondence_summary.R
# Output: maintained/output/text_correspondence_summary.csv
# Depends on: maintained/output/phc_summary_clean.rds, helpers.R
# Description: Computes the inline text statistics about correspondence between pre-COVID
#   and COVID-era estimates (73% overall, 87% conjoint, 49% non-conjoint) and the
#   significant-difference counts corrected by the 2022 corrigendum.

source(here::here("maintained", "helpers.R"))

summary_dat <- read_rds(file.path(out_dir, "phc_summary_clean.rds"))

x <- summary_dat |> filter(study == "Pre-COVID summary")
y <- summary_dat |> filter(study == "YCLS summary")

dat <- left_join(x, y, by = "study_group_detail", suffix = c("_pre", "_ycls")) |>
  select(-study_ycls, -study_group_ycls, -study_pre) |>
  rename(study_group = study_group_pre) |>
  ungroup() |>
  mutate(
    estimate_diff = estimate_ycls - estimate_pre,
    se_diff       = sqrt(std.error_ycls ^ 2 + std.error_pre ^ 2),
    p_diff        = 2 * (1 - pnorm(abs(estimate_diff / se_diff))),
    sign_diff     = sign(estimate_ycls) != sign(estimate_pre),
    sig_diff      = if_else(p_diff < 0.05, "Significant", "Not Significant"),
    conjoint      = if_else(
      study_group == "Hainmueller & Hopkins (2015)",
      "Conjoint Estimates", "Non-Conjoint Estimates"
    )
  )

# Correspondence by study ----
by_study <- dat |>
  filter(!sign_diff) |>
  group_by(study_group) |>
  summarise(avg_pct_precovid = mean(estimate_ycls / estimate_pre), .groups = "drop") |>
  mutate(avg_pct_precovid = round(avg_pct_precovid, 2)) |>
  arrange(desc(avg_pct_precovid))

# Overall correspondence ----
# inflated_aronow rescales the COVID-era estimate by the 0.70 attenuation factor
# discussed in the paper before taking the ratio.
overall <- dat |>
  filter(!sign_diff) |>
  summarise(
    avg             = mean(estimate_ycls / estimate_pre),
    inflated_aronow = mean((estimate_ycls / 0.70) / estimate_pre)
  )

# Conjoint vs non-conjoint ----
by_type <- dat |>
  filter(!sign_diff) |>
  group_by(conjoint) |>
  summarise(
    avg             = mean(estimate_ycls / estimate_pre),
    n               = n(),
    inflated_aronow = mean((estimate_ycls / 0.70) / estimate_pre),
    .groups = "drop"
  )

# Significant differences ----
# The false discovery rate adjustment is applied within each panel of the paper, so
# the non-conjoint and conjoint sets are adjusted separately.
nonconj <- dat |>
  filter(conjoint == "Non-Conjoint Estimates") |>
  mutate(p_adjust = p.adjust(p_diff, method = "fdr"))

conj <- dat |>
  filter(conjoint == "Conjoint Estimates") |>
  mutate(p_adjust = p.adjust(p_diff, method = "fdr"))

# Export summary ----
results_tbl <- tibble(
  quantity = c(
    "total_pairs",
    "conjoint_pairs",
    "nonconjoint_pairs",
    "correctly_signed_total",
    "avg_pct_precovid_overall",
    "avg_pct_precovid_conjoint",
    "avg_pct_precovid_nonconjoint",
    "inflated_aronow_overall",
    "nonconjoint_correctly_signed",
    "nonconjoint_sig_smaller_correctly_signed",
    "nonconjoint_sig_among_incorrectly_signed",
    "nonconjoint_sig_unadjusted",
    "nonconjoint_sig_fdr",
    "conjoint_smaller",
    "conjoint_larger",
    "conjoint_sig_among_smaller",
    "conjoint_sig_among_larger",
    "conjoint_sig_unadjusted",
    "conjoint_sig_fdr"
  ),
  value = c(
    nrow(dat),
    sum(dat$conjoint == "Conjoint Estimates"),
    sum(dat$conjoint == "Non-Conjoint Estimates"),
    sum(!dat$sign_diff),
    round(overall$avg, 3),
    round(by_type$avg[by_type$conjoint == "Conjoint Estimates"], 3),
    round(by_type$avg[by_type$conjoint == "Non-Conjoint Estimates"], 3),
    round(overall$inflated_aronow, 3),
    sum(!nonconj$sign_diff),
    sum(!nonconj$sign_diff & nonconj$estimate_diff < 0 & nonconj$p_diff < 0.05),
    sum(nonconj$sign_diff & nonconj$p_diff < 0.05),
    sum(nonconj$p_diff < 0.05),
    sum(nonconj$p_adjust < 0.05),
    sum(conj$estimate_diff < 0),
    sum(conj$estimate_diff > 0),
    sum(conj$estimate_diff < 0 & conj$p_diff < 0.05),
    sum(conj$estimate_diff > 0 & conj$p_diff < 0.05),
    sum(conj$p_diff < 0.05),
    sum(conj$p_adjust < 0.05)
  )
)

write_csv(results_tbl, file.path(out_dir, "text_correspondence_summary.csv"))

# Checks ----
check_correspondence <- results_tbl |>
  rename(check = quantity)

print(check_correspondence, n = nrow(check_correspondence))

check_by_study <- by_study |>
  transmute(check = paste("Mean ratio to pre-COVID,", study_group), avg_pct_precovid)

print(check_by_study, n = nrow(check_by_study))
