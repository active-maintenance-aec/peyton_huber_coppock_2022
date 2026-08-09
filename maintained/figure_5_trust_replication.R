# peyton_huber_coppock_2022/maintained/figure_5_trust_replication.R
# Output: maintained/output/figure_5_trust_replication.pdf/.png/.csv
# Depends on: original/phc_replications.rds, original/peyton_original.csv, helpers.R
# Description: Reanalysis of treatment effects on trust in government for Peyton (2020)
#   replication, showing full sample and attentive vs inattentive subgroups.
#   Substitutions: position_dodgev to position_dodge; geom_errorbarh to geom_linerange;
#   coord_capped_cart to coord_cartesian. All three come from lemon; the ggplot2
#   equivalents are current and do not depend on a third package for basic dodging.

source(here::here("maintained", "helpers.R"))

ycls_dat        <- read_rds(file.path(data_dir, "phc_replications.rds"))
peyton_original <- read_csv(file.path(data_dir, "peyton_original.csv"), show_col_types = FALSE)

# Build Peyton original subsets ----
peyton_original_clean <- peyton_original |>
  mutate(
    Z_trust = factor(
      Z,
      levels = c("Corrupt", "Placebo", "Honest"),
      labels = c("Corrupt", "Control", "Honest")
    ),
    Z_trust_n = case_when(
      Z_trust == "Corrupt" ~ 0,
      Z_trust == "Control" ~ 0.5,
      Z_trust == "Honest"  ~ 1
    ),
    D = glass_delta(Y = fmptrust_index, Z = Z_trust, level = "Control"),
    Y = glass_delta(Y = fedspend_index,  Z = Z_trust, level = "Control")
  ) |>
  filter(study_type == "Politics")

# Build COVID-era replication subset ----
peyton_rep <- ycls_dat |>
  filter(str_detect(week, "Week 9")) |>
  mutate(
    Z_trust = factor(
      peyton_Z,
      levels = c("corrupt", "placebo", "honest"),
      labels = c("Corrupt", "Control", "Honest")
    ),
    Z_trust_n = case_when(
      Z_trust == "Corrupt" ~ 0,
      Z_trust == "Control" ~ 0.5,
      Z_trust == "Honest"  ~ 1
    ),
    D = glass_delta(Y = peyton_trust_index,   Z = Z_trust, level = "Control"),
    Y = glass_delta(Y = peyton_fedspend_index, Z = Z_trust, level = "Control")
  )

# Combine all datasets for Figure 5 ----
all_data_sets <- bind_rows(
  `MTurk sample, Jun 2014`       = peyton_original_clean |> filter(experiment == "MTurk_Pols14"),
  `Qualtrics sample, Sep 2014`   = peyton_original_clean |> filter(experiment == "GenPop_Pols14"),
  `MTurk sample, Mar 2017`       = peyton_original_clean |> filter(experiment == "MTurk_Pols17"),
  `Full Sample`                  = peyton_rep,
  `Attentive: Passed ACQ`        = peyton_rep |> filter(peyton_pass_acq == 1),
  `Inattentive: Failed ACQ`      = peyton_rep |> filter(peyton_pass_acq == 0),
  `Attentive: Internet browser`  = peyton_rep |> filter(admin_browser == 1),
  `Inattentive: Web-Application` = peyton_rep |> filter(admin_browser == 0),
  `Attentive: Non-mobile device` = peyton_rep |> filter(admin_nonmobile == 1),
  `Inattentive: Mobile device`   = peyton_rep |> filter(admin_nonmobile == 0),
  .id = "dataset"
) |>
  filter(!is.na(Z_trust_n))

# Estimate first-stage effect of Z on D for each dataset/subgroup ----
gg_df <- all_data_sets |>
  group_by(dataset) |>
  reframe(tidy(lm_robust(D ~ Z_trust_n, data = pick(everything())))) |>
  filter(term != "(Intercept)") |>
  ungroup() |>
  add_row(dataset = c("Original experiments:", "Lucid replication:")) |>
  mutate(
    study = if_else(
      str_detect(paste(dataset), "MTurk|Qualtrics"),
      "Original", "Lucid"
    ),
    study = factor(
      study,
      levels = c("Original", "Lucid"),
      labels = c("Original study:", "Lucid replication:")
    ),
    dataset = factor(
      dataset,
      rev(c(
        "Original experiments:",
        "MTurk sample, Jun 2014",
        "Qualtrics sample, Sep 2014",
        "MTurk sample, Mar 2017",
        "Lucid replication:",
        "Full Sample",
        "Attentive: Passed ACQ",
        "Inattentive: Failed ACQ",
        "Attentive: Internet browser",
        "Inattentive: Web-Application",
        "Attentive: Non-mobile device",
        "Inattentive: Mobile device"
      ))
    )
  )

# Plot ----

g <- ggplot(gg_df, aes(x = estimate, y = dataset, fill = study, shape = study)) +
  geom_vline(xintercept = 0, lty = 2, linewidth = 0.5) +
  geom_linerange(
    aes(xmin = conf.low, xmax = conf.high, color = study),
    position  = position_dodge(width = 0.5),
    linewidth = 1.25,
    na.rm     = TRUE
  ) +
  geom_point(
    position = position_dodge(width = 0.5),
    size     = 3.25,
    color    = "white",
    alpha    = 0.8,
    na.rm    = TRUE
  ) +
  scale_fill_grey("",  start = 0.5, end = 0) +
  scale_color_grey("", start = 0.5, end = 0) +
  scale_shape_manual("", values = c(21, 22)) +
  xlab("Average causal effect estimate (standard units)") +
  ylab("") +
  coord_cartesian() +
  theme_ycls() +
  theme(
    axis.line.x      = element_line(linewidth = 0.5),
    strip.text.x     = element_text(hjust = 0),
    axis.text.y      = element_text(
      face = c(rep("plain", 7), "bold", "plain", "plain", "plain", "bold"),
      size = c(rep(10, 7), 11, 10, 10, 10, 11)
    )
  )

fixed   <- 1
spacing <- 0.285

# The plotted values ----
# The two heading rows carry no estimate and are dropped; what remains is one row
# per plotted point, in the order the figure stacks them from the top.
write_csv(
  gg_df |>
    filter(!is.na(estimate)) |>
    arrange(desc(as.integer(dataset))) |>
    select(dataset, study, estimate, std.error, statistic, p.value, conf.low, conf.high, df),
  file.path(out_dir, "figure_5_trust_replication.csv")
)

ggsave(
  here::here("maintained", "output", "figure_5_trust_replication.pdf"),
  plot = g, width = 6.5, height = fixed + spacing * nrow(g$data)
)
ggsave(
  here::here("maintained", "output", "figure_5_trust_replication.png"),
  plot = g, width = 6.5, height = fixed + spacing * nrow(g$data), dpi = 300
)

# Checks ----
check_figure_5 <- gg_df |>
  filter(!is.na(estimate)) |>
  transmute(
    check = paste("First-stage effect,", dataset),
    estimate,
    std.error,
    conf.low,
    conf.high
  ) |>
  arrange(check)

print(check_figure_5, n = nrow(check_figure_5))
