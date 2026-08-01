# peyton_huber_coppock_2022/maintained/figure_1_lucid_weekly_completes.R
# Output: maintained/output/figure_1_lucid_weekly_completes.pdf/.png
# Depends on: original/phc_lucid_completes.rds, helpers.R
# Description: Weekly Lucid survey completions sold to academic buyers, Jan 2019 to Mar 2021.

source(here::here("maintained", "helpers.R"))

gg_df <- read_rds(file.path(data_dir, "phc_lucid_completes.rds"))

# Figure ----
g <- ggplot(gg_df, aes(y = completes, x = date)) +
  geom_smooth(
    color = "black",
    fill  = "grey70",
    linewidth = 0.6,
    alpha = 0.5
  ) +
  scale_x_date(
    expand     = c(0.01, 0.01),
    date_breaks = "3 month",
    date_labels = "%b '%y"
  ) +
  scale_y_continuous(labels = scales::label_number(scale_cut = scales::cut_short_scale())) +
  geom_point(
    size  = 3.25,
    pch   = 21,
    color = "white",
    fill  = "black",
    alpha = 0.7
  ) +
  geom_text_repel(
    data = gg_df |> filter(completes > 100000),
    aes(label = "Week before\n2020 election"),
    color             = "black",
    min.segment.length = 0,
    box.padding       = 0.5,
    nudge_y           = 0,
    nudge_x           = 80,
    direction         = "y",
    point.padding     = 0.5,
    size              = 3.5,
    family            = "serif"
  ) +
  labs(x = "", y = "") +
  theme_fivethirtyeight() +
  theme(
    plot.margin              = unit(c(0.1, 0.1, 0.1, 0.1), "lines"),
    legend.position          = "none",
    strip.text               = element_text(size = 10.28),
    strip.text.x             = element_text(size = 10.28),
    panel.background         = element_blank(),
    plot.background          = element_blank(),
    legend.background        = element_blank(),
    legend.box.background    = element_blank(),
    legend.key               = element_blank(),
    panel.grid.major.y       = element_line(linewidth = 0.3),
    panel.grid.major.x       = element_line(linewidth = 0.3),
    axis.text.x              = element_text(size = 10),
    axis.title.x             = element_text(size = 10)
  )

ggsave(
  here::here("maintained", "output", "figure_1_lucid_weekly_completes.pdf"),
  plot = g, width = 6.5, height = 4
)
ggsave(
  here::here("maintained", "output", "figure_1_lucid_weekly_completes.png"),
  plot = g, width = 6.5, height = 4, dpi = 300
)

# Checks ----
check_figure_1 <- tibble(
  check = c("Weeks plotted", "Peak weekly completes", "First week", "Last week"),
  value = c(
    as.character(nrow(gg_df)),
    format(max(gg_df$completes), big.mark = ","),
    as.character(min(gg_df$date)),
    as.character(max(gg_df$date))
  )
)

print(check_figure_1)
