# peyton_huber_coppock_2022/download_original.R
# Output: original/ (the deposited replication archive, not redistributed in this repo)
# Depends on: original_manifest.csv
# Description: Fetch the deposited archive from Harvard Dataverse and verify every file.
#   Run this once before running anything in maintained/. Re-running is free: files
#   already present with the right checksum are not downloaded again. The deposit is
#   93 MB across 20 files, most of it one SPSS file.
#
#   The manifest carries two checksums per file because they do not always agree.
#   md5_served is the MD5 of the bytes Dataverse returns for `?format=original`, which is
#   what this code was written against. md5_published is the checksum Dataverse displays.
#   Here all twenty agree, but they do not always: another deposit in this program carries
#   three published checksums that verify neither the original nor the derived tabular
#   file. Verification therefore runs against md5_served and any disagreement is reported
#   rather than hidden.
#
#   The file_persistent_id column is empty for this deposit. Harvard Dataverse minted no
#   file-level DOIs here, so the numeric dataverse_file_id is the only stable handle.

library(tidyverse)
library(here)

here::i_am("download_original.R")

dataset_doi <- "doi:10.7910/DVN/38UTBF"
base_url <- "https://dataverse.harvard.edu/api/access/datafile"

# Manifest ----
manifest <- read_csv(here::here("original_manifest.csv"), show_col_types = FALSE)

dir.create(here::here("original"), showWarnings = FALSE)

# Download what is missing or wrong ----
# format=original asks for the deposited bytes rather than the tabular representation
# Dataverse derives for ingested files. Five of these twenty were ingested as tabular
# data, so the distinction matters.
planned <- manifest |>
  mutate(
    path = here::here("original", file),
    url = str_glue("{base_url}/{dataverse_file_id}?format=original"),
    md5_local = unname(tools::md5sum(path)),
    needs_download = is.na(md5_local) | md5_local != md5_served
  )

walk2(
  planned$url[planned$needs_download],
  planned$path[planned$needs_download],
  function(url, path) download.file(url, destfile = path, mode = "wb", quiet = TRUE)
)

print(str_glue("Downloaded {sum(planned$needs_download)} of {nrow(planned)} files; ",
               "{sum(!planned$needs_download)} already present and verified."))

# Verify ----
verified <- planned |>
  mutate(
    md5_downloaded = unname(tools::md5sum(path)),
    match = md5_downloaded == md5_served,
    published_agrees = md5_served == md5_published
  ) |>
  select(file, bytes, md5_served, md5_downloaded, match, published_agrees)

print(verified, n = nrow(verified))

if (!all(verified$match)) {
  stop("Checksum mismatch: the downloaded archive does not match what Dataverse served when this code was written.")
}

print(str_glue("All {nrow(verified)} files match. ",
               "{sum(!verified$published_agrees)} carry a published checksum that disagrees."))
print(str_glue("Archive: {dataset_doi}"))
