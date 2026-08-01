# peyton_huber_coppock_2022 — figure_3_conjoint_correspondence.R
# Output: maintained/output/figure_3_conjoint_correspondence.pdf/.png
# Depends on: maintained/output/phc_summary_clean.rds, helpers.R
# Description: Comparison of 41 conjoint summary effect sizes (pre-COVID vs COVID-era).

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
    sig_diff      = if_else(p_diff < 0.05, "Significant", "Not Significant")
  )

# Figure ----
gg_df <- dat |>
  filter(study_group == "Hainmueller & Hopkins (2015)") |>
  mutate(
    p_adjust     = p.adjust(p_diff, method = "fdr"),
    sig_diff_adj = if_else(p_adjust < 0.05, "Significant", "Not Significant")
  )

g <- gg_df |>
  ggplot(aes(
    x     = estimate_pre,
    y     = estimate_ycls,
    group = study_group,
    fill  = sig_diff,
    color = sig_diff,
    shape = sig_diff_adj
  )) +
  geom_abline(intercept = 0, slope = 1, linewidth = 0.5, color = "black", alpha = 0.9, lty = 2) +
  geom_vline(xintercept = 0, linewidth = 0.5, color = "black", alpha = 0.9) +
  geom_hline(yintercept = 0, linewidth = 0.5, color = "black", alpha = 0.9) +
  geom_rug(alpha = 1 / 2, color = "black", length = unit(0.015, "npc")) +
  geom_linerange(aes(xmin = conf.low_pre,  xmax = conf.high_pre)) +
  geom_linerange(aes(ymin = conf.low_ycls, ymax = conf.high_ycls)) +
  scale_x_continuous(limits = c(-0.05, 0.3)) +
  scale_y_continuous(limits = c(-0.05, 0.3)) +
  geom_point(size = 3, color = "white", alpha = 0.8) +
  scale_fill_grey("Difference-in-Difference: ",  start = 0.5, end = 0) +
  scale_color_grey("Difference-in-Difference: ", start = 0.5, end = 0) +
  scale_shape_manual("Difference-in-Difference: ", values = c(21, 22)) +
  labs(x = "Pre-COVID summary estimate", y = "COVID-era summary estimate") +
  theme_ycls() +
  theme(
    legend.position       = "bottom",
    legend.justification  = "left",
    axis.ticks.y          = element_line(linewidth = 0.1, color = "lightgrey"),
    axis.ticks.x          = element_line(linewidth = 0.1, color = "lightgrey"),
    axis.text.y           = element_text(size = 10),
    panel.grid.major      = element_line(linewidth = 0.1, color = "lightgrey"),
    legend.margin         = margin(t = -0.05, unit = "cm"),
    legend.box.margin     = margin(t = -0.05, unit = "cm"),
    panel.background      = element_blank(),
    plot.background       = element_blank(),
    legend.background     = element_blank(),
    legend.box.background = element_blank(),
    legend.key            = element_blank(),
    plot.margin           = unit(c(0.1, 0.1, 0.1, 0.1), "lines")
  )

ggsave(
  here::here("maintained", "output", "figure_3_conjoint_correspondence.pdf"),
  plot = g, width = 6, height = 5
)
ggsave(
  here::here("maintained", "output", "figure_3_conjoint_correspondence.png"),
  plot = g, width = 6, height = 5, dpi = 300
)

# Checks ----
# The corrigendum's corrected Figure 3 caption reports 12 of 41 significant before
# adjustment and 7 after controlling the false discovery rate.
check_figure_3 <- tibble(
  check = c(
    "Conjoint pairs",
    "Correctly signed",
    "Smaller in replication",
    "Significantly different, unadjusted",
    "Significantly different, BH-FDR"
  ),
  value = c(
    nrow(gg_df),
    sum(!gg_df$sign_diff),
    sum(gg_df$estimate_diff < 0),
    sum(gg_df$sig_diff == "Significant"),
    sum(gg_df$sig_diff_adj == "Significant")
  )
)

print(check_figure_3)
