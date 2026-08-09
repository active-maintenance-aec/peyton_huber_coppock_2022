# peyton_huber_coppock_2022/maintained/helpers.R
# Output: (none; sourced by all analysis scripts)
# Description: Shared packages, paths, and helper functions for the maintained rewrite.

library(here)
library(tidyverse)
library(ggthemes)
library(ggrepel)
library(estimatr)
library(metafor)
library(haven)
library(RCurl)
library(xtable)

# ggforce (facet_col) and lemon (facet_rep_wrap, coord_capped_cart) are used only by the
# deposited appendix_section_a.R that clean_summary_estimates.R runs, and only for the
# appendix figures it draws into a temporary directory. Both are current on CRAN, lemon as
# of September 2025 and ggforce as of June 2025, so the deposited code runs as its authors
# wrote it. Neither package is called by any of the five maintained figure scripts.
library(ggforce)
library(lemon)

here::i_am("maintained/helpers.R")

data_dir <- here("original")
out_dir  <- here("maintained", "output")

# Fixed-effect pooling ----
# Drop-in replacement for rmeta::meta.summaries(), which the deposited
# appendix_section_a.R calls at fifteen sites to pool benchmark estimates.
# rmeta has had no release since March 2018; metafor::rma(method = "FE") is the
# same inverse-variance fixed-effect estimator. The argument names and the two
# return components the original code reads ($summary, $se.summary) are matched
# exactly, so clean_summary_estimates.R can substitute this function into the
# sourced text without touching the surrounding logic.
meta_summaries_fe <- function(d, se, data) {
  yi <- eval(substitute(d), data, parent.frame())
  sei <- eval(substitute(se), data, parent.frame())
  fit <- metafor::rma(yi = yi, sei = sei, method = "FE")
  list(summary = unname(fit$beta[1, 1]), se.summary = fit$se, fit = fit)
}

# Theme ----
# Custom ggthemes tufte-based theme from original helpers.R
theme_ycls <- function(font_size = 12, font_family = "serif", line_size = 0.5,
                       rel_small = 12 / 14, rel_tiny = 11 / 14, rel_large = 16 / 14) {
  half_line  <- font_size / 2
  small_size <- rel_small * font_size

  theme_tufte(base_size = font_size, base_family = font_family) %+replace%
    theme(
      line  = element_line(colour = "black", linewidth = line_size, linetype = 1, lineend = "butt"),
      rect  = element_rect(fill = NA, colour = NA, linewidth = line_size, linetype = 1),
      text  = element_text(family = font_family, face = "plain", colour = "black",
                           size = font_size, hjust = 0.5, vjust = 0.5, angle = 0,
                           lineheight = 0.9, margin = margin(), debug = FALSE),
      axis.line.y             = NULL,
      axis.line.x             = NULL,
      axis.text               = element_text(colour = "black", size = small_size, family = font_family),
      axis.text.x             = element_text(margin = margin(t = small_size / 4), vjust = 1,
                                             size = small_size, family = font_family),
      axis.text.x.top         = element_text(margin = margin(b = small_size / 4), vjust = 0,
                                             family = font_family),
      axis.text.y             = element_text(margin = margin(r = small_size / 4), hjust = 1,
                                             size = small_size, family = font_family),
      axis.text.y.right       = element_text(margin = margin(l = small_size / 4), hjust = 0,
                                             family = font_family),
      axis.ticks              = element_line(colour = "black", linewidth = line_size),
      axis.ticks.y            = element_blank(),
      axis.ticks.length       = unit(half_line / 2, "pt"),
      axis.title.x            = element_text(margin = margin(t = half_line / 2), vjust = 1,
                                             size = small_size, family = font_family),
      axis.title.x.top        = element_text(margin = margin(b = half_line / 2), vjust = 0,
                                             family = font_family),
      axis.title.y            = element_text(angle = 90, family = font_family, size = small_size,
                                             margin = margin(r = half_line / 2), vjust = 1),
      axis.title.y.right      = element_text(angle = -90, margin = margin(l = half_line / 2), vjust = 0),
      legend.position         = "none",
      legend.background       = element_blank(),
      legend.spacing          = unit(font_size, "pt"),
      legend.spacing.x        = NULL,
      legend.spacing.y        = NULL,
      legend.margin           = margin(0, 0, 0, 0),
      legend.key              = element_blank(),
      legend.key.size         = unit(1.1 * font_size, "pt"),
      legend.key.height       = NULL,
      legend.key.width        = NULL,
      legend.text             = element_text(size = rel(rel_small)),
      legend.title            = element_text(hjust = 0),
      legend.direction        = NULL,
      legend.justification    = c("left", "center"),
      legend.box              = NULL,
      legend.box.margin       = margin(0, 0, 0, 0),
      legend.box.background   = element_blank(),
      legend.box.spacing      = unit(font_size, "pt"),
      panel.background        = element_blank(),
      panel.border            = element_blank(),
      panel.grid              = element_blank(),
      panel.grid.major        = NULL,
      panel.grid.minor        = element_blank(),
      panel.grid.major.x      = NULL,
      panel.grid.major.y      = NULL,
      panel.grid.minor.x      = NULL,
      panel.grid.minor.y      = NULL,
      panel.spacing           = unit(half_line, "pt"),
      panel.spacing.x         = NULL,
      panel.spacing.y         = NULL,
      panel.ontop             = FALSE,
      strip.background        = element_blank(),
      strip.text              = element_text(size = font_size, family = font_family,
                                             margin = margin(half_line / 2, half_line / 2,
                                                             half_line / 2, half_line / 2)),
      strip.text.x            = element_text(size = font_size, family = font_family,
                                             angle = 0, hjust = 0,
                                             margin = margin(half_line / 2, half_line / 2,
                                                             half_line / 2, half_line / 2)),
      strip.placement         = "inside",
      strip.placement.x       = NULL,
      strip.placement.y       = NULL,
      strip.switch.pad.grid   = unit(half_line / 2, "pt"),
      strip.switch.pad.wrap   = unit(half_line / 2, "pt"),
      plot.background         = element_blank(),
      plot.title              = element_text(face = "bold", size = rel(rel_large),
                                             hjust = 0.5, vjust = 1, margin = margin(b = half_line)),
      plot.subtitle           = element_text(size = rel(rel_small), hjust = 0.5, vjust = 1,
                                             margin = margin(b = half_line)),
      plot.caption            = element_text(size = rel(rel_tiny), hjust = 1, vjust = 1,
                                             margin = margin(t = half_line)),
      plot.tag                = element_text(face = "bold", hjust = 0, vjust = 0.7),
      plot.tag.position       = c(0, 1),
      plot.margin             = margin(half_line, half_line, half_line, half_line),
      complete                = TRUE
    )
}

# Formatting helpers ----
add_parens <- function(x, digits = 2) {
  x <- as.numeric(x)
  paste0("(", sprintf(paste0("%.", digits, "f"), x), ")")
}

format_num <- function(x, digits = 2) {
  x <- as.numeric(x)
  sprintf(paste0("%.", digits, "f"), x)
}

make_entry <- function(est, se, p, digits = 2) {
  entry <- paste0(format_num(est, digits = digits), " ", add_parens(se, digits = digits))
  entry[p < 0.05] <- paste0(entry[p < 0.05], "*")
  entry
}

table_entry <- function(est, se, digits = 2) {
  paste0(format_num(est, digits = digits), " ", add_parens(se, digits = digits))
}

glass_delta <- function(Y, Z, level) {
  Y / sd(Y[Z == level], na.rm = TRUE)
}

# Blank a figure PDF's embedded timestamps ----
# R's pdf() device stamps /CreationDate and /ModDate with the wall clock, so an
# otherwise deterministic pipeline writes a different file on every run. The epoch
# string is the same width as what it replaces, which keeps the cross-reference byte
# offsets valid, and a file with no timestamp is left alone.
blank_pdf_timestamps <- function(path) {
  epoch <- charToRaw("D:19700101000000")
  raw_pdf <- readBin(path, "raw", file.size(path))
  hits <- grepRaw("D:[0-9]{14}", raw_pdf, all = TRUE)
  if (length(hits) == 0) return(invisible(path))
  for (h in hits) raw_pdf[h:(h + length(epoch) - 1L)] <- epoch
  writeBin(raw_pdf, path)
  invisible(path)
}
