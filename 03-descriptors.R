
library(tidyverse)
library(progress)
library(furrr)
source("helper-functions.R")

out_textos <- "textos/"
out_data <- "data/"

plan(multisession, workers = parallel::detectCores() - 1L)

output <- dir(out_textos, full.names = TRUE) |> 
  furrr::future_map(\(x) str_squish(read_rds(x)))

names(output) <- dir(out_textos) |> str_remove("\\.rds")

# Descriptors -------------------------------------------------------------

descriptors <- furrr::future_map(output, extract_descriptors) |> 
  enframe(name = "from", value = "to") |> 
  unnest(to) |> 
  distinct()

descriptors <- descriptors |> 
  group_by(to) |> 
  filter(n() >= 5) |> 
  ungroup()

write_rds(descriptors, str_glue("{out_data}descriptors.rds"), compress = "gz")
