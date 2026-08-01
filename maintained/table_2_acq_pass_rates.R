# peyton_huber_coppock_2022/maintained/table_2_acq_pass_rates.R
# Output: maintained/output/table_2_acq_pass_rates.tex, .csv
# Depends on: original/phc_replications.rds, helpers.R
# Description: ACQ pass rates by attentiveness level and device type (browser vs web-app,
#   nonmobile vs mobile). Reproduces manuscript Table 2.

source(here::here("maintained", "helpers.R"))

ycls_dat <- read_rds(file.path(data_dir, "phc_replications.rds"))

# Compute pass rates by browser/app ----
app_hard_pass <- ycls_dat |> group_by(admin_browser) |>
  reframe(tidy(lm_robust(peyton_pass_acq ~ 1, data = pick(everything())))) |>
  mutate(level = "Hard",   type = "Web-App")

app_easy_pass <- ycls_dat |> group_by(admin_browser) |>
  reframe(tidy(lm_robust(huber_acq_easy ~ 1, data = pick(everything())))) |>
  mutate(level = "Easy",   type = "Web-App")

app_medium_pass <- ycls_dat |> group_by(admin_browser) |>
  reframe(tidy(lm_robust(huber_acq_hard ~ 1, data = pick(everything())))) |>
  mutate(level = "Medium", type = "Web-App")

# Compute pass rates by mobile/nonmobile ----
mobile_hard_pass <- ycls_dat |> group_by(admin_nonmobile) |>
  reframe(tidy(lm_robust(peyton_pass_acq ~ 1, data = pick(everything())))) |>
  mutate(level = "Hard",   type = "Mobile")

mobile_easy_pass <- ycls_dat |> group_by(admin_nonmobile) |>
  reframe(tidy(lm_robust(huber_acq_easy ~ 1, data = pick(everything())))) |>
  mutate(level = "Easy",   type = "Mobile")

mobile_medium_pass <- ycls_dat |> group_by(admin_nonmobile) |>
  reframe(tidy(lm_robust(huber_acq_hard ~ 1, data = pick(everything())))) |>
  mutate(level = "Medium", type = "Mobile")

# Build summary columns ----
mobile_acq_means <- bind_rows(mobile_easy_pass, mobile_medium_pass, mobile_hard_pass) |>
  ungroup() |>
  mutate(
    device = if_else(admin_nonmobile == 1, "Non-Mobile", "Mobile"),
    device = factor(device, levels = c("Non-Mobile", "Mobile"))
  ) |>
  select(estimate, std.error, level, device) |>
  mutate(entry = table_entry(est = estimate, se = std.error, digits = 2)) |>
  select(level, device, entry) |>
  arrange(device) |>
  pivot_wider(names_from = device, values_from = entry)

app_acq_means <- bind_rows(app_easy_pass, app_medium_pass, app_hard_pass) |>
  ungroup() |>
  mutate(device = if_else(admin_browser == 1, "Browser", "Web-App")) |>
  select(estimate, std.error, level, device) |>
  mutate(entry = table_entry(est = estimate, se = std.error, digits = 2)) |>
  select(level, device, entry) |>
  arrange(device) |>
  pivot_wider(names_from = device, values_from = entry)

mobile_acq_diffs <- bind_rows(mobile_easy_pass, mobile_medium_pass, mobile_hard_pass) |>
  ungroup() |>
  mutate(
    device = if_else(admin_nonmobile == 1, "Non-Mobile", "Mobile"),
    device = factor(device, levels = c("Non-Mobile", "Mobile"))
  ) |>
  select(estimate, std.error, level, device) |>
  pivot_wider(names_from = device, values_from = c(estimate, std.error)) |>
  mutate(
    diff    = `estimate_Non-Mobile` - `estimate_Mobile`,
    se_diff = sqrt(`std.error_Non-Mobile` ^ 2 + `std.error_Mobile` ^ 2),
    p_diff  = 2 * (1 - pnorm(abs(diff / se_diff)))
  ) |>
  select(level, diff, se_diff, p_diff) |>
  mutate(entry = make_entry(est = diff, se = se_diff, p = p_diff, digits = 2)) |>
  select(level, entry)

app_acq_diffs <- bind_rows(app_easy_pass, app_medium_pass, app_hard_pass) |>
  ungroup() |>
  mutate(device = if_else(admin_browser == 1, "Browser", "Web-App")) |>
  select(estimate, std.error, level, device) |>
  pivot_wider(names_from = device, values_from = c(estimate, std.error)) |>
  mutate(
    diff    = `estimate_Browser` - `estimate_Web-App`,
    se_diff = sqrt(`std.error_Browser` ^ 2 + `std.error_Web-App` ^ 2),
    p_diff  = 2 * (1 - pnorm(abs(diff / se_diff)))
  ) |>
  select(level, diff, se_diff, p_diff) |>
  mutate(entry = make_entry(est = diff, se = se_diff, p = p_diff, digits = 2)) |>
  select(level, entry)

# Combine ----
app_acq_summary    <- left_join(app_acq_means,    app_acq_diffs,    by = "level")
mobile_acq_summary <- left_join(mobile_acq_means, mobile_acq_diffs, by = "level")
acq_summary        <- left_join(app_acq_summary,  mobile_acq_summary, by = "level")

# Export ----
write_csv(acq_summary, file.path(out_dir, "table_2_acq_pass_rates.csv"))

knitr::kable(
  acq_summary,
  format  = "latex",
  booktabs = TRUE,
  col.names = c("Difficulty", "Browser", "Web-App", "Difference", "Nonmobile", "Mobile", "Difference"),
  caption = "ACQ pass rates by attentiveness and level of difficulty"
) |>
  write_lines(file.path(out_dir, "table_2_acq_pass_rates.tex"))

# Checks ----
check_table_2 <- acq_summary |>
  mutate(check = paste("ACQ pass rates,", level, "difficulty"), .before = 1) |>
  select(-level)

print(check_table_2)
