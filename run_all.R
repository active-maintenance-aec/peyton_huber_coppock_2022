# peyton_huber_coppock_2022/run_all.R
# Runs the whole reproduction in order: fetch and verify the deposited archive, rebuild
# the summary effect sizes, then every published figure and table, then the in-text
# quantities. Every script is self-contained and can also be run on its own.
#
# clean_summary_estimates.R needs network access beyond Dataverse: the deposited code it
# runs downloads two ManyLabs 2 datasets from GitHub.

library(here)
here::i_am("run_all.R")

# Deposited archive ----
# Downloads from Dataverse on a fresh clone; verifies checksums either way.
source(here::here("download_original.R"))

# Summary effect sizes ----
# Everything that compares pre-COVID to COVID-era estimates reads this script's output,
# so it runs first. It is also the slow step, at a few minutes.
source(here::here("maintained", "clean_summary_estimates.R"))

# Figures ----
source(here::here("maintained", "figure_1_lucid_weekly_completes.R"))
source(here::here("maintained", "figure_2_noncojoint_correspondence.R"))
source(here::here("maintained", "figure_3_conjoint_correspondence.R"))
source(here::here("maintained", "figure_4_meta_trends.R"))
source(here::here("maintained", "figure_5_trust_replication.R"))

# Tables ----
source(here::here("maintained", "table_2_acq_pass_rates.R"))

# In-text quantities ----
source(here::here("maintained", "text_correspondence_summary.R"))
