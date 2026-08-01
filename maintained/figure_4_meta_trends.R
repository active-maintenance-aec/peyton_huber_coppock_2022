# peyton_huber_coppock_2022/maintained/figure_4_meta_trends.R
# Output: maintained/output/figure_4_meta_trends.pdf/.png
# Depends on: original/phc_meta_trends.rds, helpers.R
# Description: Respondents from mobile devices and web applications, Jun 2018 to Jul 2020.

source(here::here("maintained", "helpers.R"))

gg_df <- read_rds(file.path(data_dir, "phc_meta_trends.rds"))

# Figure ----
g <- ggplot(
  gg_df,
  aes(
    x      = time,
    weight = 1 / (std.error ^ 2),
    y      = est
  )
) +
  scale_x_date(date_labels = "%b '%y") +
  geom_smooth(color = "black", fill = "grey70", linewidth = 0.5, alpha = 0.25) +
  geom_point(
    aes(size = as.numeric(size_group), fill = pre_covid),
    pch      = 21,
    color    = "white",
    alpha    = 0.8,
    position = position_dodge2(width = 1.5, preserve = "single")
  ) +
  facet_wrap(~ name) +
  scale_color_grey("Pre-COVID sample: ", start = 0, end = 0.4) +
  scale_fill_grey("Pre-COVID sample: ",  start = 0, end = 0.4) +
  labs(x = "", y = "", size = "Sample size:") +
  scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
  scale_size(
    range  = c(2, 4),
    labels = c("< 1,000", "1,000-2,000", "2,000-3,000", "3,000+")
  ) +
  theme_ycls() +
  theme(
    plot.margin           = unit(c(0.1, 0.1, 0.1, 0.1), "lines"),
    legend.position       = "bottom",
    legend.justification  = "left",
    axis.ticks.y          = element_line(linewidth = 0.1, color = "lightgrey"),
    axis.ticks.x          = element_line(linewidth = 0.1, color = "lightgrey"),
    axis.text.y           = element_text(size = 10),
    panel.grid.major      = element_line(linewidth = 0.1, color = "lightgrey"),
    legend.margin         = margin(t = -0.3, unit = "cm"),
    legend.box.margin     = margin(t = -0.3, unit = "cm"),
    panel.background      = element_blank(),
    plot.background       = element_blank(),
    legend.background     = element_blank(),
    legend.box.background = element_blank(),
    legend.key            = element_blank(),
    legend.box.just       = "left",
    legend.box            = "vertical"
  ) +
  guides(
    fill = guide_legend(override.aes = list(size = 3)),
    size = guide_legend(override.aes = list(color = "black"))
  )

ggsave(
  here::here("maintained", "output", "figure_4_meta_trends.pdf"),
  plot = g, width = 6.5, height = 3.5
)
ggsave(
  here::here("maintained", "output", "figure_4_meta_trends.png"),
  plot = g, width = 6.5, height = 3.5, dpi = 300
)

# Checks ----
check_figure_4 <- tibble(
  check = c("Survey-panel rows", "Panels", "First survey", "Last survey"),
  value = c(
    as.character(nrow(gg_df)),
    paste(sort(unique(gg_df$name)), collapse = "; "),
    as.character(min(gg_df$time)),
    as.character(max(gg_df$time))
  )
)

print(check_figure_4)
