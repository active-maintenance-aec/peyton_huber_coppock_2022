# Active Maintenance Report: peyton_huber_coppock_2022


- [Paper overview](#paper-overview)
- [Summary](#summary)
  - [Does the deposited archive run?](#does-the-deposited-archive-run)
  - [Does the maintained rewrite reproduce the
    paper?](#does-the-maintained-rewrite-reproduce-the-paper)
- [Original archive reproducibility](#original-archive-reproducibility)
- [Errata](#errata)
  - [Corrected p-value adjustment (published article, Figures 2 and 3
    and page
    6)](#corrected-p-value-adjustment-published-article-figures-2-and-3-and-page-6)
  - [Everything else the reanalysis
    found](#everything-else-the-reanalysis-found)
  - [A rounding difference in Table
    2](#a-rounding-difference-in-table-2)
  - [Two findings that are not
    corrections](#two-findings-that-are-not-corrections)
- [The extraction and the two
  instruments](#the-extraction-and-the-two-instruments)
- [Number-by-number comparison](#number-by-number-comparison)
  - [Float coverage](#float-coverage)
- [Maintained rewrite](#maintained-rewrite)
  - [Architecture](#architecture)
  - [Deprecated patterns replaced](#deprecated-patterns-replaced)
- [Fixed-effect and random-effects
  pooling](#fixed-effect-and-random-effects-pooling)
- [Figures](#figures)
- [Table 2](#table-2)
- [Maintained rewrite verification](#maintained-rewrite-verification)
- [R environment](#r-environment)

*Drafted by Claude Opus 5 under the supervision of Alex Coppock.*

This repository holds the actively maintained replication code for
Peyton, Huber and Coppock (2022), together with the reproducibility
report that documents what the original archive did and did not do. It
is part of a program applying the maintenance proposal in Peer, Orr and
Coppock (2021, *PS: Political Science & Politics*, doi
[10.1017/S1049096521000366](https://doi.org/10.1017/S1049096521000366))
to a set of published archives.

|  |  |
|----|----|
| Article | [10.1017/xps.2021.17](https://doi.org/10.1017/xps.2021.17) |
| Corrigendum | [10.1017/xps.2022.23](https://doi.org/10.1017/xps.2022.23) |
| Replication archive | [10.7910/DVN/38UTBF](https://doi.org/10.7910/DVN/38UTBF) |

**The data are not redistributed here.** The deposit is 93 MB across 20
files and lives at Harvard Dataverse, which is the only copy this
repository points at. `download_original.R` fetches it and verifies
every file; `original_manifest.csv` pins the file identifiers, sizes and
checksums, so the exact bytes this code was written against are recorded
in version control even though the bytes themselves are not.

**Repository layout.** `maintained/` is the maintained rewrite: one
script per published figure or table, writing to `output/`, which is
committed so a reader can compare a fresh run against it without
downloading anything. `ground_truth/` ties every published number to the
code that produces it. `original/` is created by the download script and
is deliberately absent from the repository. This README is the
reproducibility report, also available as a PDF in `report/`.

**License.** CC0 1.0 Universal, matching the terms of the deposit this
repository maintains. See `LICENSE`.

**To reproduce.** Clone or download the repository, open
`peyton_huber_coppock_2022.Rproj`, and run:

``` r
source("run_all.R")
```

That fetches the deposit, verifies its 20 files, produces every figure
and table into `maintained/output/`, runs the deposited code once more
to record what it produces, rebuilds the ground truth and runs the
coverage gate over the in-text claims. Required packages: tidyverse,
estimatr, metafor, ggthemes, ggrepel, ggforce, lemon, RCurl, haven,
xtable, knitr, kableExtra, here. Paths resolve through `here`, so
nothing depends on the working directory. The run also needs network
access beyond Dataverse, because the deposited appendix code downloads
two ManyLabs 2 datasets from GitHub. A successful run overwrites
`maintained/output/`, which is committed: **`git diff` on that folder is
the reproduction check.**

# Paper overview

**Citation**: Peyton, K., Huber, G. A. and Coppock, A. (2022). “The
Generalizability of Online Experiments Conducted During the COVID-19
Pandemic.” *Journal of Experimental Political Science*, 9(3), 379-394.
DOI: 10.1017/xps.2021.17

**Corrigendum**: Peyton, K., Huber, G. A. and Coppock, A. (2023).
*Journal of Experimental Political Science*, 10(2), 306-309. DOI:
10.1017/xps.2022.23

**Summary**: The paper asks whether survey experiments fielded during
the COVID-19 pandemic recover what the same designs found before it. The
authors fielded 33 replications of 12 previously published designs
across 13 weekly Lucid quota samples of roughly 1,000 US respondents
each, between March and July 2020, spanning binary, ordinal, six-arm and
factorial conjoint designs. Pre-COVID benchmarks come from the original
papers, from prior replications including ManyLabs 2, and from archived
data; Glass’s Delta standardizes outcomes within study, and summary
effect sizes pool treatment-outcome pairs by inverse-variance weighting.
Effects replicate in sign and significance but at reduced magnitude:
replication estimates average 73 percent of their pre-COVID benchmarks,
87 percent among conjoint designs and 49 percent among the rest.
Inattention, proxied by attention-check failure, mobile devices and
web-application respondents, accounts for much of the attenuation, since
attentive subgroups recover effect sizes close to the pre-COVID
benchmarks.

------------------------------------------------------------------------

# Summary

Two questions, answered before the detail.

## Does the deposited archive run?

Not as deposited, but only one of the failures is more than an
inconvenience.

The trivial ones are three. `ReadMe.R`, which is the entry point, loads
`attentive`, a package that has only ever existed on GitHub, and
`coefplot`, which is on CRAN. Neither package’s functions are called
anywhere in the archive, so both `library()` calls can simply be
dropped. `manuscript.R` reads `phc_summary.rds`, which the deposit does
not contain because `appendix_section_a.R` generates it, so the scripts
have to be run in the order `ReadMe.R` names. And `manuscript.R` calls
`scales::label_number_si()`, which `scales` made defunct in 2022 and
which has a one-line replacement.

The fourth is substantive. `appendix_section_a.R` ends by writing the
file every later script depends on, and the last statement before that
write collapses a grouping variable with `paste()` where it should take
one value per group. Under the dplyr of 2021 this silently produced a
character vector of run-together study names; under dplyr 1.1 and later
it is an error, and the file is never written. The bug is one word long
and sits at the very end of a 3,010-line script, so nothing announces
itself until the whole thing has run.

One further failure is worth separating out because it is a fact about a
dependency rather than about the archive. `appendix_section_a.R` and
`manuscript.R` call `position_dodgev()`, which the archive obtains
through `lemon`. `lemon` is current on CRAN, updated in September 2025,
but it no longer re-exports that function from `ggstance`. The archive
is not broken; the package moved.

## Does the maintained rewrite reproduce the paper?

Almost everywhere. The ground truth carries 426 rows; 329 of the 358 the
rewrite can compute agree with the published value at the page’s own
precision, and 53 of the 59 claims about shape, sign or count hold. That
includes every count the 2023 corrigendum corrected. The 35 that do not
are among the rows the number-by-number comparison below lists, and
eleven of them are corrected in `peyton_huber_coppock_2022_errata.pdf`.

Two things are worth stating. First, the deposited archive is **not**
the version that produced the erroneous counts in the published article.
Harvard Dataverse version 2.0, released 6 October 2022, replaced
`manuscript.R` with the corrected code, and running it reproduces the
corrigendum’s numbers exactly. Second, `lemon` and `ggforce` are both
current CRAN packages, so nothing in this archive depends on an
abandoned graphics package.

The deposit does not reproduce one of its own published tables.
`appendix_section_a.R` pools the COVID-era weeks of the prospective
atomic aversion experiment without restricting them to the
unstandardized estimates, so each week enters the precision-weighted
mean twice, once on the percentage-point scale and once on Glass’s Delta
scale. 17 cells of the appendix’s Table 2 move as a result. The three
blocks around it are written the same way with the filter present, and
restoring it returns all 44 of that table’s cells exactly.

The one genuinely stale dependency is `rmeta`, whose most recent release
is from March 2018. The maintained rewrite replaces it with `metafor`,
which changes no result: see the section on fixed-effect and
random-effects pooling.

------------------------------------------------------------------------

# Original archive reproducibility

| Script | Status on current R | Resolution |
|:---|:---|:---|
| ReadMe.R | Fails at library(attentive) | Drop library(attentive) and library(coefplot); neither package’s functions are called anywhere in the archive |
| helpers.R | Clean (sourced by all scripts) | No changes required |
| appendix_section_a.R | Fails twice | position_dodgev() is no longer re-exported by lemon, so supply the position_dodge equivalent; then paste(study_group) must become first(study_group) to write phc_summary.rds |
| appendix_section_b.R | Clean | No changes required; deprecation warnings only |
| manuscript.R | Fails twice | Run appendix_section_a.R first so phc_summary.rds exists; replace the defunct scales::label_number_si() with label_number(scale_cut = cut_short_scale()) |

Original archive reproducibility, checked against R 4.6.0 in August
2026.

Everything else in the archive is a deprecation warning rather than a
failure: `size` where ggplot2 now wants `linewidth`, `geom_errorbarh()`
superseded by an oriented `geom_errorbar()`, `do()` and `gather()` and
`spread()` superseded within dplyr and tidyr, and
`lemon::facet_rep_wrap()` soft-deprecated in favour of
`ggh4x::facet_wrap2()`. All of them still run.

The `paste(study_group)` bug deserves emphasis because of what it did
rather than what it does. In dplyr 1.0 it did not error. It returned a
character vector, and `summarise()` recycled it, so `phc_summary.rds`
was written with a `study_group` column whose entries were several study
names run together. Nothing downstream reads that column in a way that
would notice. The bug became visible only when a later dplyr turned the
silent recycling into an error, which is to say the archive was more
likely to be caught by a version change than by anyone reading its
output.

------------------------------------------------------------------------

# Errata

## Corrected p-value adjustment (published article, Figures 2 and 3 and page 6)

The published article reported the wrong number of statistically
significant differences between the pre-COVID and COVID-era summary
estimates. Errors in the code that adjusted p-values for multiple
comparisons produced counts that were inconsistent before and after
adjustment. The corrigendum (Peyton, Huber and Coppock 2023, *JEPS*
10(2), 306-309, doi 10.1017/xps.2022.23) corrects the page 6 text and
both figures. No point estimate, standard error or substantive
conclusion changes.

| Quantity | Published article | Corrigendum | Deposited archive | Maintained rewrite |
|:---|:---|:---|:---|:---|
| Non-conjoint: significantly smaller, of 24 correctly signed | 10 | 11 | 11 | 11 |
| Non-conjoint: significant at p \< 0.05 (Figure 2 caption) | 13 | 14 | 14 | 14 |
| Non-conjoint: still significant after BH-FDR (Figure 2 caption) | not reported | 13 | 13 | 13 |
| Conjoint: significantly smaller, of 35 smaller | 6 | 11 | 11 | 11 |
| Conjoint: significant at p \< 0.05 (Figure 3 caption) | 7 | 12 | 12 | 12 |
| Conjoint: still significant after BH-FDR (Figure 3 caption) | not reported | 7 | 7 | 7 |

Significant-difference counts corrected by the 2022 corrigendum. The
deposited archive already carries the corrected code.

The deposit was updated alongside the corrigendum. Harvard Dataverse
version 2.0, released 6 October 2022, replaced `ReadMe.R` and
`manuscript.R`, and the replacement `ReadMe.R` says so in a comment.
Running the deposited `manuscript.R` reproduces the corrigendum’s counts
exactly, and so does the maintained rewrite, which computes them in
`maintained/text_correspondence_summary.R` and writes them to
`output/text_correspondence_summary.csv`. Reproducing the published
article’s original counts is not possible from the deposit, because the
code that produced them is no longer in it.

## Everything else the reanalysis found

Eleven further corrections are set out in
`peyton_huber_coppock_2022_errata.pdf` at the root of this repository,
each quoting the published sentence and the corrected one, with every
corrected value computed at render time from `maintained/output/`. None
of them changes a conclusion. The largest is a paragraph of the online
appendix that attributes four estimates to the original atomic aversion
study which are in fact the pre-COVID replication’s, as the appendix’s
own Table 2 shows.

## A rounding difference in Table 2

One cell of published Table 2 differs from the pass rate behind it in
its last digit. The Easy attention-check pass rate among web-application
respondents is 0.5449. Rounded once to two decimal places that is 0.54,
which is what the maintained rewrite prints. The deposited script rounds
every estimate to three decimals before formatting it to two, so 0.5449
becomes 0.545 and then 0.55, which is what the published table shows.
The deposit therefore reproduces its own table, and the discrepancy is
between the printed cell and the quantity it reports. Nothing else in
the table or the text depends on it. It is a table cell rather than a
sentence, so it stays here rather than in the errata.

## Two findings that are not corrections

Two disagreements are recorded in the ground truth without a correction,
because establishing what the published figure should be would mean
choosing between analytical conventions the paper does not state.

The appendix reports three pairwise comparisons between two of the
authors’ own replication arms, in Sections A.2 and A.7, and each printed
p-value is the one-tailed value at the standard error the comparison
implies: 0.02 against a two-sided 0.044, 0.09 against 0.183, and 0.46
against 0.919. Every other p-value in the article and the appendix is
two-sided, and the deposited code computes two-sided p-values
everywhere. The estimates and standard errors in those sentences are
unaffected.

The annual device shares on page 10 reproduce for 2018 and 2020 and not
for 2019. Averaging the per-survey shares in the deposited
`phc_meta_trends.rds` over the surveys fielded in each year returns 13
per cent and 33 per cent for 2018 and 41 per cent and 56 per cent for
2020, exactly as printed, and 34 per cent and 58 per cent for 2019,
against a printed 33 and 56. The 56 the sentence gives for 2019 is the
same figure it gives for 2020 in the preceding clause.

------------------------------------------------------------------------

# The extraction and the two instruments

`ground_truth/published_claims.csv` is an exhaustive numeric-token
extraction from the article, its 35-float online appendix and the 2023
corrigendum, read line by line rather than searched for expected
patterns. It carries 440 rows, each classified as a `pipeline`,
`descriptive`, `definitional`, `structural` or `transcribed` claim and
each carrying the precision at which the page prints it, so that the two
instruments cannot disagree about what precision a comparison should
use. 276 of those rows require a recomputation.

The coverage boundary is every number printed in the body of the
article, in every caption, note and footnote, and in the online
appendix’s prose and its three tables, plus every number in the
corrigendum. Five classes of token are excluded and named here so the
exclusion is auditable: bibliographic tokens, which is to say citation
years and the volume, issue and page numbers of the two reference lists;
page numbers and the page references in the appendix’s contents; the
DOIs and the institutional review board protocol number; axis tick
labels, which are scale furniture rather than estimates; and the prices,
probabilities and casualty counts quoted from the original studies’
instruments, which the extraction records once per section as a
`transcribed` row rather than one row per token.

`maintained/in_text_claims.R` is the second instrument. It recomputes
every one of those 276 claims from `maintained/output/` by a route of
its own and prints one line per claim. Where `build_ground_truth.R`
reaches a quantity through a summary file, the claims file goes back to
the study-level estimates the summary was built from, so the two
derivations are separate; where they disagree, one of them is wrong.
`build_ground_truth.R` runs the claims file inside its own environment,
captures what it prints, and halts unless the printed identifiers are
exactly the identifiers the extraction requires and every printed value
equals the ground truth’s at the extraction’s precision. It also halts
if a transcribed value does not survive a round trip through its own
recorded precision, if a published cell has no rewrite counterpart or a
rewrite cell no published counterpart, if a float prints a different
number of cells from the count the extraction declares, or if an adverse
row carries no cause or a clean match carries one.

------------------------------------------------------------------------

# Number-by-number comparison

The ground truth carries 426 rows: 260 prose and caption quantities
named in the extraction, 146 cells transcribed from Table 2 and the
appendix’s three tables, four relative sizes the appendix prints as a
dash, and 16 counts of what a wordless figure plots. The full table is
`ground_truth/peyton_huber_coppock_2022_ground_truth.csv`; only the rows
that disagree are printed here.

| Location | Quantity | Paper | Rewrite | Cause |
|:---|:---|:---|:---|:---|
| Design (p. 4) | design_median_duration | 12.8 | 12.88 | paper_internal |
| Results (p. 5) | results_replication_estimates | 101 | 102 | unresolved |
| Results (p. 6) | results_sig_smaller_of_24 | 10 | 11 | paper_internal |
| Results (p. 6) | results_conjoint_sig_among_smaller | 6 | 11 | paper_internal |
| Results (p. 6) | results_correspondence_nonconjoint | 49 | 48.3 | paper_internal |
| Figure 2 note (p. 7) | figure_2_sig_count | 13 | 14 | paper_internal |
| Figure 3 note (p. 8) | figure_3_sig_count | 7 | 12 | paper_internal |
| Inattention (p. 10) | device_2019_webapp | 33 | 33.82 | paper_internal |
| Inattention (p. 10) | device_2019_mobile | 56 | 57.62 | paper_internal |
| Inattention (p. 10) | device_overlap_webapp_given_mobile | 72 | 74.51 | unresolved |
| Inattention (p. 10) | device_duration_browser | 21.5 | 21 | paper_internal |
| Inattention (p. 11) | inattention_inattentive_share | 26 | 27 | paper_internal |
| Online Appendix A.1 (p. 1) | a1_replication_estimate | 25.5 | 25.39 | paper_internal |
| Online Appendix A.1 (p. 1) | a1_difference | 5.5 | 5.108 | paper_internal |
| Online Appendix A.2 (p. 3) | a2_covid_vs_precovid_p | 0.02 | 0.04349 | paper_internal |
| Online Appendix A.2 (p. 3) | a2_covid_vs_direct_p | 0.09 | 0.183 | paper_internal |
| Online Appendix A.7 (p. 15) | a7_covid_vs_direct_se | 0.04 | 0.05695 | paper_internal |
| Online Appendix A.7 (p. 15) | a7_covid_vs_direct_p | 0.46 | 0.9177 | paper_internal |
| Online Appendix A.4 (p. 6) | a4_capi_summary | 1.00 | 0.9943 | paper_internal |
| Online Appendix A.8 (p. 17) | a8_9070_success | 75 | 70 | paper_internal |
| Online Appendix A.8 (p. 18) | a8_original_9070_prefer | 37 | 29.71 | paper_internal |
| Online Appendix A.8 (p. 18) | a8_original_9045_prefer | 51 | 47.56 | paper_internal |
| Online Appendix A.8 (p. 18) | a8_original_9070_approve | 17 | 5.136 | paper_internal |
| Online Appendix A.8 (p. 18) | a8_original_9045_approve | 27 | 27.52 | paper_internal |
| Online Appendix A.9 (p. 22) | a9_total_amces | 81 | 82 | paper_internal |
| Online Appendix A.10 footnote 5 (p. 25) | a10_footnote_5_significant | 2 | 4 | paper_internal |
| Corrigendum Figure 1a note (p. 307) | corrigendum_figure_1a_note_sig | 13 | 14 | paper_internal |
| Corrigendum Figure 2a note (p. 308) | corrigendum_figure_2a_note_sig | 7 | 12 | paper_internal |
| Results (p. 6) | results_all_smaller_nonconjoint | NA | FALSE | paper_internal |
| Inattention (p. 10) | device_additional_sample_period | NA | FALSE | paper_internal |
| Inattention (p. 10) | device_acq_significance | NA | FALSE | paper_internal |
| Online Appendix A.5 (p. 11) | a5_table_reference | NA | FALSE | paper_internal |
| Online Appendix A.5 (p. 10) | a5_program_a_significant | NA | FALSE | unresolved |
| Online Appendix A.10 footnote 5 (p. 25) | a10_footnote_5_named | NA | FALSE | paper_internal |
| Table 2 | table_2_easy_webapp_estimate | 0.55 | 0.5449 | archive |
| Appendix Table 2 | appendix_table_2_90_70_prefer_nuclear_use_ycls_summary_estimate | 0.08 | 0.07875 | archive |
| Appendix Table 2 | appendix_table_2_90_70_prefer_nuclear_use_psv_diff_estimate | -0.22 | -0.2184 | archive |
| Appendix Table 2 | appendix_table_2_90_70_prefer_nuclear_use_abp_diff_estimate | -0.29 | -0.2889 | archive |
| Appendix Table 2 | appendix_table_2_90_70_prefer_nuclear_use_abp_diff_se | 0.04 | 0.03582 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_ycls_summary_estimate | 0.13 | 0.1266 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_ycls_summary_se | 0.03 | 0.02599 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_psv_diff_estimate | -0.35 | -0.349 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_psv_diff_se | 0.06 | 0.05519 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_abp_diff_estimate | -0.39 | -0.3883 | archive |
| Appendix Table 2 | appendix_table_2_90_70_approve_nuclear_use_ycls_summary_estimate | -0.04 | -0.03862 | archive |
| Appendix Table 2 | appendix_table_2_90_70_approve_nuclear_use_psv_diff_estimate | -0.09 | -0.08998 | archive |
| Appendix Table 2 | appendix_table_2_90_70_approve_nuclear_use_abp_diff_estimate | -0.21 | -0.212 | archive |
| Appendix Table 2 | appendix_table_2_90_45_approve_nuclear_use_psv_diff_estimate | -0.32 | -0.3203 | archive |
| Appendix Table 2 | appendix_table_2_90_70_prefer_nuclear_use_psv_ratio | 0.27 | 0.2651 | archive |
| Appendix Table 2 | appendix_table_2_90_70_prefer_nuclear_use_abp_ratio | 0.21 | 0.2142 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_psv_ratio | 0.27 | 0.2663 | archive |
| Appendix Table 2 | appendix_table_2_90_45_prefer_nuclear_use_abp_ratio | 0.25 | 0.2459 | archive |

Every row of the ground truth that does not agree with the published
page: 52 of 426.

## Float coverage

| Float | Numbers printed | Covered | Reproduced by the rewrite | Reproduced by the deposit | Estimates plotted |
|:---|---:|---:|---:|---:|---:|
| table_2 | 36 | 36 | 35 | 36 | NA |
| figure_2 | 0 | 0 | 0 | 0 | 28 |
| figure_3 | 0 | 0 | 0 | 0 | 41 |
| figure_5 | 0 | 0 | 0 | 0 | 10 |
| appendix_table_1 | 42 | 42 | 42 | 42 | NA |
| appendix_table_2 | 44 | 44 | 44 | 27 | NA |
| appendix_table_3 | 24 | 24 | 24 | 24 | NA |
| figure_a1 | 0 | 0 | 0 | 0 | 4 |
| figure_a2 | 0 | 0 | 0 | 0 | 4 |
| figure_a3 | 0 | 0 | 0 | 0 | 10 |
| figure_a4 | 0 | 0 | 0 | 0 | 34 |
| figure_a5 | 0 | 0 | 0 | 0 | 24 |
| figure_a6 | 0 | 0 | 0 | 0 | 2 |
| figure_a7 | 0 | 0 | 0 | 0 | 4 |
| figure_a8 | 0 | 0 | 0 | 0 | 20 |
| figure_a9 | 0 | 0 | 0 | 0 | 10 |
| figure_a10 | 0 | 0 | 0 | 0 | 82 |
| figure_a11 | 0 | 0 | 0 | 0 | 12 |
| figure_a12 | 0 | 0 | 0 | 0 | 10 |
| figure_a13 | 0 | 0 | 0 | 0 | 8 |

Published floats that print a number or plot an estimate. A float
printing no numbers is covered by the count of what it plots; the
remaining floats, listed in the float coverage file, carry a stated
reason.

The 24 floats not in that table are the eight covariate-distribution
figures of appendix Section B, whose proportions the rewrite does not
compute; the eleven Section C figures, which are screenshots of survey
content and state no estimated quantity; Table 1 and Figures 1 and 4,
which print no estimates and whose content is covered as prose claims;
and the corrigendum’s two figures, which reprint the article’s.

------------------------------------------------------------------------

# Maintained rewrite

The rewrite (`maintained/`) is eleven scripts: a shared `helpers.R`, one
cleaning script, five figures, one table, two scripts for quantities the
article states only in prose, and the in-text claims file that
recomputes every one of them.

| Script | Output |
|:---|:---|
| helpers.R | Packages, theme_ycls(), meta_summaries_fe(), glass_delta(), make_entry(), table_entry() |
| clean_summary_estimates.R | phc_summary_clean.rds and .csv; appendix_study_estimates.csv; appendix_table_cells.csv; appendix_table_ratios.csv; text_pooled_benchmarks.csv |
| figure_1_lucid_weekly_completes.R | figure_1_lucid_weekly_completes.pdf, .png and .csv |
| figure_2_noncojoint_correspondence.R | figure_2_noncojoint_correspondence.pdf, .png and .csv |
| figure_3_conjoint_correspondence.R | figure_3_conjoint_correspondence.pdf, .png and .csv |
| figure_4_meta_trends.R | figure_4_meta_trends.pdf, .png and .csv |
| figure_5_trust_replication.R | figure_5_trust_replication.pdf, .png and .csv |
| table_2_acq_pass_rates.R | table_2_acq_pass_rates.tex and .csv; table_2_acq_pass_rates_cells.csv |
| text_correspondence_summary.R | text_correspondence_summary.csv |
| text_device_metadata.R | text_device_metadata.csv; text_device_by_survey.csv; text_device_by_year.csv; text_device_all_surveys.csv |
| in_text_claims.R | Printed to the console: one line per published claim |

Maintained rewrite scripts and their outputs.

## Architecture

Every comparison in the paper rests on 138 summary effect sizes, one
pre-COVID and one COVID-era estimate for each of 69 study-outcome pairs.
The deposited `appendix_section_a.R` builds them in 3,010 lines of
study-by-study estimation, and only its last statement is wrong.
`clean_summary_estimates.R` therefore runs the deposited code up to that
point and then applies the corrected summarise, rather than
reimplementing twelve studies’ worth of estimation to fix one word. That
is a deliberate choice and it is the one place where the rewrite depends
on the deposit as code rather than as data.

Running someone else’s script inside a rewrite needs care, and three
things are done to contain it. The deposited code addresses its inputs
by bare relative path and writes appendix tables and figures beside
them, so it runs in a temporary directory of symlinks to `original/`:
reads resolve, writes land in `tempdir()`, and `original/` stays
byte-identical to what `download_original.R` verified. The environment
it evaluates in is passed explicitly rather than inherited. And three
substitutions are applied to the text of the script itself. Two are
dependency repairs, described in the next section. The third is an
analysis correction: the block that pools the COVID-era weeks of the
prospective atomic aversion experiment omits the
`estimate_type == "Unstandardized"` filter that its three siblings in
the same file all carry, so it averages each week’s percentage-point
estimate together with the same week’s Glass’s Delta estimate. Restoring
the filter is what makes the rewrite reproduce the appendix’s published
Table 2.

Every figure script also writes a CSV of the estimates it plots. A PDF
records the time it was written, so for a paper whose results are almost
entirely figures the committed output would otherwise be undiffable.

The remaining scripts read either `original/` or the cleaned summary
estimates, and share nothing but `helpers.R`.
`ground_truth/extract_archive_values.R` runs the deposited code a second
time with only the repairs it needs to execute, and not the analysis
correction, so that the deposit’s own answer is recorded separately from
the rewrite’s.

## Deprecated patterns replaced

| Original pattern | Replacement |
|:---|:---|
| `rmeta::meta.summaries()` | `metafor::rma(method = "FE")` |
| `position_dodgev()` (ggstance, via lemon) | `position_dodge(width = 0.5)` |
| `geom_errorbarh()` | `geom_linerange(xmin =, xmax =)` |
| `facet_row()` (ggforce) | `facet_wrap()` |
| `scales::label_number_si()` | `label_number(scale_cut = cut_short_scale())` |
| `do(tidy(...))` | `reframe(tidy(lm_robust(..., data = pick(everything()))))` |
| `paste(study_group)` in `summarise()` | `first(study_group)` |
| `size =` for lines | `linewidth =` |
| `ifelse()` | `if_else()` |
| `xtable()` + `print.xtable()` | `knitr::kable()` + `readr::write_lines()` |
| `%>%` | `&#124;>` |

Deprecated patterns and their replacements in the maintained rewrite.

Three of these deserve a word. `position_dodgev()` came from `ggstance`,
which ggplot2 superseded once `position_dodge()` learned to dodge along
a discrete axis; `lemon` re-exported it when this archive was deposited
and no longer does. `facet_row()` still exists in current `ggforce`, and
the replacement is a simplification rather than a repair: with two
panels `facet_wrap()` lays them out identically and the maintained
figure needs one fewer package. `coord_capped_cart()`, also from
`lemon`, is left in place in the deposited code the cleaning script
runs, since `lemon` is maintained and the call affects only appendix
figures drawn into a temporary directory.

The rewrite does not use `xtable`, but the deposited appendix code does,
at five sites that write LaTeX table bodies with `only.contents = TRUE`.
Those are fragments with no header, no row or column names and no rules,
meant to be read into a hand-written `tabular` environment in the
appendix. `knitr::kable()` has no equivalent output mode, so converting
them would mean pasting the body rows together by hand rather than
swapping one call for another. They are left as deposited, and `xtable`
remains a dependency of `clean_summary_estimates.R` for that reason
alone.

------------------------------------------------------------------------

# Fixed-effect and random-effects pooling

The deposited appendix code pools benchmark estimates with
`rmeta::meta.summaries()` at fifteen sites, always at its default of
fixed-effect inverse-variance weighting. `rmeta`’s most recent release
is from March 2018, so its continued availability is a fact about CRAN’s
archiving policy rather than about maintenance. The rewrite replaces it
with `metafor::rma(method = "FE")`, which is the same estimator: across
all fifteen sites the largest disagreement in a pooled estimate is 7
times 10 to the minus 16, and in a standard error 7 times 10 to the
minus 18, which is double-precision noise.

Having the data in `metafor` makes the random-effects estimates free,
and they are reported below as an addition rather than a correction. The
published article uses the fixed-effect column throughout, and those are
the numbers that reproduce.

| Benchmark | k | FE est. | FE SE | RE est. | RE SE | $\hat{\tau}^2$ | $I^2$ | $Q$ | $p$ |
|:---|---:|:---|:---|:---|:---|:---|:---|:---|:---|
| Russian reporters, pre-COVID | 3 | 0.305 | 0.020 | 0.280 | 0.056 | 0.0074 | 83.3% | 15.33 | 0.000 |
| Question framing, pre-COVID | 2 | 0.174 | 0.015 | 0.269 | 0.115 | 0.0240 | 90.7% | 10.70 | 0.001 |
| Question framing, COVID era | 2 | 0.111 | 0.031 | 0.111 | 0.041 | 0.0015 | 43.6% | 1.77 | 0.183 |
| Asian disease, pre-COVID | 5 | 0.289 | 0.014 | 0.325 | 0.043 | 0.0081 | 88.8% | 24.97 | 0.000 |
| Asian disease, COVID era | 5 | 0.147 | 0.019 | 0.147 | 0.019 | 0.0000 | 0.0% | 2.22 | 0.695 |
| Welfare spending, COVID-era web interviews | 12 | 0.437 | 0.017 | 0.437 | 0.019 | 0.0007 | 17.1% | 12.72 | 0.312 |
| Welfare spending, GSS in-person | 9 | 0.994 | 0.012 | 0.993 | 0.018 | 0.0016 | 53.3% | 17.21 | 0.028 |
| Welfare spending, GSS paper and pencil | 11 | 1.048 | 0.013 | 1.038 | 0.037 | 0.0133 | 87.3% | 85.19 | 0.000 |
| Welfare spending, COVID-era experimental | 10 | 0.434 | 0.018 | 0.433 | 0.021 | 0.0013 | 27.7% | 12.39 | 0.192 |
| Welfare spending, Huber benchmark | 2 | 0.462 | 0.052 | 0.462 | 0.052 | 0.0000 | 0.0% | 0.08 | 0.774 |
| Welfare spending, Huber and GSS 1986 | 3 | 0.702 | 0.036 | 0.621 | 0.154 | 0.0669 | 94.1% | 41.51 | 0.000 |
| Welfare spending, COVID-era observational | 2 | 0.362 | 0.030 | 0.362 | 0.030 | 0.0000 | 0.0% | 0.73 | 0.392 |
| Issue framing, pre-COVID | 9 | 0.254 | 0.043 | 0.258 | 0.055 | 0.0106 | 39.0% | 12.92 | 0.115 |
| Issue framing, COVID era | 27 | 0.094 | 0.015 | 0.094 | 0.015 | 0.0003 | 4.2% | 36.04 | 0.091 |
| Intentional side effects, pre-COVID | 2 | 0.640 | 0.012 | 0.640 | 0.012 | 0.0000 | 0.0% | 0.31 | 0.580 |

Pooled benchmark estimates. FE is inverse-variance fixed-effect pooling,
the estimator the article uses; RE is REML. $\hat{\tau}^2$ is the REML
estimate of between-study variance and $I^2$ the share of total variance
attributable to it. $Q$ is Cochran’s heterogeneity statistic, which the
appendix quotes for the three welfare survey modes.

The pattern is the one the fixed-effect assumption invites. In 6 of the
fifteen pools more than half the variance in the component estimates is
between studies rather than within them, and where that is true the
random-effects standard error is much wider, by up to a factor of 7.7.
The point estimates move little. The reading is not that the article’s
benchmarks are wrong but that several of them pool studies run decades
apart in different modes, and a single true effect across those is a
strong assumption to make silently.

------------------------------------------------------------------------

# Figures

<img src="maintained/output/figure_1_lucid_weekly_completes.png"
style="width:100.0%"
alt="Figure 1: Total weekly Lucid survey responses to academic buyers, January 2019 to March 2021." />

<img src="maintained/output/figure_2_noncojoint_correspondence.png"
style="width:100.0%"
alt="Figure 2: Comparison of 28 summary effect sizes across 11 studies, conjoint excluded. Fill marks a difference significant at p &lt; 0.05; square points remain significant after controlling the false discovery rate." />

<img src="maintained/output/figure_3_conjoint_correspondence.png"
style="width:100.0%"
alt="Figure 3: Comparison of 41 summary effect sizes in conjoint experiments, marked as in Figure 2." />

<img src="maintained/output/figure_4_meta_trends.png"
style="width:100.0%"
alt="Figure 4: Respondents from mobile devices and web applications, June 2018 to July 2020." />

<img src="maintained/output/figure_5_trust_replication.png"
style="width:100.0%"
alt="Figure 5: Reanalysis of estimated treatment effects on trust in government for the Peyton (2020) replication." />

Figures 2 and 3 are the corrected versions. They encode significance
before adjustment by fill and significance after the Benjamini-Hochberg
adjustment by point shape, matching the figures printed in the
corrigendum rather than those in the original article.

------------------------------------------------------------------------

# Table 2

| Difficulty | Browser | Web app | Difference | Non-mobile | Mobile | Difference |
|:---|:---|:---|:---|:---|:---|:---|
| Easy | 0.66 (0.02) | 0.54 (0.02) | 0.11 (0.03)\* | 0.63 (0.02) | 0.58 (0.02) | 0.05 (0.03) |
| Medium | 0.53 (0.02) | 0.37 (0.02) | 0.16 (0.03)\* | 0.50 (0.02) | 0.42 (0.02) | 0.08 (0.03)\* |
| Hard | 0.22 (0.02) | 0.15 (0.01) | 0.07 (0.02)\* | 0.24 (0.02) | 0.16 (0.01) | 0.08 (0.02)\* |

Attention-check pass rates by attentiveness and level of difficulty,
reproducing published Table 2. Standard errors in parentheses; an
asterisk marks a difference significant at p \< 0.05.

------------------------------------------------------------------------

# Maintained rewrite verification

329 of the 358 claims the rewrite can compute match the published value
at the page’s own precision, and 53 of the 59 claims about shape, sign
or count hold. The 9 rows carrying no verdict are `approximate` hedges,
which have no comparison by design, and the descriptive rows are counted
separately above.

The pipeline is deterministic. Running `run_all.R` twice in succession
returns every file it writes byte-identical, the figure PDFs included:
`maintained/helpers.R` blanks the wall-clock `/CreationDate` and
`/ModDate` that R’s `pdf()` device stamps into every figure, which are
otherwise the only reason two runs differ.

The coverage gate was tested by breaking it three ways. Deleting a claim
block fails the count. Changing a computed value in the claims file
fails the cross-instrument comparison. Changing a recorded precision in
the extraction fails the round-trip check, which runs before anything
consumes the precision, so a wrong precision cannot hide behind a value
comparison downstream.

------------------------------------------------------------------------

# R environment

| Item       | Value                  |
|:-----------|:-----------------------|
| R version  | 4.6.0                  |
| Platform   | aarch64-apple-darwin23 |
| Date run   | 2026-08-09             |
| tidyverse  | 2.0.0                  |
| estimatr   | 1.0.6                  |
| metafor    | 5.0.1                  |
| ggthemes   | 5.2.0                  |
| ggrepel    | 0.9.8                  |
| ggforce    | 0.5.0                  |
| lemon      | 0.5.2                  |
| RCurl      | 1.98.1.19              |
| haven      | 2.5.5                  |
| xtable     | 1.8.8                  |
| knitr      | 1.51                   |
| kableExtra | 1.4.0                  |
| here       | 1.0.2                  |

R version and key package versions at the last run.
