# peyton_huber_coppock_2022/maintained/text_device_metadata.R
# Output: maintained/output/text_device_metadata.csv,
#   maintained/output/text_device_by_survey.csv,
#   maintained/output/text_device_by_year.csv,
#   maintained/output/text_device_all_surveys.csv
# Depends on: original/phc_replications.rds, original/phc_meta_trends.rds,
#   original/peyton_original.csv, helpers.R
# Description: The device and duration quantities the manuscript states in prose on
#   page 10 and in the Figure 5 note: the per-survey range of web-application and
#   mobile shares, the overlap between the two classifications, mean and median survey
#   durations, the annual shares behind Figure 4, and the two attention-check pass
#   rates. The deposited manuscript.R computes the durations and the pass rates and
#   prints them to the console without saving them; the rest it does not compute at
#   all, so nothing in the deposit's output could be compared against these sentences.

source(here::here("maintained", "helpers.R"))

ycls_dat <- read_rds(file.path(data_dir, "phc_replications.rds")) |> ungroup()
meta_dat <- read_rds(file.path(data_dir, "phc_meta_trends.rds")) |> ungroup()
peyton_original <- read_csv(file.path(data_dir, "peyton_original.csv"), show_col_types = FALSE)

# Shares by survey ----
# admin_browser is 1 for an internet browser and 0 for a web application;
# admin_nonmobile is 1 for a desktop or tablet and 0 for a mobile phone.
by_survey <- ycls_dat |>
  group_by(week) |>
  summarise(
    n            = n(),
    webapp_share = mean(admin_browser == 0),
    mobile_share = mean(admin_nonmobile == 0),
    .groups = "drop"
  )

write_csv(by_survey, file.path(out_dir, "text_device_by_survey.csv"))

# Shares by year ----
# phc_meta_trends carries one share per survey per panel, over the 38 Lucid surveys
# for which UserAgent data were assembled. The annual figure is the mean over the
# surveys fielded in that year, each survey counting once.
by_year <- meta_dat |>
  mutate(year = year(time)) |>
  group_by(panel = name, year) |>
  summarise(mean_share = mean(est), surveys = n(), .groups = "drop")

write_csv(by_year, file.path(out_dir, "text_device_by_year.csv"))

# Every survey in the UserAgent data ----
# Thirteen of the 38 are the replication surveys reported here; the rest are the
# additional sample the manuscript describes. A survey is one of ours when its
# respondent count matches one of the thirteen.
all_surveys <- meta_dat |>
  distinct(time, n) |>
  mutate(replication_survey = n %in% by_survey$n) |>
  arrange(time)

stopifnot(sum(all_surveys$replication_survey) == nrow(by_survey))

write_csv(all_surveys, file.path(out_dir, "text_device_all_surveys.csv"))

# Overlap and durations ----
webapp <- ycls_dat |> filter(admin_browser == 0)
mobile <- ycls_dat |> filter(admin_nonmobile == 0)

# The three pairwise correlations in the Figure 5 note are between the three
# attentiveness classifications, which coexist only in the Week 9 survey, the one that
# carried the Peyton (2020) attention check.
week_9 <- ycls_dat |> filter(str_detect(week, "Week 9"), !is.na(peyton_pass_acq))

# The UserAgent data cover 38 Lucid surveys, of which 13 are the replication surveys
# reported here. The "additional sample" is everything else, so it is the total across
# all 38 less the respondents in our own.
respondents_all_surveys <- meta_dat |> distinct(time, n) |> summarise(sum(n)) |> pull()

device_metadata <- tibble(
  quantity = c(
    "respondents",
    "surveys",
    "field_period_year_first",
    "field_period_year_last",
    "field_period_month_first",
    "field_period_month_last",
    "webapp_share_min",
    "webapp_share_max",
    "mobile_share_min",
    "mobile_share_max",
    "mobile_share_among_webapp",
    "webapp_share_among_mobile",
    "duration_median_minutes",
    "duration_mean_browser",
    "duration_mean_webapp",
    "duration_mean_nonmobile",
    "duration_mean_mobile",
    "respondents_outside_replication_surveys",
    "acq_pass_rate_peyton_original",
    "acq_pass_rate_week_9",
    "correlation_nonmobile_browser",
    "correlation_nonmobile_acq",
    "correlation_browser_acq",
    "surveys_with_acq"
  ),
  value = c(
    nrow(ycls_dat),
    nrow(by_survey),
    min(ycls_dat$admin_year),
    max(ycls_dat$admin_year),
    min(as.integer(ycls_dat$admin_month)),
    max(as.integer(ycls_dat$admin_month)),
    min(by_survey$webapp_share),
    max(by_survey$webapp_share),
    min(by_survey$mobile_share),
    max(by_survey$mobile_share),
    mean(webapp$admin_nonmobile == 0),
    mean(mobile$admin_browser == 0),
    median(ycls_dat$admin_duration_minutes),
    mean(ycls_dat$admin_duration_minutes[ycls_dat$admin_browser == 1]),
    mean(ycls_dat$admin_duration_minutes[ycls_dat$admin_browser == 0]),
    mean(ycls_dat$admin_duration_minutes[ycls_dat$admin_nonmobile == 1]),
    mean(ycls_dat$admin_duration_minutes[ycls_dat$admin_nonmobile == 0]),
    respondents_all_surveys - nrow(ycls_dat),
    mean(peyton_original$attention_math, na.rm = TRUE),
    mean(ycls_dat$peyton_pass_acq[str_detect(ycls_dat$week, "Week 9")], na.rm = TRUE),
    cor(week_9$admin_nonmobile, week_9$admin_browser),
    cor(week_9$admin_nonmobile, week_9$peyton_pass_acq),
    cor(week_9$admin_browser, week_9$peyton_pass_acq),
    ycls_dat |>
      filter(!is.na(huber_acq_easy) | !is.na(huber_acq_hard) | !is.na(peyton_pass_acq)) |>
      summarise(n_distinct(week)) |>
      pull()
  )
)

write_csv(device_metadata, file.path(out_dir, "text_device_metadata.csv"))

# Checks ----
check_device <- device_metadata |> rename(check = quantity)

print(check_device, n = nrow(check_device))
print(by_survey, n = nrow(by_survey))
print(by_year, n = nrow(by_year))
